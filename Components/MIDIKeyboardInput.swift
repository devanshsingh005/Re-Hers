import CoreMIDI
import Foundation
import QuartzCore

// MARK: - MIDIKeyboardInput
//
// Listens to every MIDI keyboard connected to the phone — a digital piano or keyboard on a USB
// cable (USB-C, or Apple's Lightning to USB adapter); class-compliant devices need no driver —
// and reports the keys pressed. Keyboards plugged in or out while listening are picked up
// automatically. Events arrive on the main thread, timed with CACurrentMediaTime().

final class MIDIKeyboardInput {
    struct Device: Equatable { let id: MIDIUniqueID; let name: String }

    /// A key pressed: MIDI note number and velocity (1–127).
    var onNote: ((_ midi: Int, _ velocity: Int, _ time: Double) -> Void)?
    /// The keyboards connected changed.
    var onDevicesChanged: (([Device]) -> Void)?

    private(set) var devices: [Device] = []
    private(set) var isRunning = false

    private var client = MIDIClientRef()
    private var port = MIDIPortRef()
    private var connected = Set<MIDIEndpointRef>()

    deinit { stop() }

    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }
        var status = MIDIClientCreateWithBlock("Re-Hearse" as CFString, &client) { [weak self] notification in
            guard notification.pointee.messageID == .msgSetupChanged else { return }
            DispatchQueue.main.async { self?.connectSources() }
        }
        guard status == noErr else { return false }
        status = MIDIInputPortCreateWithProtocol(client, "Re-Hearse keys" as CFString, ._1_0, &port) { [weak self] list, _ in
            let notes = Self.noteOns(in: list)
            guard !notes.isEmpty else { return }
            let now = CACurrentMediaTime()
            DispatchQueue.main.async {
                guard let self, self.isRunning else { return }
                for note in notes { self.onNote?(note.midi, note.velocity, now) }
            }
        }
        guard status == noErr else {
            MIDIClientDispose(client)
            return false
        }
        isRunning = true
        connectSources()
        return true
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        for source in connected { MIDIPortDisconnectSource(port, source) }
        connected.removeAll()
        MIDIPortDispose(port)
        MIDIClientDispose(client)
        devices = []
    }

    /// Connects to every source (keyboard) there is, and reports the list when it changes.
    private func connectSources() {
        guard isRunning else { return }
        var found: [Device] = []
        var current = Set<MIDIEndpointRef>()
        for i in 0..<MIDIGetNumberOfSources() {
            let source = MIDIGetSource(i)
            guard source != 0 else { continue }
            current.insert(source)
            if !connected.contains(source) { MIDIPortConnectSource(port, source, nil) }
            var id: MIDIUniqueID = 0
            MIDIObjectGetIntegerProperty(source, kMIDIPropertyUniqueID, &id)
            found.append(Device(id: id, name: Self.name(of: source)))
        }
        for gone in connected.subtracting(current) { MIDIPortDisconnectSource(port, gone) }
        connected = current
        if found != devices {
            devices = found
            onDevicesChanged?(found)
        }
    }

    private static func name(of endpoint: MIDIEndpointRef) -> String {
        var name: Unmanaged<CFString>?
        if MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name) == noErr, let name {
            return name.takeRetainedValue() as String
        }
        return "MIDI keyboard"
    }

    /// Note-ons in a MIDI 1.0 event list (a note-on with velocity 0 is a note-off).
    static func noteOns(in list: UnsafePointer<MIDIEventList>) -> [(midi: Int, velocity: Int)] {
        var notes: [(Int, Int)] = []
        for packet in list.unsafeSequence() {
            let words = MIDIEventPacket.WordCollection(packet)
            for word in words {
                // universal MIDI packet: type 2 is a MIDI 1.0 channel voice message
                guard word >> 28 == 0x2 else { continue }
                let status = (word >> 16) & 0xF0
                let note = Int((word >> 8) & 0x7F)
                let velocity = Int(word & 0x7F)
                if status == 0x90 && velocity > 0 { notes.append((note, velocity)) }
            }
        }
        return notes
    }
}
