import Foundation
import OemerKit
import os
import PhotosUI
import SwiftUI
import UIKit

/// Runs the Core ML self-test and timed transcriptions. Every line goes to the screen, to stdout
/// (Xcode console, or `devicectl device process launch --console`) and to Documents/report.txt
/// (Files app, or the share button).
@MainActor
final class Benchmark: ObservableObject {
    @Published private(set) var lines: [String] = []
    @Published private(set) var running = false

    let reportURL = URL.documentsDirectory.appending(path: "report.txt")
    private var report = ""
    private var recognizer: SheetMusicRecognizer?

    /// Launched with `-autorun [-repeat N]`: run the benchmark at once, N transcriptions (default 3).
    static var autorunRepeats: Int? {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-autorun") else { return nil }
        if let i = args.firstIndex(of: "-repeat"), i + 1 < args.count, let n = Int(args[i + 1]) { return max(1, n) }
        return 3
    }

    /// Self-test, then `repeats` transcriptions of the bundled tabi.jpg.
    func runAll(repeats: Int) async {
        guard begin() else { return }
        defer { end() }
        log("OemerKit test app: \(Device.summary)")
        log("thermal \(Device.thermal) at start")
        do {
            let recognizer = try loadRecognizer()
            let t = Date()
            try await recognizer.prepare()
            log(String(format: "models ready in %.2fs (slower on the first launch after install)", since(t)))
            let selfTest = try await recognizer.runSelfTest()
            log("self-test: \(selfTest)")
            log("  thermal \(Device.thermal), \(Device.memory)")
            guard let url = Bundle.main.url(forResource: "tabi", withExtension: "jpg") else {
                log("error: tabi.jpg is missing from the app bundle")
                return
            }
            for run in 1...repeats {
                let t0 = Date()
                let result = try await recognizer.recognize(imageAt: url)
                log(String(format: "run %d: %.2fs total, %d notes  [%@]", run, since(t0), result.notes.count,
                           Self.stages(result.timings)))
                log("  thermal \(Device.thermal), \(Device.memory)")
                if run == repeats { save(result.musicXML, as: "tabi.musicxml") }
            }
        } catch {
            log("error: \(error)")
        }
        log("done")
    }

    /// Transcribes a photo from the library.
    func transcribe(_ item: PhotosPickerItem) async {
        guard begin() else { return }
        defer { end() }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                log("error: could not load the photo")
                return
            }
            let recognizer = try loadRecognizer()
            log("photo: \(data.count / 1024) KB, thermal \(Device.thermal)")
            let t0 = Date()
            let result = try await recognizer.recognize(imageData: data)
            log(String(format: "photo %dx%d: %.2fs total, %d notes  [%@]", Int(result.imageSize.width),
                       Int(result.imageSize.height), since(t0), result.notes.count, Self.stages(result.timings)))
            log("  thermal \(Device.thermal), \(Device.memory)")
            for n in result.notes.prefix(12) {
                log(String(format: "  staff %d  %@ %@ at (%.0f, %.0f)", n.staff, n.name,
                           n.type + (n.dotted ? "." : ""), n.rect.midX, n.rect.midY))
            }
            save(result.musicXML, as: "photo.musicxml")
        } catch {
            log("error: \(error)")
        }
    }

    func log(_ line: String) {
        lines.append(line)
        print(line)
        fflush(stdout)
        report += line + "\n"
        try? report.write(to: reportURL, atomically: true, encoding: .utf8)
    }

    private func loadRecognizer() throws -> SheetMusicRecognizer {
        if let recognizer { return recognizer }
        let r = try SheetMusicRecognizer()
        recognizer = r
        return r
    }

    private func begin() -> Bool {
        guard !running else { return false }
        running = true
        UIApplication.shared.isIdleTimerDisabled = true  // a locked screen would suspend the run
        return true
    }

    private func end() {
        running = false
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func save(_ xml: String, as name: String) {
        try? xml.write(to: URL.documentsDirectory.appending(path: name), atomically: true, encoding: .utf8)
        log("saved \(name)")
    }

    private func since(_ t: Date) -> Double { Date().timeIntervalSince(t) }

    /// Stage timings in pipeline order.
    static func stages(_ timings: [String: Double]) -> String {
        let order = ["prepare", "model1", "model2", "dewarp", "staffs", "symbols", "noteheads", "groups", "rhythm", "musicxml"]
        let keys = order.filter { timings[$0] != nil } + timings.keys.filter { !order.contains($0) }.sorted()
        return keys.map { String(format: "%@ %.2f", $0, timings[$0]!) }.joined(separator: ", ")
    }
}

@MainActor
enum Device {
    static var summary: String {
        let p = ProcessInfo.processInfo
        return String(format: "%@, iOS %@, %d cores, %.1f GB RAM%@", model, UIDevice.current.systemVersion,
                      p.processorCount, Double(p.physicalMemory) / 1_073_741_824,
                      p.isLowPowerModeEnabled ? ", Low Power Mode ON" : "")
    }

    /// Hardware identifier, e.g. "iPhone16,1".
    static var model: String {
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return "Simulator \(sim)" }
        var u = utsname()
        uname(&u)
        return withUnsafeBytes(of: u.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }

    static var thermal: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    /// Memory footprint (what iOS counts against the app's limit), its peak, and the headroom left
    /// (not reported in the Simulator, which has no limit).
    static var memory: String {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return "memory n/a" }
        let mb = 1_048_576.0
        let available = os_proc_available_memory()
        return String(format: "memory %.0f MB (peak %.0f MB%@)", Double(info.phys_footprint) / mb,
                      Double(info.ledger_phys_footprint_peak) / mb,
                      available > 0 ? String(format: ", %.0f MB left", Double(available) / mb) : "")
    }
}
