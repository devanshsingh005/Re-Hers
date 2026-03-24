import SwiftUI
import UIKit

// MARK: - Square genre card
struct GenreSquareCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Text(icon)
                        .font(.system(size: 28))
                    
                    Spacer()
                    
                    // Animated Checkmark
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(SemanticColors.Icon.active))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(SemanticColors.Text.primary))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Color(SemanticColors.Text.secondary))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color(SemanticColors.Background.brandTint) : Color(SemanticColors.Background.card))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Color(SemanticColors.Border.active) : Color(SemanticColors.Border.default), lineWidth: 1.5)
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Q2: What style of piano music?
struct OnboardingQuestion2View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    let genres: [(icon: String, title: String, subtitle: String)] = [
        ("🎼", "Classical",        "Bach, Chopin, Mozart"),
        ("🎷", "Jazz & Blues",     "Standards, improv"),
        ("🎹", "Contemporary",     "Einaudi, Yiruma"),
        ("🎬", "Film Scores",      "Zimmer, Williams"),
        ("🎤", "Pop Ballads",      "Adele, Elton John"),
        ("🌿", "Ambient",          "Lo-fi, meditative"),
        ("🎶", "Gospel & Sacred",  "Hymns, worship")
    ]

    let grid = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var hasSelection: Bool { !viewModel.selectedGenres.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            CustomOnboardingNavBar(step: 2)
                .padding(.top, 10)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Header text
                    VStack(alignment: .leading, spacing: 10) {
                        Text("STEP 2 OF 3")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(SemanticColors.Text.brand))
                            .shadow(color: Color(SemanticColors.Text.brand).opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        Text("What style of piano music?")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(SemanticColors.Text.primary))

                        Text("Select all that interest you — your song library will be built around these.")
                            .font(.system(size: 15))
                            .foregroundColor(Color(SemanticColors.Text.secondary))
                    }
                    .padding(.top, 24)

                    LazyVGrid(columns: grid, spacing: 16) {
                        ForEach(genres, id: \.title) { item in
                            GenreSquareCard(
                                icon: item.icon,
                                title: item.title,
                                subtitle: item.subtitle,
                                isSelected: viewModel.selectedGenres.contains(item.title),
                                action: {
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                    
                                    if viewModel.selectedGenres.contains(item.title) {
                                        viewModel.selectedGenres.remove(item.title)
                                    } else {
                                        viewModel.selectedGenres.insert(item.title)
                                    }
                                }
                            )
                            .frame(minHeight: 140)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 24)
            }

            // Bottom Action Area
            VStack(spacing: 16) {
                NavigationLink {
                    OnboardingQuestion3View()
                        .environmentObject(viewModel)
                } label: {
                    Text("Continue")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(
                            !hasSelection
                            ? Color(SemanticColors.Background.disabledButton)
                            : Color(SemanticColors.Background.primaryButton)
                        )
                        .foregroundColor(!hasSelection ? Color(SemanticColors.Text.disabled) : Color(SemanticColors.Text.onBrand))
                        .cornerRadius(26)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hasSelection)
                }
                .disabled(!hasSelection)
                
                NavigationLink {
                    OnboardingQuestion3View()
                        .environmentObject(viewModel)
                } label: {
                    Text("Skip")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(SemanticColors.Text.brand))
                }
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
