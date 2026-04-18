//
//  AudioRecorder.swift
//  EngineChecker
//
//  Created by Anastasia on 17.04.2026.
//

import AVFoundation
import Combine
import os.log

private let logger = Logger(subsystem: "com.enginechecker.app", category: "AudioRecorder")

class AudioRecorder: NSObject, ObservableObject {
	var audioRecorder: AVAudioRecorder?
	@Published var isRecording = false
	@Published var isUploading = false
	@Published var uploadMessage: String?
	@Published var classifyAnswer: ClassifyAnswer?
	@Published private(set) var lastRecordingURL: URL?
	@Published var waveformSamples: [CGFloat] = Array(repeating: 0.05, count: 100)

	/// Идентификатор ТС для `RequestModel.vehicle_id` (multipart).
	@Published var vehicleId: String = ""
	/// Тип сегмента записи (`idle` / `high_hold` / `background`).
	@Published var segmentType: RequestModel.SegmentType = .idle

	/// Сегменты уже остановленных записей в текущей «сессии» (для склейки при отправке).
	private var completedSegmentURLs: [URL] = []

	/// Можно продолжить запись после `stopRecording()` в тот же логический файл (новый сегмент).
	var canContinueRecording: Bool {
		!completedSegmentURLs.isEmpty && !isRecording
	}

	private let minPower: Float = -50
	private let maxWaveformSamples = 100
	private var meterTimer: Timer?
	private var smoothedLevel: CGFloat = 0.05

	deinit {
		logger.debug("AudioRecorder deinit - stopping meter updates")
		stopMeterUpdates()
	}

	init(answer: ClassifyAnswer? = nil) {
		super.init()
		logger.info("AudioRecorder init - answer provided: \(answer != nil)")
		self.classifyAnswer = answer
		checkPermissions()
	}

	func checkPermissions() {
		logger.info("Requesting microphone permission")
		AVAudioSession.sharedInstance().requestRecordPermission { granted in
			if granted {
				logger.info("Microphone permission granted")
			} else {
				logger.error("Microphone permission denied")
			}
		}
	}

	func startRecording() {
		logger.info("startRecording called")
		completedSegmentURLs.removeAll()
		beginRecordingNewSegment(shouldResetWaveform: true)
	}

	func continueRecording() {
		logger.info("continueRecording called")
		guard canContinueRecording else {
			logger.warning("continueRecording ignored — no completed segments or already recording")
			return
		}
		beginRecordingNewSegment(shouldResetWaveform: false)
	}

	private func beginRecordingNewSegment(shouldResetWaveform: Bool) {
		let session = AVAudioSession.sharedInstance()
		do {
			try session.setCategory(.playAndRecord, mode: .default)
			try session.setActive(true)
			logger.debug("Audio session configured successfully")
		} catch {
			logger.error("Failed to configure audio session: \(error.localizedDescription)")
		}

		let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
		let timestamp = Int(Date().timeIntervalSince1970)
		let fileName = path.appendingPathComponent("recording-\(timestamp).wav")
		logger.debug("Recording file path: \(fileName.path)")

		let settings: [String: Any] = [
			AVFormatIDKey: Int(kAudioFormatLinearPCM),
			AVSampleRateKey: 44100,
			AVNumberOfChannelsKey: 1,
			AVLinearPCMBitDepthKey: 16,
			AVLinearPCMIsBigEndianKey: false,
			AVLinearPCMIsFloatKey: false
		]
		logger.debug("Recording settings: sampleRate=44100, channels=1, bitDepth=16")

		do {
			audioRecorder = try AVAudioRecorder(url: fileName, settings: settings)
			audioRecorder?.isMeteringEnabled = true
			audioRecorder?.record()
			isRecording = true
			lastRecordingURL = fileName
			if shouldResetWaveform {
				resetWaveform()
			}
			startMeterUpdates()
			logger.info("Recording started successfully")
		} catch {
			logger.error("Failed to start recording: \(error.localizedDescription)")
		}
	}

