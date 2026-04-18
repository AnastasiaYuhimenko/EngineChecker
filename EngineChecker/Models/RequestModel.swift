//
//  RequestModel.swift
//  EngineChecker
//
//  Created by Anastasia on 18.04.2026.
//

import Foundation

struct RequestModel {
	var vehicleId: String
	let segmentType: SegmentType
	let durationSec: Double

	enum CodingKeys: String, CodingKey {
		case vehicleId = "vehicle_id"
		case segmentType = "segment_type"
		case durationSec = "duration_sec"
	}

	enum SegmentType: String, Codable, CaseIterable {
		case idle = "idle"
		case highHold = "high_hold"
		case background = "background"
	}

	init(vehicleId: String, durationSec: Double, segmentType: SegmentType = .idle) {
		self.vehicleId = vehicleId
		self.durationSec = durationSec
		self.segmentType = segmentType
	}
}


