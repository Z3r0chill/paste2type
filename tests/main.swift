import Foundation
import CoreGraphics

func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    guard condition() else { fatalError("FAIL: \(name)") }
}

let samples = ["", "Hello, 'world'! — <>&", "café e\u{301} 中文", "👩🏽‍💻 🇺🇸 👨‍👩‍👧‍👦", "a\n\tb",
               "x" + String(repeating: "\u{301}", count: 50)]
for text in samples {
    let packets = TypingPlan.packets(for: text)
    check(String(decoding: packets.flatMap { $0 }, as: UTF16.self) == text, "text round trip")
    for packet in packets {
        check(packet.count <= 20, "packet size")
        check(Array(String(decoding: packet, as: UTF16.self).utf16) == packet, "no split surrogate")
        guard let (down, up) = TypingPlan.events(for: packet, source: nil) else { fatalError("event creation") }
        for event in [down, up] {
            var actual = 0
            var buffer = [UInt16](repeating: 0, count: 20)
            event.keyboardGetUnicodeString(maxStringLength: 20, actualStringLength: &actual, unicodeString: &buffer)
            check(Array(buffer.prefix(actual)) == packet, "event payload")
            check(event.flags.isEmpty, "no shortcut modifiers")
            check(event.getIntegerValueField(.keyboardEventKeycode) == 0, "no Return/Tab keycode")
        }
    }
}
check(String(decoding: TypingPlan.packets(for: "a\r\nb\rc").flatMap { $0 }, as: UTF16.self) == "a\nb\nc", "line endings")
check(TypingPlan.mayContinue(target: 42, frontmost: 42, escape: false, modifiers: false), "correct target")
check(!TypingPlan.mayContinue(target: 42, frontmost: 43, escape: false, modifiers: false), "app switch")
check(!TypingPlan.mayContinue(target: 42, frontmost: nil, escape: false, modifiers: false), "no front app")
check(!TypingPlan.mayContinue(target: 42, frontmost: 42, escape: true, modifiers: false), "Escape")
check(!TypingPlan.mayContinue(target: 42, frontmost: 42, escape: false, modifiers: true), "modifier")
print("Passed: Unicode/event payloads, line endings, target and cancellation guards.")

var permission = PermissionFlow()
for _ in 0..<10 {
    check(!permission.shouldRequest(granted: false, explicitlyRequested: false), "denied start never prompts")
}
check(!permission.didRequest, "checks do not consume explicit request")
check(permission.shouldRequest(granted: false, explicitlyRequested: true), "explicit first request")
check(!permission.shouldRequest(granted: false, explicitlyRequested: true), "no repeated denied prompts")
check(!permission.shouldRequest(granted: true, explicitlyRequested: true), "granted access never prompts")
check(!permission.shouldRequest(granted: false, explicitlyRequested: true), "revocation does not start prompt loop")
var alreadyGranted = PermissionFlow()
check(!alreadyGranted.shouldRequest(granted: true, explicitlyRequested: true), "existing grant never requests")
print("Passed: permission denial, explicit request, grant and revocation flow.")
