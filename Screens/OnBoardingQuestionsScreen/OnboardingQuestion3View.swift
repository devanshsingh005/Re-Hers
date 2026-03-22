import SwiftUI
import UIKit
import Supabase

// MARK: - Q3: How long can you practice each day?
struct OnboardingQuestion3View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    // Slider steps: 5, 10, 15, 20, 30, 45, 60
    private let steps: [Int] = [5, 10, 15, 20, 30, 45, 60]
    @State private var sliderIndex: Double = 1   // default index 1 = 10 min

    private var currentMins: Int { steps[Int(sliderIndex.rounded())] }

    private var moodLabel: String {
        switch currentMins {
        case 5:        return "A micro-habit — easy to keep 🌿"
        case 10:       return "A sustainable daily habit 🌱"
        case 15:       return "Solid progress every day 🎵"
        case 20:       return "You'll see real improvement 🎼"
        case 30:       return "Committed and consistent 🎹"
        case 45:       return "Serious about this 🏅"
        default:       return "An hour a day — dedicated 🔥"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            CustomOnboardingNavBar(step: 3)
                .padding(.top, 10)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Header text
                    VStack(alignment: .leading, spacing: 10) {
                        Text("STEP 3 OF 3")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(SemanticColors.Text.brand))
                            .shadow(color: Color(SemanticColors.Text.brand).opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        Text("How long can you practice each day?")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(SemanticColors.Text.primary))

                        Text("Even 10 minutes a day adds up to something beautiful.")
                            .font(.system(size: 15))
                            .foregroundColor(Color(SemanticColors.Text.secondary))
                    }
                    .padding(.top, 24)

                    // Liquid Glass Card
                    VStack(alignment: .leading, spacing: 0) {
                        // Big number display
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            Text("\(currentMins)")
                                .font(.system(size: 64, weight: .bold))
                                .foregroundColor(Color(SemanticColors.Text.primary))
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.35, dampingFraction: 0.65), value: currentMins)
                                .shadow(color: Color(SemanticColors.Text.primary).opacity(0.2), radius: 8, x: 0, y: 4)

                            Text("min / day")
                                .font(.system(size: 18))
                                .foregroundColor(Color(SemanticColors.Text.secondary))
                        }
                        .padding(.top, 24)
                        .padding(.horizontal, 24)
                        
                        Text(moodLabel)
                            .font(.system(size: 13))
                            .foregroundColor(Color(SemanticColors.Text.secondary))
                            .padding(.horizontal, 24)
                            .padding(.bottom, 32)
                            .padding(.top, 4)

                        // Slider
                        VStack(spacing: 8) {
                            Slider(value: $sliderIndex, in: 0...Double(steps.count - 1), step: 1) { _ in
                                viewModel.practiceMins = currentMins
                            }
                            .tint(Color(SemanticColors.DataViz.progressFill))
                            .onChange(of: sliderIndex) { _ in
                                viewModel.practiceMins = currentMins
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                            }

                            HStack {
                                Text("5 min")
                                Spacer()
                                Text("60 min")
                            }
                            .font(.system(size: 11))
                            .foregroundColor(Color(SemanticColors.Text.tertiary))
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(SemanticColors.Background.card))
                    )
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 24)
            }

            // Bottom Action Area
            VStack(spacing: 16) {
                Button {
                    viewModel.practiceMins = currentMins
                    Task { await submit() }
                } label: {
                    Group {
                        if viewModel.isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        } else {
                            Text("Finish setup")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color(SemanticColors.Background.primaryButton))
                    .foregroundColor(Color(SemanticColors.Text.onBrand))
                    .cornerRadius(26)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.isSaving)
                }
                .disabled(viewModel.isSaving)
                
                Button("Skip") {
                    viewModel.skipOnboarding()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(SemanticColors.Text.brand))
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
        .alert("Error", isPresented: Binding<Bool>(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            if let msg = viewModel.errorMessage {
                Text(msg)
            }
        }
        .onAppear {
            if let idx = steps.firstIndex(of: viewModel.practiceMins) {
                sliderIndex = Double(idx)
            }
        }
    }

    // MARK: - Save & navigate
    func submit() async {
        let client = SupabaseManager.shared.client
        do {
            let session = try await client.auth.session
            let userId  = session.user.id.uuidString

            viewModel.saveToSupabase(userId: userId) { success in
                if success {
                    viewModel.skipOnboarding()
                }
            }
        } catch {
            viewModel.errorMessage = "Failed to get session: \(error.localizedDescription)"
        }
    }
}
