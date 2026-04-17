//
//  AnswerMockData.swift
//  EngineChecker
//
//  Created by Anastasia on 17.04.2026.
//

import Foundation

class AnswerMockData {
	static let shared = AnswerMockData()
	
	private init() {}
	
	let answer = ClassifyAnswer(
		result: false,
		message: "Normal",
		anomalyScore: 0.23
	)
	
}
