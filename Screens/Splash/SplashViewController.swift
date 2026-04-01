import SwiftUI
import UIKit
import Combine

// MARK: - Particle System for Aesthetics (Optimized)
struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
    var speed: Double
}

struct ParticleView: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var isPulseActive: Bool
    @State private var particles: [Particle] = []
    let color: Color
    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(color)
                        .frame(
                            width: particle.size * (isPulseActive ? 1.4 : 1.0),
                            height: particle.size * (isPulseActive ? 1.4 : 1.0)
                        )
                        .opacity(adjustedOpacity(for: particle))
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
            }
            .onReceive(timer) { _ in
                updateParticles(in: geometry.size)
            }
        }
    }
    
    private func adjustedOpacity(for particle: Particle) -> Double {
        let baseOpacity = colorScheme == .dark ? particle.opacity : (particle.opacity + 0.1)
        return isPulseActive ? min(1.0, baseOpacity + 0.2) : baseOpacity
    }

    private func createParticles(in size: CGSize) {
        guard particles.isEmpty else { return }
        for _ in 0..<25 {
            particles.append(
                Particle(
                    x: CGFloat.random(in: 0...max(size.width, 1)),
                    y: CGFloat.random(in: 0...max(size.height, 1)),
                    size: CGFloat.random(in: 3...6),
                    opacity: Double.random(in: 0.1...0.3),
                    speed: Double.random(in: 0.5...1.4)
                )
            )
        }
    }
    
    private func updateParticles(in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let speedMult: CGFloat = isPulseActive ? 4.5 : 1.0
        for i in 0..<particles.count {
            particles[i].y -= CGFloat(particles[i].speed) * speedMult
            if particles[i].y < -20 {
                particles[i].y = size.height + 20
                particles[i].x = CGFloat.random(in: 0...size.width)
            }
        }
    }
}