	func stopRecording() {
		logger.info("stopRecording called")
		let shouldCommitSegment = isRecording
		audioRecorder?.stop()
		isRecording = false
		stopMeterUpdates()
		if let url = lastRecordingURL, shouldCommitSegment {
			completedSegmentURLs.append(url)
			logger.info("Recording stopped. File saved at: \(url.path), segments: \(self.completedSegmentURLs.count)")
		}
	}

	func uploadLastRecording() {
		logger.info("uploadLastRecording called")
		guard lastRecordingURL != nil || !completedSegmentURLs.isEmpty else {
			logger.warning("No recording file available for upload")
			uploadMessage = "Нет записи для отправки"
			return
		}
		let segments = completedSegmentURLs
		logger.info("Preparing to upload, segment count: \(segments.count)")

		Task {
			await MainActor.run {
				self.isUploading = true
				self.uploadMessage = nil
				self.classifyAnswer = nil
			}
			logger.debug("Upload state set - isUploading: true")

			do {
				let fileURL = try Self.makeUploadURL(from: segments)
				let responseBody = try await uploadFile(fileURL: fileURL)
				logger.info("Upload successful - label: \(responseBody.label ?? "nil"), anomalyScore: \(responseBody.anomalyScore ?? -1)")
				await MainActor.run {
					self.classifyAnswer = responseBody
					self.uploadMessage = responseBody.label ?? "Успешно отправлено"
					self.isUploading = false
				}
			} catch {
				logger.error("Upload failed: \(error.localizedDescription)")
				await MainActor.run {
					self.uploadMessage = "Ошибка отправки: \(error.localizedDescription)"
					self.isUploading = false
				}
			}
		}
	}

	private func uploadFile(fileURL: URL) async throws -> ClassifyAnswer {
		let endpoint = URL(string: "http://178.154.233.146:8000/api/v1/audio/classify")!
		logger.info("Starting file upload to: \(endpoint.absoluteString)")
		
		var request = URLRequest(url: endpoint)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Accept")

		let boundary = "Boundary-\(UUID().uuidString)"
		request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
		logger.debug("Request configured - method: POST, boundary: \(boundary)")

		let durationSec = try Self.wavDurationSeconds(at: fileURL)
		let meta = RequestModel(
			vehicleId: vehicleId.isEmpty ? "unknown" : vehicleId,
			durationSec: durationSec,
			segmentType: segmentType
		)

		let fileData = try Data(contentsOf: fileURL)
		logger.debug("File data loaded - size: \(fileData.count) bytes, durationSec: \(durationSec)")
		
		var body = Data()
		body.appendMultipartField(boundary: boundary, name: "vehicle_id", value: meta.vehicleId)
		body.appendMultipartField(boundary: boundary, name: "segment_type", value: meta.segmentType.rawValue)
		body.appendMultipartField(boundary: boundary, name: "duration_sec", value: String(format: "%.6f", meta.durationSec))
		body.append("--\(boundary)\r\n")
		body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n")
		body.append("Content-Type: audio/wav\r\n\r\n")
		body.append(fileData)
		body.append("\r\n")
		body.append("--\(boundary)--\r\n")

		request.httpBody = body
		logger.debug("Request body prepared - total size: \(body.count) bytes")
		logger.info("Sending request to server...")

		let (data, response) = try await URLSession.shared.data(for: request)
		guard let httpResponse = response as? HTTPURLResponse else {
			logger.error("Invalid server response - not an HTTP response")
			throw NSError(domain: "Upload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Некорректный ответ сервера"])
		}

		let responseText = String(data: data, encoding: .utf8) ?? ""
		logger.debug("Server response - status: \(httpResponse.statusCode), body: \(responseText)")
		
		guard (200...299).contains(httpResponse.statusCode) else {
			logger.error("Server returned error status: \(httpResponse.statusCode)")
			throw NSError(
				domain: "Upload",
				code: httpResponse.statusCode,
				userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(responseText)"]
			)
		}

