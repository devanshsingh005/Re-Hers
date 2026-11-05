import SwiftUI

// MARK: - RehearsalInfoCard
// Full-screen overlay (overFullScreen presentation).
// GeometryReader gives reliable actual screen height for the slide-in offset.

struct RehearsalFeaturesSheetView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var isUp    = false
    @State private var dragY:  CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {

                // ── Dim layer ─────────────────────────────────────────────
                Color.black
                    .opacity(isUp ? 0.45 : 0)
                    .ignoresSafeArea()
                    .animation(.easeOut(duration: 0.25), value: isUp)
                    .onTapGesture { slideDown() }

                // ── Card ─────────────────────────────────────────────────
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 0) {
                        // Drag Handle
                        Capsule()
                            .fill(Color.gray.opacity(0.35))
                            .frame(width: 36, height: 5)
                            .padding(.top, 12)

                        // Header
                        VStack(spacing: 4) {
                            Text("Welcome to")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color(SemanticColors.Text.primary))
                            Text("Rehearse")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color(BrandColors.brand))
                            Text("Learn piano faster with interactive tools\nand guided practice.")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(Color(SemanticColors.Text.secondary))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                                .padding(.top, 10)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 28)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 22)

                        // Features
                        VStack(alignment: .leading, spacing: 0) {
                            FeatureRow(icon: "doc.viewfinder",  title: "Scan & Play",       description: "Scan sheet music and instantly start practicing.")
                            FeatureRow(icon: "pianokeys",        title: "Animations",        description: "See animated keys that guide your fingers while playing.")
                            FeatureRow(icon: "play.circle",      title: "Play Along",        description: "Practice songs in real time with guided playback.")
                            FeatureRow(icon: "dumbbell",         title: "Build Your Basics", description: "Strengthen core piano skills with structured exercises.")
                        }

                        // Got It
                        Button(action: slideDown) {
                            Text("Got It")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(SemanticColors.Background.primaryButton))
                                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, max(geo.safeAreaInsets.bottom + 20, 44))
                    }
                    .background(
                        ZStack {
                            Color(SemanticColors.Background.modal)
                            BlurView(style: .systemThinMaterial).opacity(0.72)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 28, x: 0, y: -8)

                    // Close ×
                    Button(action: slideDown) {
                        ZStack {
                            Circle()
                                .fill(Color(SemanticColors.Background.secondaryButton))
                                .frame(width: 30, height: 30)
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(BrandColors.brand))
                        }
                    }
                    .padding(14)
                }
                // Slide from fully below screen → resting position
                .offset(y: isUp ? max(0, dragY) : geo.size.height + 60)
                .animation(
                    isUp ? nil : .spring(response: 0.42, dampingFraction: 0.82),
                    value: isUp
                )
                .gesture(
                    DragGesture()
                        .onChanged { v in dragY = max(0, v.translation.height) }
                        .onEnded   { v in
                            if v.translation.height > 100 { slideDown() }
                            else { withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) { dragY = 0 } }
                        }
                )
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { isUp = true }
        }
    }

    private func slideDown() {
        withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) { isUp = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { dismiss() }
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
                    .fill(Color(BrandColors.brand).opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(Color(BrandColors.brand))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(SemanticColors.Text.primary))
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(Color(SemanticColors.Text.secondary))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
    }
}

// MARK: - Blur helper

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