// MARK: - SwiftUI SplashScreenView
struct SplashScreenView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var logoBlur: CGFloat = 8
    
    // Wave States
    @State private var waveScale1: CGFloat = 0.8 // Start from inside/behind logo
    @State private var waveOpacity1: Double = 0
    @State private var waveScale2: CGFloat = 0.8
    @State private var waveOpacity2: Double = 0
    
    // Background State
    @State private var gradientStart = UnitPoint(x: 0, y: 0)
    @State private var gradientEnd = UnitPoint(x: 1, y: 1)
    
    // Breathing & Shimmer
    @State private var breathScale: CGFloat = 1.0
    @State private var shimmerOffset: CGFloat = -1.5
    @State private var isPulseActive: Bool = false
    
    var onGetStarted: () -> Void
    
    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let brandOrange = Color(red: 239.0/255.0, green: 148.0/255.0, blue: 8.0/255.0) // #EF9408
    
    private var baseColor: Color {
        colorScheme == .dark ? Color(red: 15.0/255.0, green: 15.0/255.0, blue: 15.0/255.0) : Color(red: 248.0/255.0, green: 248.0/255.0, blue: 244.0/255.0)
    }
    
    private var accentColor: Color {
        colorScheme == .dark ? Color(red: 28/255, green: 28/255, blue: 30/255) : .white
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background Gradient
                LinearGradient(
                    gradient: Gradient(colors: [baseColor, accentColor, baseColor]),
                    startPoint: gradientStart,
                    endPoint: gradientEnd
                )
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                        gradientStart = UnitPoint(x: 1, y: 0)
                        gradientEnd = UnitPoint(x: 0, y: 1)
                    }
                }
                
                // Optimized Particles
                ParticleView(isPulseActive: $isPulseActive, color: brandOrange)
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                        .frame(height: geometry.size.height * 0.16)
                    
                    ZStack {
                        // Clear Resonance Waves (emerging from behind logo)
                        Circle()
                            .stroke(
                                brandOrange.opacity(0.8),
                                lineWidth: colorScheme == .dark ? 1.5 : 2.5
                            )
                            .scaleEffect(waveScale1)
                            .opacity(waveOpacity1)
                            .shadow(color: brandOrange.opacity(0.4), radius: 8)
                        
                        Circle()
                            .stroke(
                                brandOrange.opacity(0.6),
                                lineWidth: colorScheme == .dark ? 1 : 2.0
                            )
                            .scaleEffect(waveScale2)
                            .opacity(waveOpacity2)
                            .shadow(color: brandOrange.opacity(0.3), radius: 6)
                        
                        // Centered Logo
                        ZStack {
                            Image("logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: logoSize(for: geometry))
                                .blur(radius: logoBlur)
                                .scaleEffect(logoScale * breathScale)
                                .opacity(logoOpacity)
                            
                            // Shimmer
                            Image("logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: logoSize(for: geometry))
                                .scaleEffect(logoScale * breathScale)
                                .opacity(logoOpacity * 0.5)
                                .mask(
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [.clear, .white.opacity(0.6), .clear]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .rotationEffect(.degrees(30))
                                        .offset(x: shimmerOffset * logoSize(for: geometry))
                                )
                        }
                        .shadow(color: brandOrange.opacity(colorScheme == .dark ? 0.2 : 0.3), radius: 40, x: 0, y: 15)
                    }
                    .frame(height: geometry.size.height * 0.45)
                    
                    Spacer()
                }
            }
        }
        .onAppear {
            runAnimations()
        }
    }
    
    private func logoSize(for geo: GeometryProxy) -> CGFloat {
        let minDim = min(geo.size.width, geo.size.height)
        return isIPad ? minDim * 0.34 : minDim * 0.51
    }
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    private func runAnimations() {
        // Accelerated Logo Gaussian Reveal (reduced from 1.5s to 1.0s)
        withAnimation(.easeOut(duration: 1.0)) {
            logoOpacity = 1
            logoScale = 1.0
            logoBlur = 0
        }
        
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            shimmerOffset = 1.5
        }
        
        // Earlier Initial Pulse delay (reduced from 1.2s to 0.7s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            triggerPulse()
            Timer.scheduledTimer(withTimeInterval: 3.2, repeats: true) { _ in
                triggerPulse()
            }
        }
        
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            breathScale = 1.025
        }
        
        // Accelerated Auto-navigation: Exactly at 2.0 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            onGetStarted()
        }
    }
    
    private func triggerPulse() {
        // Reset states to "Origin" position (invisible and small)
        // We do this WITHOUT animation to prepare for the "Fade In" reveal
        waveScale1 = 0.9
        waveOpacity1 = 0
        waveScale2 = 0.9
        waveOpacity2 = 0
        
        // Phase 1: Primary Wave - Faster "Fade In" (reduced from 0.6s to 0.4s)
        withAnimation(.easeIn(duration: 0.4)) {
            waveOpacity1 = colorScheme == .dark ? 0.6 : 0.8
        }
        
        // Synchronized Haptic at the peak of the reveal
        impact.prepare()
        impact.impactOccurred()
        
        // Global Atmosphere Reactivity
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isPulseActive = true
        }
        
        // Phase 2: Long, organic expansion and fade-out
        withAnimation(.easeOut(duration: 3.5)) {
            waveScale1 = 4.2
            waveOpacity1 = 0
        }
        
        // Staggered Secondary Wave - Following the same smooth pattern
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeIn(duration: 0.6)) {
                waveOpacity2 = colorScheme == .dark ? 0.4 : 0.6
            }
            
            withAnimation(.easeOut(duration: 3.2)) {
                waveScale2 = 3.8
                waveOpacity2 = 0
            }
        }
        
        // Reset reactivity after the initial "impact" phase
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 1.2)) {
                isPulseActive = false
            }
        }
    }
}

// MARK: - Legacy Wrapper
class SplashViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let splashView = SplashScreenView { [weak self] in
            self?.goToMain()
        }
        let hostingController = UIHostingController(rootView: splashView)
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.frame = view.bounds
        hostingController.didMove(toParent: self)
    }
    
    private func goToMain() {
        guard let window = view.window else { return }
        let homeVC = AuthViewController()
        // Faster, snappier transition duration (from 1.2s to 1.0s) for better perceived performance
        UIView.transition(with: window, duration: 1.0, options: .transitionCrossDissolve, animations: {
            window.rootViewController = homeVC
        })
    }
}