		do {
			let decoded = try Self.decodeClassifyResponse(from: data)
			logger.info("Response decoded successfully - label: \(decoded.label ?? "nil"), anomaly_score: \(decoded.anomalyScore.map { String($0) } ?? "nil")")
			return decoded
		} catch {
			logger.error("Failed to decode response: \(error.localizedDescription)")
			throw NSError(
				domain: "Upload",
				code: -2,
				userInfo: [NSLocalizedDescriptionKey: "Не удалось распарсить ответ сервера: \(responseText)"]
			)
		}
	}

	private func startMeterUpdates() {
		logger.debug("startMeterUpdates called")
		stopMeterUpdates()
		meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
			guard let self, let recorder = self.audioRecorder else { return }
			recorder.updateMeters()
			let averagePower = recorder.averagePower(forChannel: 0)
			let normalizedPower = max(0, (averagePower - self.minPower) / abs(self.minPower))
			let rawSample = CGFloat(normalizedPower)
			self.smoothedLevel = (self.smoothedLevel * 0.75) + (rawSample * 0.25)

			DispatchQueue.main.async {
				self.waveformSamples.append(self.smoothedLevel)
				if self.waveformSamples.count > self.maxWaveformSamples {
					self.waveformSamples.removeFirst(self.waveformSamples.count - self.maxWaveformSamples)
				}
			}
		}
		logger.debug("Meter timer started with 0.05s interval")
	}

	private func stopMeterUpdates() {
		if meterTimer != nil {
			logger.debug("Stopping meter updates")
		}
		meterTimer?.invalidate()
		meterTimer = nil
	}

	private func resetWaveform() {
		logger.debug("Resetting waveform samples")
		smoothedLevel = 0.05
		waveformSamples = Array(repeating: 0.05, count: maxWaveformSamples)
	}

	func clearUploadFeedback() {
		logger.debug("Clearing upload feedback")
		uploadMessage = nil
		classifyAnswer = nil
	}

	private static func wavDurationSeconds(at url: URL) throws -> Double {
		let file = try AVAudioFile(forReading: url)
		let rate = file.fileFormat.sampleRate
		guard rate > 0 else { return 0 }
		return Double(file.length) / rate
	}

	private static func decodeClassifyResponse(from data: Data) throws -> ClassifyAnswer {
		let decoder = JSONDecoder()
		if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
		   obj["items"] is [Any] {
			let batch = try decoder.decode(BatchClassifyResponse.self, from: data)
			guard let first = batch.items.first else {
				throw NSError(
					domain: "Upload",
					code: -3,
					userInfo: [NSLocalizedDescriptionKey: "Пустой ответ batch"]
				)
			}
			return first
		}
		return try decoder.decode(ClassifyAnswer.self, from: data)
	}

	private struct WavFormat: Equatable {
		let sampleRate: UInt32
		let channels: UInt16
		let bitsPerSample: UInt16
	}

	/// Один сегмент — как есть; несколько — склейка PCM в один WAV (те же параметры, что у `AVAudioRecorder`).
	private static func makeUploadURL(from segments: [URL]) throws -> URL {
		guard !segments.isEmpty else {
			throw NSError(domain: "AudioRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Нет сегментов записи"])
		}
		if segments.count == 1 {
			return segments[0]
		}
		return try mergeWavSegmentFiles(segments)
	}

	private static func mergeWavSegmentFiles(_ urls: [URL]) throws -> URL {
		var combinedPCM = Data()
		var refFormat: WavFormat?
		for url in urls {
			let data = try Data(contentsOf: url)
			let (fmt, pcm) = try extractWavPCM(data)
			if let r = refFormat {
				guard r == fmt else {
					throw NSError(domain: "AudioRecorder", code: 3, userInfo: [NSLocalizedDescriptionKey: "Формат WAV сегментов не совпадает"])
				}
			} else {
				refFormat = fmt
			}
			combinedPCM.append(pcm)
		}
		guard let format = refFormat else {
			throw NSError(domain: "AudioRecorder", code: 4, userInfo: [NSLocalizedDescriptionKey: "Не удалось прочитать WAV"])
		}
		let wavData = buildWav(pcm: combinedPCM, format: format)
		let out = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
			.appendingPathComponent("merged-\(Int(Date().timeIntervalSince1970)).wav")
		try wavData.write(to: out, options: .atomic)
		logger.info("Merged \(urls.count) segments into \(out.lastPathComponent)")
		return out
	}

	private static func extractWavPCM(_ data: Data) throws -> (WavFormat, Data) {
		guard data.count >= 12 else {
			throw NSError(domain: "AudioRecorder", code: 5, userInfo: [NSLocalizedDescriptionKey: "Слишком короткий WAV"])
		}
		guard String(data: data.subdata(in: 0..<4), encoding: .ascii) == "RIFF",
			  String(data: data.subdata(in: 8..<12), encoding: .ascii) == "WAVE" else {
			throw NSError(domain: "AudioRecorder", code: 6, userInfo: [NSLocalizedDescriptionKey: "Некорректный RIFF/WAVE"])
		}
		var offset = 12
		var format: WavFormat?
		var pcm = Data()
		while offset + 8 <= data.count {
			let chunkId = String(data: data.subdata(in: offset..<(offset + 4)), encoding: .ascii) ?? ""
			let chunkSize = Int(readUInt32LE(data, at: offset + 4))
			let contentStart = offset + 8
			let contentEnd = contentStart + chunkSize
			guard contentEnd <= data.count else {
				throw NSError(domain: "AudioRecorder", code: 7, userInfo: [NSLocalizedDescriptionKey: "Обрезанный WAV"])
			}
			if chunkId == "fmt " {
				let channels = readUInt16LE(data, at: contentStart + 2)
				let sampleRate = readUInt32LE(data, at: contentStart + 4)
				let bits = readUInt16LE(data, at: contentStart + 14)
				format = WavFormat(sampleRate: sampleRate, channels: channels, bitsPerSample: bits)
			} else if chunkId == "data" {
				pcm.append(data.subdata(in: contentStart..<contentEnd))
			}
			offset = contentEnd + (chunkSize % 2)
		}
		guard let f = format, !pcm.isEmpty else {
			throw NSError(domain: "AudioRecorder", code: 8, userInfo: [NSLocalizedDescriptionKey: "Нет PCM в WAV"])
		}
		return (f, pcm)
	}

	private static func buildWav(pcm: Data, format: WavFormat) -> Data {
		let blockAlign = UInt16(format.channels) * format.bitsPerSample / 8
		let byteRate = format.sampleRate * UInt32(blockAlign)
		let dataSize = UInt32(pcm.count)
		let riffChunkSize = 36 + dataSize

		var out = Data()
		out.append(contentsOf: "RIFF".utf8)
		out.append(contentsOf: riffChunkSize.leBytes)
		out.append(contentsOf: "WAVE".utf8)
		out.append(contentsOf: "fmt ".utf8)
		out.append(contentsOf: UInt32(16).leBytes)
		out.append(contentsOf: UInt16(1).leBytes)
		out.append(contentsOf: format.channels.leBytes)
		out.append(contentsOf: format.sampleRate.leBytes)
		out.append(contentsOf: byteRate.leBytes)
		out.append(contentsOf: blockAlign.leBytes)
		out.append(contentsOf: format.bitsPerSample.leBytes)
		out.append(contentsOf: "data".utf8)
		out.append(contentsOf: dataSize.leBytes)
		out.append(pcm)
		return out
	}

	private static func readUInt16LE(_ data: Data, at offset: Int) -> UInt16 {
		data.withUnsafeBytes { buf in
			buf.loadUnaligned(fromByteOffset: offset, as: UInt16.self).littleEndian
		}
	}

	private static func readUInt32LE(_ data: Data, at offset: Int) -> UInt32 {
		data.withUnsafeBytes { buf in
			buf.loadUnaligned(fromByteOffset: offset, as: UInt32.self).littleEndian
		}
	}
}

private extension FixedWidthInteger {
	var leBytes: Data {
		var v = self.littleEndian
		return Swift.withUnsafeBytes(of: &v) { Data($0) }
	}
}

private extension Data {
	mutating func append(_ string: String) {
		guard let data = string.data(using: .utf8) else { return }
		append(data)
	}

	mutating func appendMultipartField(boundary: String, name: String, value: String) {
		append("--\(boundary)\r\n")
		append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
		append(value)
		append("\r\n")
	}
}
