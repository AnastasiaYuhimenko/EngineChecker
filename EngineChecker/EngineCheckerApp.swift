//
//  EngineCheckerApp.swift
//  EngineChecker
//
//  Created by Anastasia on 17.04.2026.
//

import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.enginechecker.app", category: "App")

@main
struct EngineCheckerApp: App {
	@StateObject private var mainScreenViewModel = MainScreenVIewModel()
	
	init() {
		logger.info("EngineCheckerApp launched")
	}
	
    var body: some Scene {
        WindowGroup {
			MainScreen()
				.preferredColorScheme(.light)
				.environmentObject(mainScreenViewModel)
				.onAppear {
					logger.info("Main window appeared")
				}
        }
    }
}
