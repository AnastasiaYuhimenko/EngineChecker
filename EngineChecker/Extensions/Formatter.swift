//
//  Formatter.swift
//  EngineChecker
//
//  Created by Anastasia on 17.04.2026.
//

import Foundation

extension Double {
	// конвертирует значение типа Double в тип String, оставляет 2 знака после запятой
	/// ```
	/// 1.23456 -> "1.23"
	/// ```
	func convertNumberToString2() -> String {
		return String(format: "%.2f", self)
	}
	
	// конвертирует значение типа Double в тип String, оставляет 2 знака после запятой, добавляет знак процента(%)
	/// ```
	/// 1.23456 -> "1.23%"
	/// ```
	func convertToProcent() -> String {
		return self.convertNumberToString2() + "%"
	}
}
