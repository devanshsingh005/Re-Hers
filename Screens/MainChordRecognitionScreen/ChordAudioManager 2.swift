import Foundation
import CoreGraphics

protocol ChordAudioManagerDelegate: AnyObject {
    func didUpdateChord(_ chord: String, note: String, confidence: String, amplitude: CGFloat)
    func didStopListening()
}

final class ChordAudioManager {
    weak var delegate: ChordAudioManagerDelegate?
    private(set) var isListening: Bool = false

    private var timer: Timer?
    private var amplitude: CGFloat = 0.02

    func toggleListening() {
        if isListening {
            stop()
        } else {
            start()
        }
    }

    private func start() {
        guard !isListening else { return }
        isListening = true

        // Simulate incoming audio levels and chord recognition with a timer
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        guard isListening else { return }
        isListening = false
        timer?.invalidate()
        timer = nil
        delegate?.didStopListening()
    }

    private func tick() {
        // Simple simulated amplitude oscillation
        amplitude += 0.06
        if amplitude > 1.0 { amplitude = 0.02 }

        // Simulate a rotating set of chords/notes with a pseudo confidence value
        let chords = [
            ("C", "C E G"),
            ("Dm", "D F A"),
            ("G", "G B D"),
            ("Am", "A C E"),
            ("F", "F A C"),
            ("E", "E G# B")
        ]
        let index = Int(Date().timeIntervalSince1970 * 2).quotientAndRemainder(dividingBy: chords.count).remainder
        let (chord, notes) = chords[index]
        let confidenceValue = 0.6 + 0.4 * Double((index + 1) % chords.count) / Double(chords.count)
        let confidence = String(format: "Confidence: %.0f%%", confidenceValue * 100)

        delegate?.didUpdateChord(chord, note: notes, confidence: confidence, amplitude: amplitude)
    }
}
