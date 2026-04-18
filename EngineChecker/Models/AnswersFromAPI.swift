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
	let label: String?
	let anomalyScore: Double?
	let rpmEstimate: Double?
	let model_version: String
	/// Если сервер отдаёт флаг аномалии отдельно от текста (`label` / `message`).
	let result: Bool?

	enum CodingKeys: String, CodingKey {
		case filename
		case label
		case message
		case result
		case anomalyScore = "anomaly_score"
		case rpmEstimate = "rpm_estimate"
		case model_version
	}

	init(
		filename: String? = nil,
		label: String? = nil,
		anomalyScore: Double? = nil,
		rpmEstimate: Double? = nil,
		model_version: String = "",
		result: Bool? = nil
	) {
		self.filename = filename
		self.label = label
		self.anomalyScore = anomalyScore
		self.rpmEstimate = rpmEstimate
		self.model_version = model_version
		self.result = result
	}

	/// Совместимость с превью и моками: `message` уходит в `label`.
	init(filename: String? = nil, result: Bool?, message: String?, anomalyScore: Double?, rpmEstimate: Double? = nil, model_version: String = "") {
		self.filename = filename
		self.label = message
		self.anomalyScore = anomalyScore
		self.rpmEstimate = rpmEstimate
		self.model_version = model_version
		self.result = result
	}

	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		filename = try c.decodeIfPresent(String.self, forKey: .filename)
		if let l = try c.decodeIfPresent(String.self, forKey: .label) {
			label = l
		} else if let m = try c.decodeIfPresent(String.self, forKey: .message) {
			label = m
		} else {
			label = nil
		}
		anomalyScore = try c.decodeIfPresent(Double.self, forKey: .anomalyScore)
		rpmEstimate = try c.decodeIfPresent(Double.self, forKey: .rpmEstimate)
		model_version = try c.decodeIfPresent(String.self, forKey: .model_version) ?? ""
		result = try c.decodeIfPresent(Bool.self, forKey: .result)
	}

	func encode(to encoder: Encoder) throws {
		var c = encoder.container(keyedBy: CodingKeys.self)
		try c.encodeIfPresent(filename, forKey: .filename)
		try c.encodeIfPresent(label, forKey: .label)
		try c.encodeIfPresent(anomalyScore, forKey: .anomalyScore)
		try c.encodeIfPresent(rpmEstimate, forKey: .rpmEstimate)
		try c.encode(model_version, forKey: .model_version)
		try c.encodeIfPresent(result, forKey: .result)
	}
}

struct BatchClassifyResponse: Codable {
	let items: [ClassifyAnswer]
	let total: Int
	let successful: Int
	let failed: Int
}
