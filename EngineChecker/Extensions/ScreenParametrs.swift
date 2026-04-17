//
//  ScreenParametrs.swift
//  EngineChecker
//
//  Created by Anastasia on 17.04.2026.
//

import Foundation
import SwiftUI

extension UIScreen {
	static var currentBounds: CGRect {
		UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
			.first?.screen.bounds ?? .zero
	}
}
