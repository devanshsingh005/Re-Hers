//
//  SheetTempo.swift
//  Re-Hearse
//
//  The tempo a sheet is played at, in BPM, chosen by the player and kept per sheet (Animation
//  and Play Along share it), and the pop-up that asks for it.
//

import UIKit
import CryptoKit

enum SheetTempo {
    /// The tempos a player can choose (quarter notes per minute).
    static let range = 20...300

    static func clamp(_ bpm: Int) -> Int { min(range.upperBound, max(range.lowerBound, bpm)) }

    /// Where a sheet's tempo is kept: one key per sheet, by its content.
    static func key(for data: Data) -> String {
        "sheet.tempo.bpm." + SHA256.hash(data: data).prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    static func saved(forKey key: String?) -> Int? {
        guard let key else { return nil }
        let bpm = UserDefaults.standard.integer(forKey: key)
        return range.contains(bpm) ? bpm : nil
    }

    static func save(_ bpm: Int, forKey key: String?) {
        guard let key else { return }
        UserDefaults.standard.set(clamp(bpm), forKey: key)
    }

    /// Asks for a tempo with the field filled in with `prefill`. `onDone` gets the tempo typed;
    /// `onCancel` runs when the player cancels.
    static func ask(in presenter: UIViewController,
                    title: String = "Play at this tempo?",
                    scoreBPM: Double,
                    prefill: Int,
                    doneTitle: String = "Play",
                    onDone: @escaping (Int) -> Void,
                    onCancel: (() -> Void)? = nil) {
        let alert = UIAlertController(
            title: title,
            message: "Type the tempo you want to play at.",
            preferredStyle: .alert)
        var observer: NSObjectProtocol?
        let done = UIAlertAction(title: doneTitle, style: .default) { [weak alert] _ in
            if let observer { NotificationCenter.default.removeObserver(observer) }
            let typed = Int(alert?.textFields?.first?.text ?? "") ?? prefill
            onDone(clamp(typed))
        }
        alert.addTextField { field in
            field.keyboardType = .numberPad
            field.text = String(clamp(prefill))
            field.placeholder = "BPM"
            field.textAlignment = .center
            field.clearButtonMode = .whileEditing
            observer = NotificationCenter.default.addObserver(
                forName: UITextField.textDidChangeNotification, object: field, queue: .main) { _ in
                done.isEnabled = Int(field.text ?? "").map(range.contains) ?? false
            }
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            if let observer { NotificationCenter.default.removeObserver(observer) }
            onCancel?()
        })
        alert.addAction(done)
        alert.preferredAction = done
        presenter.present(alert, animated: true)
    }
}
