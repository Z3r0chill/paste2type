import Foundation
import CoreGraphics

enum TypingPlan {
    /// Preserve graphemes where possible and never split a UTF-16 surrogate pair.
    static func packets(for text: String) -> [[UInt16]] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return normalized.flatMap { character -> [[UInt16]] in
            let units = Array(String(character).utf16)
            if units.count <= 20 { return [units] }
            var packets: [[UInt16]] = []
            var packet: [UInt16] = []
            for scalar in character.unicodeScalars {
                let next = Array(String(scalar).utf16)
                if packet.count + next.count > 20 {
                    packets.append(packet)
                    packet = []
                }
                packet += next
            }
            if !packet.isEmpty { packets.append(packet) }
            return packets
        }
    }

    static func events(for packet: [UInt16], source: CGEventSource?) -> (CGEvent, CGEvent)? {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return nil }
        for event in [down, up] {
            event.flags = []
            packet.withUnsafeBufferPointer {
                event.keyboardSetUnicodeString(stringLength: $0.count, unicodeString: $0.baseAddress)
            }
        }
        return (down, up)
    }

    static func mayContinue(target: Int32, frontmost: Int32?, escape: Bool, modifiers: Bool) -> Bool {
        frontmost == target && !escape && !modifiers
    }
}
