//
//  AnswersFromAPI.swift
//  EngineChecker
//
//  Created by Anastasia on 17.04.2026.
//

import Foundation

struct ClassifyAnswer: Codable, Identifiable {
	var id: String { filename ?? UUID().uuidString }
	let filename: String?
	let result: Bool?
	let message: String?
	let anomalyScore: Double?

	enum CodingKeys: String, CodingKey {
		case filename, result, message
		case anomalyScore = "anomaly_score"
	}

	init(filename: String? = nil, result: Bool? = nil, message: String? = nil, anomalyScore: Double? = nil) {
		self.filename = filename
		self.result = result
		self.message = message
		self.anomalyScore = anomalyScore
	}
}

struct BatchClassifyResponse: Codable {
	let items: [ClassifyAnswer]
	let total: Int
	let successful: Int
	let failed: Int
}
