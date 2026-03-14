import SwiftUI

struct RehearsalInfoCard: View {
    @Binding var isPresented: Bool
    @State private var appear = false

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Card
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {

                    // Header
                    VStack(spacing: 4) {
                        Text("Welcome to")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)

                        Text("Rehearse")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.orange)

                        Text("Learn piano faster with interactive tools\nand guided practice.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.top, 10)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24) // ← reduced from original
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                    Divider()

                    // Features
                    VStack(alignment: .leading, spacing: 0) {
                        FeatureRow(
                            icon: "doc.viewfinder",
                            title: "Scan & Play",
                            description: "Scan sheet music and instantly start practicing."
                        )
                        Divider().padding(.leading, 64)
                        FeatureRow(
                            icon: "pianokeys",
                            title: "Animations",
                            description: "See animated keys that guide your fingers while playing."
                        )
                        Divider().padding(.leading, 64)
                        FeatureRow(
                            icon: "play.circle",
                            title: "Play Along",
                            description: "Practice songs in real time with guided playback."
                        )
                        Divider().padding(.leading, 64)
                        FeatureRow(
                            icon: "dumbbell",
                            title: "Build Your Basics",
                            description: "Strengthen core piano skills with structured exercises."
                        )
                    }

                    Divider()

                    // Got It Button
                    Button(action: dismiss) {
                        Text("Got It")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(20)
                }
                .background(Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 8)

                // Close button
                Button(action: dismiss) {
                    ZStack {
                        Circle()
                            .fill(Color(uiColor: .secondarySystemBackground))
                            .frame(width: 30, height: 30)
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                    }
                }
                .padding(14)
            }
            .padding(.horizontal, 20)
            .scaleEffect(appear ? 1 : 0.94)
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                appear = true
            }
        }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            appear = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            isPresented = false
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.gray.opacity(0.5).ignoresSafeArea()
        RehearsalInfoCard(isPresented: .constant(true))
    }
}
