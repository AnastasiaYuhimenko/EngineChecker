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

	private var stopOrContinueLabel: String {
		let r = mainScreenViewModel.recorder
		if r.isUploading { return "Sending..." }
		if r.isRecording { return "Stop" }
		if r.canContinueRecording { return "Continue" }
		return "Record"
	}

    var body: some View {
		ZStack {
			Color.background
				.ignoresSafeArea()
			NotebookGrid(cellSize: 40)
				.foregroundStyle(Color.cletka)
				.ignoresSafeArea()
			
			VStack() {
				VechicleIdField
				
				segmentTypePicker
				
				LiveWaveformView(samples: mainScreenViewModel.recorder.waveformSamples, isRecording: mainScreenViewModel.recorder.isRecording)
					.frame(height: 100)
					.padding(.horizontal)
				HStack {
					Button {
						logger.info("Stop button tapped")
						if mainScreenViewModel.recorder.isRecording {
							logger.debug("Stopping active recording")
							mainScreenViewModel.recorder.stopRecording()
						} else if mainScreenViewModel.recorder.canContinueRecording {
							logger.debug("Continuing recording session")
							mainScreenViewModel.recorder.continueRecording()
						} else {
							mainScreenViewModel.recorder.startRecording()
						}
					} label: {
						ZStack {
							RoundedRectangle(cornerRadius: 15)
								.foregroundStyle(Color.accent)
								.frame(width: 150, height: 50)
								.opacity(0.3)
							RoundedRectangle(cornerRadius: 15)
								.stroke(lineWidth: 3)
								.foregroundStyle(Color.accent)
							
								.frame(width: 150, height: 50)
							Text(stopOrContinueLabel)
								.foregroundStyle(Color.white)
								.font(.custom("Orbitron-Bold", size: 24))
						}
					}
					.padding(.trailing)
					
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
								.frame(width: 150, height: 50)
								.opacity(0.3)
							RoundedRectangle(cornerRadius: 15)
								.stroke(lineWidth: 3)
								.foregroundStyle(Color.accent)
							
								.frame(width: 150, height: 50)
							Text(mainScreenViewModel.recorder.isUploading ? "Sending..." : "Send")
								.foregroundStyle(Color.white)
								.font(.custom("Orbitron-Bold", size: 24))
						}
					}
					.padding(.leading)
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
					.frame(width: 3.5, height: max(6, samples[index] * 60))
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


extension ScanScreen {
	var VechicleIdField: some View {
		TextField(
			"",
			text: $mainScreenViewModel.recorder.vehicleId,
			prompt: Text("Vechicle ID").foregroundStyle(Color.white.opacity(0.65))
		)
		.textFieldStyle(.plain)
		.textInputAutocapitalization(.never)
		.autocorrectionDisabled()
		.tint(Color.white)
		.foregroundStyle(Color.white)
		.padding(.horizontal, 12)
		.frame(height: 40)
		.contentShape(Rectangle())
		.background(
			RoundedRectangle(cornerRadius: 10)
				.stroke(Color.accent, lineWidth: 3)
		)
		.padding()
	}
	
	var segmentTypePicker: some View {
		HStack(spacing: 30) {
			ForEach(RequestModel.SegmentType.allCases, id: \.self) { type in
				Button {
					mainScreenViewModel.recorder.segmentType = type
				} label: {
					Text(type.rawValue)
						.font(.system(size: 14, weight: .medium))
						.foregroundStyle(mainScreenViewModel.recorder.segmentType == type ? Color.white : Color.white.opacity(0.5))
						.padding(.vertical, 10)
						.padding(.horizontal, 16)
						.background(
							RoundedRectangle(cornerRadius: 8)
								.fill(mainScreenViewModel.recorder.segmentType == type ? Color.accent.opacity(0.3) : Color.clear)
						)
						.overlay(
							RoundedRectangle(cornerRadius: 8)
								.stroke(mainScreenViewModel.recorder.segmentType == type ? Color.accent : Color.gray, lineWidth: 2)
						)
				}
			
			}
		}
		.padding(.horizontal)
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.horizontal)
	}
}

