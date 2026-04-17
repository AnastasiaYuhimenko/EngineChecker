//
//  MainScreenVIewModel.swift
//  EngineChecker
//
//  Created by Anastasia on 18.04.2026.
//

import Foundation
import Combine
import os.log
import SwiftUI

private let logger = Logger(subsystem: "com.enginechecker.app", category: "MainScreenViewModel")

enum curScreen: CustomStringConvertible, Equatable {
	case start
	case scan
	case result
	case batchResult
	
	var description: String {
		switch self {
		case .start: return "start"
		case .scan: return "scan"
		case .result: return "result"
		case .batchResult: return "batchResult"
		}
	}
}

class MainScreenVIewModel: ObservableObject {
	@Published var answer: ClassifyAnswer? {
		didSet {
			logger.debug("answer changed: \(self.answer != nil ? "set" : "nil")")
		}
	}
	@Published var recorder: AudioRecorder = AudioRecorder() {
		didSet {
			logger.debug("recorder instance replaced")
			subscribeToRecorder()
		}
	}
	@Published var screen: curScreen = .start {
		didSet {
			logger.info("Screen changed: \(oldValue.description) -> \(self.screen.description)")
		}
	}
	
	@Published var batchResponse: BatchClassifyResponse?
	@Published var isUploadingZip = false
	@Published var zipUploadError: String?
	
	private var recorderCancellable: AnyCancellable?
	
	init(answer: ClassifyAnswer? = nil, recorder: AudioRecorder = AudioRecorder(), screen: curScreen = .start) {
		logger.info("MainScreenVIewModel init - screen: \(screen.description), answer: \(answer != nil)")
		self.answer = answer
		self.recorder = recorder
		self.screen = screen
		subscribeToRecorder()
	}
	
	private func subscribeToRecorder() {
		recorderCancellable = recorder.objectWillChange
			.receive(on: DispatchQueue.main)
			.sink { [weak self] _ in
				self?.objectWillChange.send()
			}
	}
	
	func uploadZipFile(url: URL) {
		logger.info("uploadZipFile called with: \(url.lastPathComponent)")
		isUploadingZip = true
		zipUploadError = nil
		batchResponse = nil
		
		Task {
			do {
				let response = try await uploadZip(fileURL: url)
				logger.info("Batch upload successful - total: \(response.total), successful: \(response.successful)")
				await MainActor.run {
					self.batchResponse = response
					self.isUploadingZip = false
					withAnimation(.easeInOut(duration: 0.4)) {
						self.screen = .batchResult
					}
				}
			} catch {
				logger.error("Batch upload failed: \(error.localizedDescription)")
				await MainActor.run {
					self.zipUploadError = error.localizedDescription
					self.isUploadingZip = false
				}
			}
		}
	}
	
	private func uploadZip(fileURL: URL) async throws -> BatchClassifyResponse {
		let endpoint = URL(string: "http://178.154.233.146:8000/api/v1/audio/classify-batch")!
		logger.info("Starting ZIP upload to: \(endpoint.absoluteString)")
		
		var request = URLRequest(url: endpoint)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Accept")
		
		let boundary = "Boundary-\(UUID().uuidString)"
		request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
		
		let accessing = fileURL.startAccessingSecurityScopedResource()
		defer {
			if accessing {
				fileURL.stopAccessingSecurityScopedResource()
			}
		}
		
		let fileData = try Data(contentsOf: fileURL)
		logger.debug("ZIP file loaded - size: \(fileData.count) bytes")
		
		var body = Data()
		body.append("--\(boundary)\r\n".data(using: .utf8)!)
		body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
		body.append("Content-Type: application/zip\r\n\r\n".data(using: .utf8)!)
		body.append(fileData)
		body.append("\r\n".data(using: .utf8)!)
		body.append("--\(boundary)--\r\n".data(using: .utf8)!)
		
		request.httpBody = body
		
		let (data, response) = try await URLSession.shared.data(for: request)
		guard let httpResponse = response as? HTTPURLResponse else {
			throw NSError(domain: "Upload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Некорректный ответ сервера"])
		}
		
		let responseText = String(data: data, encoding: .utf8) ?? ""
		logger.debug("Server response - status: \(httpResponse.statusCode), body: \(responseText)")
		
		guard (200...299).contains(httpResponse.statusCode) else {
			throw NSError(
				domain: "Upload",
				code: httpResponse.statusCode,
				userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(responseText)"]
			)
		}
		
		return try JSONDecoder().decode(BatchClassifyResponse.self, from: data)
	}
}
