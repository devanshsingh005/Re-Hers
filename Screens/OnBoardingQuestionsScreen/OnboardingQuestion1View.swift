import SwiftUI
import UIKit

// MARK: - Single level option row
struct LevelOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon block
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(SemanticColors.Background.secondaryButton))
                        .frame(width: 38, height: 38)
                    Text(icon)
                        .font(.system(size: 18))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(SemanticColors.Text.primary))
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(Color(SemanticColors.Text.secondary))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                // Animated Checkmark
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(SemanticColors.Icon.active))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color(SemanticColors.Background.brandTint) : Color(SemanticColors.Background.card))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color(SemanticColors.Border.active) : Color(SemanticColors.Border.default), lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

// MARK: - Q1: What's your level?
struct OnboardingQuestion1View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    let levels: [(icon: String, title: String, subtitle: String)] = [
        ("🌱", "Absolute beginner",  "I've never played piano before"),
        ("🎵", "Some basics",        "I know a few notes or simple songs"),
        ("🎼", "Intermediate",       "I read sheet music and practice regularly"),
        ("🎹", "Advanced",           "Strong technique, expanding repertoire")
    ]

    var body: some View {
        VStack(spacing: 0) {
            CustomOnboardingNavBar(step: 1)
                .padding(.top, 10)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header text
                    VStack(alignment: .leading, spacing: 10) {
                        Text("STEP 1 OF 3")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(SemanticColors.Text.brand))
                            .shadow(color: Color(SemanticColors.Text.brand).opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        Text("What's your current level?")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(SemanticColors.Text.primary))

                        Text("We'll tune your lessons, song difficulty, and pacing to match where you are.")
                            .font(.system(size: 15))
                            .foregroundColor(Color(SemanticColors.Text.secondary))
                    }
                    .padding(.top, 24)

                    // Options List
                    VStack(spacing: 12) {
                        ForEach(Array(levels.enumerated()), id: \.element.title) { index, item in
                            LevelOptionRow(
                                icon: item.icon,
                                title: item.title,
                                subtitle: item.subtitle,
                                isSelected: viewModel.selectedLevel == item.title,
                                action: {
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                    viewModel.selectedLevel = item.title
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
            }

            // Bottom Action Area
            VStack(spacing: 16) {
                NavigationLink {
                    OnboardingQuestion2View()
                        .environmentObject(viewModel)
                } label: {
                    Text("Continue")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(
                            viewModel.selectedLevel == nil
                            ? Color(SemanticColors.Background.disabledButton)
                            : Color(SemanticColors.Background.primaryButton)
                        )
                        .foregroundColor(viewModel.selectedLevel == nil ? Color(SemanticColors.Text.disabled) : Color(SemanticColors.Text.onBrand))
                        .cornerRadius(26)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.selectedLevel)
                }
                .disabled(viewModel.selectedLevel == nil)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .padding(.top, 10)
        }
        .background(
            GlassBackgroundView()
                .ignoresSafeArea()
        )
        .navigationBarHidden(true)
    }
}
