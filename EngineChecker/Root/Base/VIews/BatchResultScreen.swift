//
//  BatchResultScreen.swift
//  EngineChecker
//
//  Created by Anastasia on 18.04.2026.
//

import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.enginechecker.app", category: "BatchResultScreen")

struct BatchResultScreen: View {
	@EnvironmentObject var mainScreenModelView: MainScreenVIewModel
	@State private var selectedIndex: Int = 0
	
	var body: some View {
		ZStack {
			Color.background
				.ignoresSafeArea()
			
			VStack {
				headerView
				
				if let response = mainScreenModelView.batchResponse {
					summaryView(response: response)
					
					TabView(selection: $selectedIndex) {
						ForEach(Array(response.items.enumerated()), id: \.element.id) { index, item in
							BatchItemResultView(item: item, index: index + 1, total: response.items.count)
								.tag(index)
						}
					}
					.tabViewStyle(.page(indexDisplayMode: .automatic))
					.indexViewStyle(.page(backgroundDisplayMode: .always))
				} else {
					Spacer()
					Text("No data available")
						.foregroundStyle(Color.gray)
					Spacer()
				}
				
				newScanButton
			}
		}
	}
	
	private var headerView: some View {
		VStack {
			HStack {
				Text("BATCH ANALYSIS")
					.font(.custom("Orbitron-Bold", size: 25))
					.fontWeight(.semibold)
					.foregroundStyle(Color.white)
				Spacer()
			}
			.padding()
			
			RoundedRectangle(cornerRadius: 15)
				.fill(
					LinearGradient(
						gradient: Gradient(colors: [Color.accent, Color(#colorLiteral(red: 0.8336152434, green: 0.3937123716, blue: 0.1215411201, alpha: 1)), Color.background]),
						startPoint: .leading,
						endPoint: .trailing
					)
				)
				.frame(height: 5)
				.padding(.horizontal)
		}
	}
	
	private func summaryView(response: BatchClassifyResponse) -> some View {
		HStack(spacing: 20) {
			summaryItem(title: "TOTAL", value: "\(response.total)", color: .white)
			summaryItem(title: "SUCCESS", value: "\(response.successful)", color: .green)
			summaryItem(title: "FAILED", value: "\(response.failed)", color: .red)
		}
		.padding()
	}
	
	private func summaryItem(title: String, value: String, color: Color) -> some View {
		VStack {
			Text(value)
				.font(.custom("Orbitron-Bold", size: 24))
				.foregroundStyle(color)
			Text(title)
				.font(.caption)
				.foregroundStyle(Color.gray)
		}
		.frame(maxWidth: .infinity)
	}
	
	private var newScanButton: some View {
		Button {
			logger.info("New Scan button tapped - returning to start")
			mainScreenModelView.batchResponse = nil
			withAnimation(.easeInOut(duration: 0.4)) {
				mainScreenModelView.screen = .start
			}
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
		.padding(.bottom, 30)
	}
}

struct BatchItemResultView: View {
	let item: ClassifyAnswer
	let index: Int
	let total: Int
	@State private var animatedScore: Double = 0
	
	var body: some View {
		VStack {
			Text("\(index) / \(total)")
				.font(.caption)
				.foregroundStyle(Color.gray)
				.padding(.top, 10)
			
			if let filename = item.filename {
				Text(filename)
					.font(.custom("Orbitron-Bold", size: 16))
					.foregroundStyle(Color.white)
					.lineLimit(1)
					.truncationMode(.middle)
					.padding(.horizontal)
			}
			
			Image(systemName: !(item.result ?? false) ? "checkmark.circle" : "xmark.circle")
				.resizable()
				.frame(width: 70, height: 70)
				.foregroundStyle(!(item.result ?? false) ? Color.green : Color.red)
				.padding(.vertical, 15)
			
			Text(!(item.result ?? false) ? "Healthy" : "Anomaly Detected")
				.font(.custom("Orbitron-Bold", size: 22))
				.foregroundStyle(!(item.result ?? false) ? Color.green : Color.red)
			
			if let message = item.label {
				Text(message)
					.font(.subheadline)
					.foregroundStyle(Color.gray)
					.multilineTextAlignment(.center)
					.padding(.horizontal)
			}
			
			HStack(alignment: .bottom) {
				Text("ANOMALY SCORE")
					.foregroundStyle(Color.gray)
				Spacer()
				Text(String(format: "%.2f", item.anomalyScore ?? 0))
					.font(.title)
					.fontWeight(.bold)
					.foregroundStyle(Color.white)
			}
			.padding(.horizontal)
			.padding(.top, 10)
			
			scoreLineView
				.padding(.horizontal)
				.padding(.vertical, 5)
			
			serverResponseView
			
			Spacer()
		}
	}
	
	private var scoreLineView: some View {
		let targetScore = item.anomalyScore ?? 0
		
		return GeometryReader { geo in
			let w = geo.size.width
			ZStack(alignment: .leading) {
				RoundedRectangle(cornerRadius: 15)
					.stroke(Color.accent, lineWidth: 3)
					.frame(height: 30)
				Capsule()
					.fill(Color.accent)
					.frame(width: w * CGFloat(animatedScore), height: 30)
				HStack {
					Spacer()
					Text(String(format: "%.1f", animatedScore * 100) + "%")
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
			if targetScore > 0 {
				withAnimation(.easeOut(duration: 1.2)) {
					animatedScore = targetScore
				}
			}
		}
	}
	
	private var serverResponseView: some View {
		ZStack {
			RoundedRectangle(cornerRadius: 15)
				.stroke(lineWidth: 2)
				.fill(Color.accent)
				.opacity(0.6)
				.frame(height: 130)
				.padding(.horizontal, 20)
			RoundedRectangle(cornerRadius: 15)
				.fill(Color.accent)
				.opacity(0.1)
				.frame(height: 130)
				.padding(.horizontal, 20)
			
			VStack(alignment: .leading, spacing: 8) {
				Text("SERVER RESPONSE")
					.font(.caption)
					.padding(.bottom, 5)
				
				HStack {
					Text("result: ")
					Text("\(item.result ?? false)")
						.foregroundStyle(Color.accent)
				}
				
				HStack {
					Text("message: ")
					Text(item.label ?? "—")
						.lineLimit(1)
				}
				
				HStack {
					Text("anomaly_score: ")
					Text(String(format: "%.4f", item.anomalyScore ?? 0))
						.foregroundStyle(Color(#colorLiteral(red: 1, green: 0.4225196242, blue: 0.007212365046, alpha: 1)))
				}
			}
			.font(.caption)
			.foregroundStyle(Color.gray)
			.padding(.horizontal, 40)
		}
		.padding(.top, 10)
	}
}

#Preview {
	let vm = MainScreenVIewModel()
	vm.batchResponse = BatchClassifyResponse(
		items: [
			ClassifyAnswer(filename: "engine_sound_1.wav", result: true, message: "Normal operation", anomalyScore: 0.12),
			ClassifyAnswer(filename: "engine_sound_2.wav", result: false, message: "Anomaly detected", anomalyScore: 0.87),
			ClassifyAnswer(filename: "test_recording.wav", result: true, message: "All good", anomalyScore: 0.05)
		],
		total: 3,
		successful: 2,
		failed: 1
	)
	return BatchResultScreen()
		.environmentObject(vm)
}
