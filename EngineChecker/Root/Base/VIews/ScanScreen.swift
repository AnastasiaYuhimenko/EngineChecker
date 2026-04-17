//
//  ScanScreen.swift
//  EngineChecker
//
//  Created by Anastasia on 17.04.2026.
//

import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.enginechecker.app", category: "ScanScreen")

struct ScanScreen: View {
	@EnvironmentObject var mainScreenViewModel: MainScreenVIewModel
    var body: some View {
		NavigationStack {
			ZStack {
				Color.background
					.ignoresSafeArea()
				NotebookGrid(cellSize: 40)
					.foregroundStyle(Color.cletka)
					.ignoresSafeArea()
				
				VStack {
					LiveWaveformView(samples: mainScreenViewModel.recorder.waveformSamples, isRecording: mainScreenViewModel.recorder.isRecording)
						.frame(height: 100)
						.padding(.horizontal)
					
				Button {
					logger.info("Send button tapped")
					if mainScreenViewModel.recorder.isRecording {
						logger.debug("Stopping active recording before upload")
						mainScreenViewModel.recorder.stopRecording()
					}
					logger.info("Initiating upload and navigating to result screen")
					mainScreenViewModel.recorder.uploadLastRecording()
					withAnimation(.easeInOut(duration: 0.4)) {
						mainScreenViewModel.screen = .result
					}
				} label: {
						ZStack {
								RoundedRectangle(cornerRadius: 15)
								.foregroundStyle(Color.accent)
								.frame(width: 230, height: 50)
								.opacity(0.3)
								RoundedRectangle(cornerRadius: 15)
								.stroke(lineWidth: 3)
								.foregroundStyle(Color.accent)
							
								.frame(width: 230, height: 50)
							Text(mainScreenViewModel.recorder.isUploading ? "Sending..." : "Send")
								.foregroundStyle(Color.white)
								.font(.custom("Orbitron-Bold", size: 24))
						}
					}
				}
			}
		}
    }
}

#Preview {
	ScanScreen()
		.environmentObject(MainScreenVIewModel(recorder: AudioRecorder(answer: AnswerMockData.shared.answer)))
}



private struct LiveWaveformView: View {
	let samples: [CGFloat]
	let isRecording: Bool

	var body: some View {
		HStack(alignment: .center, spacing: 0) {
			ForEach(samples.indices, id: \.self) { index in
				Capsule()
					.fill(isRecording ? color(for: samples[index]) : Color.second.opacity(0.35))
					.frame(width: 3, height: max(6, samples[index] * 60))
			}
		}
		.frame(maxWidth: .infinity)
	}

	private func color(for sample: CGFloat) -> Color {
		let clamped = min(max(sample, 0), 1)
		let loudness = pow(clamped, 1.15)
		let hue = 0.60 - (0.58 * loudness)
		let saturation = 0.45 + (0.33 * loudness)
		let brightness = 0.88 + (0.10 * loudness)
		return Color(hue: hue, saturation: saturation, brightness: brightness)
			.opacity(0.82 + (0.18 * loudness))
	}
}
