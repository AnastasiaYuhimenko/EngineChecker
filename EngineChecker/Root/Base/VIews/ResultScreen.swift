//
//  ResultScreen.swift
//  EngineChecker
//
//  Created by Anastasia on 17.04.2026.
//

import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.enginechecker.app", category: "ResultScreen")

struct ResultScreen: View {
	@EnvironmentObject var mainScreenModelView: MainScreenVIewModel
	@State private var animatedScore: Double = 0
	
	private var classification: ClassifyAnswer? {
		mainScreenModelView.recorder.classifyAnswer
	}
	
	private var isHealthy: Bool { classification?.result != true }
	private var isAwaitingResult: Bool {
		mainScreenModelView.recorder.isUploading && classification == nil
	}
	
    var body: some View {
		ZStack {
			Color.background
				.ignoresSafeArea()
			
			VStack {
				HStack {
					Text("ANALYSIS COMPLETE")
						.font(.custom("Orbitron-Bold", size: 25))
						.fontWeight(.semibold)
						.foregroundStyle(Color.white)
					
					Spacer()
				}
				.padding()
				RoundedRectangle(cornerRadius: 15)
					.fill(
						LinearGradient(gradient: Gradient(colors: [Color.accent, Color(#colorLiteral(red: 0.8336152434, green: 0.3937123716, blue: 0.1215411201, alpha: 1)), Color.background]), startPoint: .leading, endPoint: .trailing)
						)
					.frame(height: 5)
					.padding(.horizontal)
					.padding(.bottom)
				Spacer()
				Group {
					if isAwaitingResult {
						ProgressView()
							.scaleEffect(1.4)
							.tint(Color.accent)
							.frame(width: 70, height: 70)
					} else {
						Image(systemName: isHealthy ? "checkmark.circle" : "xmark.circle")
							.resizable()
							.frame(width: 70, height: 70)
							.foregroundStyle(isHealthy ? Color.green : Color.red)
					}
				}

				
				Group {
					if isAwaitingResult {
						Text("Analyzing…")
							.font(.custom("Orbitron-Bold", size: 22))
							.foregroundStyle(Color.gray)
					} else {
						Text(isHealthy ? "Healthy" : "Anomaly Detected")
							.font(.custom("Orbitron-Bold", size: 22))
							.foregroundStyle(isHealthy ? Color.green : Color.red)
					}
				}
				
				if let message = classification?.message, !isAwaitingResult {
					Text(message)
						.font(.subheadline)
						.foregroundStyle(Color.gray)
						.multilineTextAlignment(.center)
						.padding(.horizontal)
				}
				Spacer()
				HStack(alignment: .bottom) {
					Text("ANOMALY SCORE")
						.foregroundStyle(Color.gray)
					Spacer()
					Text("\(String(format: "%.2f", classification?.anomalyScore ?? 0))")
						.font(.title)
						.fontWeight(.bold)
						.foregroundStyle(Color.white)
						.offset(y: 5)
				}
				.padding(.horizontal)
				scoreLine
					.padding(.horizontal)
					.padding(.bottom, 25)
				
				
				ZStack {
					RoundedRectangle(cornerRadius: 15)
						.stroke(Color.accent.opacity(0.6), lineWidth: 2)
						.background(
							RoundedRectangle(cornerRadius: 15)
								.fill(Color.accent.opacity(0.1))
						)
						.frame(height: 170)
						.padding(.horizontal, 24)
					
					VStack(alignment: .leading, spacing: 8) {
						Text("SERVER RESPONSE")
							.font(.subheadline)
							.padding(.bottom, 4)
							.offset(y: -20)
						HStack {
							Text("result: ")
								.font(.footnote)
							Text((classification?.result).map { String($0) } ?? "—")
								.foregroundStyle(Color.accent)
								.font(.footnote)
						}
						
						HStack(alignment: .top) {
							Text("message: ")
								.font(.footnote)
							Text(classification?.message ?? "—")
								.lineLimit(3)
								.font(.footnote)
						}
						
						HStack {
							Text("anomaly_score: ")
								.font(.footnote)
							Text("\(String(format: "%.2f", classification?.anomalyScore ?? 0))")
								.foregroundStyle(Color(#colorLiteral(red: 1, green: 0.4225196242, blue: 0.007212365046, alpha: 1)))
								.font(.footnote)
						}
					}
					.font(.caption)
					.foregroundStyle(Color.gray)
					.frame(maxWidth: .infinity, alignment: .leading)
					.padding(.horizontal, 40)
					
				}
				Spacer()
			Button {
				logger.info("New Scan button tapped - resetting state")
				mainScreenModelView.answer = nil
				mainScreenModelView.recorder = AudioRecorder()
				withAnimation(.easeInOut(duration: 0.4)) {
					mainScreenModelView.screen = .start
				}
				logger.debug("State reset completed - returning to start screen")
			} label: {
					ZStack {
						RoundedRectangle(cornerRadius: 15)
							.stroke(lineWidth: 3)
							.frame(width: 300, height: 60)
						RoundedRectangle(cornerRadius: 15)
							.opacity(0.2)
							.frame(width: 300, height: 60)
						HStack {
							Image(systemName: "arrow.clockwise")
								.font(.title)
							Text("NEW SCAN")
								.font(.custom("Orbitron-Bold", size: 20))
						}
						.foregroundStyle(Color.white)
					}
					
				}
				Spacer()
			}
		}
    }
}

#Preview {
	let healthy = ClassifyAnswer(result: true, message: "Normal operation", anomalyScore: 0.08)
	ResultScreen()
		.environmentObject(MainScreenVIewModel(recorder: AudioRecorder(answer: healthy)))
}


extension ResultScreen {
	private var scoreLine: some View {
		let targetScore = classification?.anomalyScore ?? 0
		
		return GeometryReader { geo in
			let w = geo.size.width
			ZStack(alignment: .leading) {
				RoundedRectangle(cornerRadius: 15)
					.stroke(Color.accentColor, lineWidth: 3)
					.frame(height: 30)
				Capsule()
					.fill(Color.accentColor)
					.frame(width: w * CGFloat(animatedScore), height: 30)
				HStack {
					Spacer()
					Text("\(String(format: "%.1f", animatedScore * 100))%")
						.foregroundStyle(Color.white)
						.fontWeight(.bold)
						.contentTransition(.numericText())
					Spacer()
				}
			}
			.frame(height: 30)
		}
		.frame(height: 30)
		.onAppear {
			withAnimation(.easeOut(duration: 1.2)) {
				animatedScore = targetScore
			}
		}
		.onChange(of: targetScore) { _, newValue in
			withAnimation(.easeOut(duration: 1.2)) {
				animatedScore = newValue
			}
		}
	}
}
