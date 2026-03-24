import SwiftUI
import UIKit

struct ProgressIndicator: View {
    let step: Int   // 1, 2, or 3
    let totalSteps: Int = 3

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(SemanticColors.DataViz.progressTrack))
                    .frame(height: 2)
                Rectangle()
                    .fill(Color(SemanticColors.DataViz.progressFill))
                    .frame(width: geometry.size.width * CGFloat(step) / CGFloat(totalSteps), height: 2)
            }
        }
        .frame(height: 2)
    }
}

struct CustomOnboardingNavBar: View {
    let step: Int
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if step > 1 {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(Color(SemanticColors.Icon.primary))
                    }
                } else {
                    Spacer()
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            ProgressIndicator(step: step)
        }
    }
}

// MARK: - Animated Glass Background
struct GlassBackgroundView: View {
    var body: some View {
        Color(SemanticColors.Background.screen).ignoresSafeArea()
    }
}
