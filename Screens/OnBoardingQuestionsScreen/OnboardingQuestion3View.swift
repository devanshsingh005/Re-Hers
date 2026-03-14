import SwiftUI
import UIKit
import Supabase

struct OnboardingQuestion3View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selection: String?

    let levels = [
        ("🌱", "Beginner"),
        ("✨", "Intermediate"),
        ("🚀", "Advanced")
    ]

    // Adaptive padding for iPad vs iPhone
    var horizontalPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 180 : 24
    }

    var body: some View {
        VStack(spacing: 24) {

            ProgressIndicator(step: 3)

            Text("How do you want to start learning?")
                .font(.title2.bold())
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Text("We'll adjust the notes and practice tips for your pace.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    ForEach(levels, id: \.1) { icon, level in

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selection = level
                                viewModel.selectedLevel = level
                            }
                        } label: {
                            HStack {
                                Text(icon)
                                Text(level)
                                Spacer()
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                selection == level
                                ? Color(UIColor.secondaryColor)
                                : Color(UIColor.lightGray)
                            )
                            .foregroundColor(selection == level ? .white : .black)
                            .cornerRadius(12)
                            .scaleEffect(selection == level ? 1.03 : 1.0)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                Task { await submit() }
            } label: {
                Text(viewModel.isSaving ? "Saving…" : "Finish")
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(selection == nil ? Color(UIColor.systemGray4) : Color(UIColor.primaryColor))
                    .foregroundColor(.white)
                    .cornerRadius(28)
            }
            .disabled(selection == nil || viewModel.isSaving)

        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 40)
        .background(Color(UIColor.appBackground))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - SAVE DATA
    func submit() async {
        let client = SupabaseManager.shared.client

        do {
            let session = try await client.auth.session
            let userId = session.user.id.uuidString

            viewModel.saveToSupabase(userId: userId) { success in
                guard success else { return }
                // ⚠️ saveToSupabase callback runs on a background thread —
                // all UIKit transitions MUST happen on the main thread.
                DispatchQueue.main.async {
                    showHomeScreen()
                }
            }

        } catch {
            print("Failed to get session: \(error.localizedDescription)")
        }
    }

    // MARK: - Navigation
    func showHomeScreen() {
        let home = MainTabBarController()

        // Use the modern non-deprecated keyWindow lookup
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.keyWindow else { return }

        UIView.transition(with: window,
                          duration: 0.35,
                          options: .transitionCrossDissolve,
                          animations: { window.rootViewController = home },
                          completion: nil)
    }
}
