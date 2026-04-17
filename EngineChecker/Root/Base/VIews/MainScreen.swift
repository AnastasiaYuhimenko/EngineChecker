import SwiftUI

struct MainScreen: View {
	@EnvironmentObject var mainScreenViewModel: MainScreenVIewModel
	var body: some View {
		ZStack {
			Color.background
				.ignoresSafeArea()
			
			switch mainScreenViewModel.screen {
			case .start:
				BaseScreen()
					.transition(.asymmetric(
						insertion: .opacity.combined(with: .scale(scale: 0.95)),
						removal: .opacity.combined(with: .scale(scale: 1.05))
					))
			case .scan:
				ScanScreen()
					.transition(.asymmetric(
						insertion: .move(edge: .trailing).combined(with: .opacity),
						removal: .move(edge: .leading).combined(with: .opacity)
					))
			case .result:
				ResultScreen()
					.transition(.asymmetric(
						insertion: .move(edge: .trailing).combined(with: .opacity),
						removal: .opacity
					))
			case .batchResult:
				BatchResultScreen()
					.transition(.asymmetric(
						insertion: .move(edge: .trailing).combined(with: .opacity),
						removal: .opacity
					))
			}
		}
		.animation(.easeInOut(duration: 0.4), value: mainScreenViewModel.screen)
	}
}

#Preview {
	MainScreen()
		.environmentObject(MainScreenVIewModel())
}
