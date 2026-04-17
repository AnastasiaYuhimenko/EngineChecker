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
			resetWaveform()
			startMeterUpdates()
			logger.info("Recording started successfully")
		} catch {
			logger.error("Failed to start recording: \(error.localizedDescription)")
		}
	}

	func stopRecording() {
		logger.info("stopRecording called")
		audioRecorder?.stop()
		isRecording = false
		stopMeterUpdates()
		if let url = lastRecordingURL {
			logger.info("Recording stopped. File saved at: \(url.path)")
		}
	}

	func uploadLastRecording() {
		logger.info("uploadLastRecording called")
		guard let fileURL = lastRecordingURL else {
			logger.warning("No recording file available for upload")
			uploadMessage = "Нет записи для отправки"
			return
		}
		logger.info("Preparing to upload file: \(fileURL.lastPathComponent)")

		Task {
			await MainActor.run {
				self.isUploading = true
				self.uploadMessage = nil
				self.classifyAnswer = nil
			}
			logger.debug("Upload state set - isUploading: true")

			do {
				let responseBody = try await uploadFile(fileURL: fileURL)
				logger.info("Upload successful - result: \(responseBody.result ?? false), anomalyScore: \(responseBody.anomalyScore ?? -1)")
				await MainActor.run {
					self.classifyAnswer = responseBody
					self.uploadMessage = responseBody.message ?? "Успешно отправлено"
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

		let fileData = try Data(contentsOf: fileURL)
		logger.debug("File data loaded - size: \(fileData.count) bytes")
		
		var body = Data()
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
			let decoded = try JSONDecoder().decode(ClassifyAnswer.self, from: data)
			logger.info("Response decoded successfully - result: \(decoded.result ?? false), message: \(decoded.message ?? "nil")")
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
}

private extension Data {
	mutating func append(_ string: String) {
		guard let data = string.data(using: .utf8) else { return }
		append(data)
	}
}
