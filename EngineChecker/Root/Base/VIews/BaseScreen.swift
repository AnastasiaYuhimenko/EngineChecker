//
//  BaseScreen.swift
//  EngineChecker
//
//  Created by Anastasia on 17.04.2026.
//

import SwiftUI
import UniformTypeIdentifiers
import os.log

private let logger = Logger(subsystem: "com.enginechecker.app", category: "BaseScreen")

struct NotebookGrid: View {
	var cellSize: CGFloat = 20 
	
	var body: some View {
		GeometryReader { proxy in
			ZStack {
				gridPath(size: proxy.size, spacing: cellSize)
					.stroke(Color.cletka.opacity(0.3), lineWidth: 2)

			}
			.ignoresSafeArea()
		}
	}
	
	func gridPath(size: CGSize, spacing: CGFloat) -> Path {
		Path { path in
			var x = spacing
			while x < size.width {
				path.move(to: CGPoint(x: x, y: 0))
				path.addLine(to: CGPoint(x: x, y: size.height))
				x += spacing
			}
			
			
			var y = spacing
			while y < size.height {
				path.move(to: CGPoint(x: 0, y: y))
				path.addLine(to: CGPoint(x: size.width, y: y))
				y += spacing
			}
		}
	}
}

struct BaseScreen: View {
	@EnvironmentObject var mainScreenViewModel: MainScreenVIewModel
	@State private var showFilePicker = false
	
    var body: some View {
		ZStack {
			Color.background
				.ignoresSafeArea()
			NotebookGrid(cellSize: 40)
				.foregroundStyle(Color.cletka)
				.ignoresSafeArea()
			
			VStack {
				VStack {
					Text("MOTOR")
						.font(.custom("Orbitron-Bold", size: 35))
						.foregroundStyle(Color.white)
						.padding(.top, 50)
					
					Text("diagnostics")
						.font(.custom("OrbitronMedium", size: 25))
						.foregroundStyle(Color.white)
						.opacity(0.6)
				}
				.offset(y: 55)
				Spacer()
				
			Button {
				logger.info("Start recording button tapped")
				if !mainScreenViewModel.recorder.isRecording {
					logger.debug("Recorder not recording - starting recording")
					mainScreenViewModel.recorder.startRecording()
				} else {
					logger.debug("Recorder already recording - skipping start")
				}
				withAnimation(.easeInOut(duration: 0.4)) {
					mainScreenViewModel.screen = .scan
				}
			} label: {
					ZStack {
						ZStack {
							Circle()
								.fill(Color.accent.opacity(0.1))
								.frame(width: 170, height: 170)
							Circle()
								.stroke(Color.accent, lineWidth: 2)
								.frame(width: 150, height: 150)
						}
						.compositingGroup()
						.shadow(color: Color.accent, radius: 70)
						.padding(72)
						
						Image(systemName: "microphone")
							.resizable()
							.foregroundStyle(Color.accentColor)
							.frame(width: 35, height: 50)
					}
				}
				.buttonStyle(.plain)
				
				Button {
					logger.info("Upload ZIP button tapped")
					showFilePicker = true
				} label: {
					ZStack {
						RoundedRectangle(cornerRadius: 15)
							.stroke(Color.accent, lineWidth: 2)
							.frame(width: 200, height: 50)
						RoundedRectangle(cornerRadius: 15)
							.fill(Color.accent.opacity(0.1))
							.frame(width: 200, height: 50)
						HStack {
							Image(systemName: "doc.zipper")
								.font(.title2)
							Text("BATCH SCAN")
								.font(.custom("Orbitron-Bold", size: 16))
						}
						.foregroundStyle(Color.accent)
					}
				}
				.buttonStyle(.plain)
				.padding(.bottom, 20)
				
				if mainScreenViewModel.isUploadingZip {
					ProgressView()
						.progressViewStyle(CircularProgressViewStyle(tint: .accent))
						.scaleEffect(1.2)
						.padding()
				}
				
				if let error = mainScreenViewModel.zipUploadError {
					Text(error)
						.foregroundStyle(Color.red)
						.font(.caption)
						.multilineTextAlignment(.center)
						.padding(.horizontal)
				}
				
				Spacer()
			}
		}
		.fileImporter(
			isPresented: $showFilePicker,
			allowedContentTypes: [UTType.zip],
			allowsMultipleSelection: false
		) { result in
			switch result {
			case .success(let urls):
				if let url = urls.first {
					logger.info("File selected: \(url.lastPathComponent)")
					mainScreenViewModel.uploadZipFile(url: url)
				}
			case .failure(let error):
				logger.error("File picker error: \(error.localizedDescription)")
				mainScreenViewModel.zipUploadError = error.localizedDescription
			}
		}
    }
}

#Preview {
    BaseScreen()
		.environmentObject(MainScreenVIewModel())
}
