import SwiftUI

struct RehearsalInfoCard: View {
    @Binding var isPresented: Bool
    @State private var appear = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dimmed background
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Card
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    // Drag Handle
                    Capsule()
                        .fill(Color(uiColor: SemanticColors.Text.tertiary).opacity(0.3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 12)

                    // Header
                    VStack(spacing: 4) {
                        Text("Welcome to")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(uiColor: SemanticColors.Text.primary))

                        Text("Rehearse")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(uiColor: BrandColors.brand))

                        Text("Learn piano faster with interactive tools\nand guided practice.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Color(uiColor: SemanticColors.Text.secondary))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.top, 10)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 36) // Increased for breathing space
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)



                    // Features
                    VStack(alignment: .leading, spacing: 0) {
                        FeatureRow(
                            icon: "doc.viewfinder",
                            title: "Scan & Play",
                            description: "Scan sheet music and instantly start practicing."
                        )

                        FeatureRow(
                            icon: "pianokeys",
                            title: "Animations",
                            description: "See animated keys that guide your fingers while playing."
                        )

                        FeatureRow(
                            icon: "play.circle",
                            title: "Play Along",
                            description: "Practice songs in real time with guided playback."
                        )

                        FeatureRow(
                            icon: "dumbbell",
                            title: "Build Your Basics",
                            description: "Strengthen core piano skills with structured exercises."
                        )
                    }
                    .padding(.vertical, 8) // Extra space between headers and button



                    // Got It Button
                    Button(action: dismiss) {
                        Text("Got It")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(uiColor: SemanticColors.Background.primaryButton))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 36) // Extra bottom breathing space
                }
                .background(
                    ZStack {
                        // Adaptive background color from Design System
                        Color(uiColor: SemanticColors.Background.modal).opacity(0.85)
                        // Glassy blur effect (adaptive material)
                        BlurView(style: .systemThinMaterial).opacity(0.7)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(
                    color: Color(uiColor: SemanticColors.Shadow.level3),
                    radius: 30, x: 0, y: 10
                )

                // Close button
                Button(action: dismiss) {
                    ZStack {
                        Circle()
                            .fill(Color(uiColor: SemanticColors.Background.secondaryButton))
                            .frame(width: 30, height: 30)
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(uiColor: BrandColors.brand))
                    }
                }
                .padding(14)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .offset(y: appear ? 0 : 800)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > -20 {
                            // Only allow dragging down
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 80 {
                            dismiss()
                        }
                    }
            )
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
                    .fill(Color(uiColor: BrandColors.brand).opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(Color(uiColor: BrandColors.brand))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(uiColor: SemanticColors.Text.primary))
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(Color(uiColor: SemanticColors.Text.secondary))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
    }
}

// MARK: - Blur View Helper
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.opacity(0.8).ignoresSafeArea()
        RehearsalInfoCard(isPresented: .constant(true))
    }
}
