import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate {
    private var window: NSWindow!
    private let editor = NSTextView()
    private let targetLabel = NSTextField(labelWithString: "")
    private let status = NSTextField(wrappingLabelWithString: "Paste your text above, then click Start Typing.")
    private let startButton = NSButton(title: "Start Typing", target: nil, action: nil)
    private let stopButton = NSButton(title: "Stop", target: nil, action: nil)
    private let permissionButton = NSButton(title: "Enable Accessibility…", target: nil, action: nil)
    private var permissionFlow = PermissionFlow()
    private var lastPermissionState: Bool?
    private var destination: NSRunningApplication?
    private var activeTarget: NSRunningApplication?
    private var observer: NSObjectProtocol?
    private var timer: Timer?
    private var packets: [[UInt16]] = []
    private var offset = 0
    private var activationDeadline = Date()
    private var focusedElement: AXUIElement?
    private let eventSource = CGEventSource(stateID: .privateState)

    func applicationDidFinishLaunching(_ notification: Notification) {
        remember(NSWorkspace.shared.frontmostApplication)
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            if self.timer != nil {
                if app.processIdentifier != self.activeTarget?.processIdentifier {
                    self.finish("Stopped because you switched apps.")
                }
            } else {
                self.remember(app)
            }
        }
        buildMenu()
        buildWindow()
        updateTarget()
        refreshPermission()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard window != nil else { return }
        refreshPermission()
    }

    private func refreshPermission() {
        let granted = CGPreflightPostEventAccess()
        permissionButton.title = granted ? "Accessibility Enabled" : "Enable Accessibility…"
        permissionButton.isEnabled = !granted
        if granted, lastPermissionState == false, timer == nil {
            status.stringValue = "Accessibility is enabled. Select your destination field, then return here."
        }
        lastPermissionState = granted
    }

    private func remember(_ app: NSRunningApplication?) {
        guard let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              app.activationPolicy == .regular else { return }
        destination = app
        updateTarget()
    }

    private func updateTarget() {
        targetLabel.stringValue = "Type into: \(destination?.localizedName ?? "select a field in another app first")"
    }

    private func buildMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Paste2Type", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        for (title, selector, key) in [("Undo", "undo:", "z"), ("Cut", "cut:", "x"),
                                        ("Copy", "copy:", "c"), ("Paste", "paste:", "v"),
                                        ("Select All", "selectAll:", "a")] {
            editMenu.addItem(withTitle: title, action: NSSelectorFromString(selector), keyEquivalent: key)
        }
        editItem.submenu = editMenu
        menu.addItem(editItem)
        NSApp.mainMenu = menu
    }

    private func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 470),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "Paste2Type"
        window.minSize = NSSize(width: 500, height: 400)
        window.isReleasedWhenClosed = false
        window.center()
        let content = window.contentView!
        let heading = NSTextField(labelWithString: "Paste here. Type there.")
        heading.font = .systemFont(ofSize: 23, weight: .semibold)
        let help = NSTextField(wrappingLabelWithString:
            "Click the destination field, come back here, and paste your text. Start Typing returns to that app and begins typing immediately.")
        help.textColor = .secondaryLabelColor
        let scroll = NSScrollView()
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true
        editor.isRichText = false
        editor.allowsUndo = true
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        editor.textContainerInset = NSSize(width: 10, height: 12)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.delegate = self
        editor.setAccessibilityLabel("Text to type")
        scroll.documentView = editor
        targetLabel.font = .systemFont(ofSize: 12, weight: .medium)
        startButton.target = self
        startButton.action = #selector(startTyping)
        startButton.bezelStyle = .rounded
        startButton.isEnabled = false
        stopButton.target = self
        stopButton.action = #selector(stopTyping)
        stopButton.bezelStyle = .rounded
        stopButton.isEnabled = false
        permissionButton.target = self
        permissionButton.action = #selector(enableAccessibility)
        permissionButton.bezelStyle = .rounded
        let buttons = NSStackView(views: [startButton, stopButton, permissionButton])
        buttons.spacing = 10
        status.textColor = .secondaryLabelColor
        status.font = .systemFont(ofSize: 12)
        let hint = NSTextField(wrappingLabelWithString: "To stop: switch back to this app or hold Esc. Text stays on this Mac and is cleared when you quit.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        for view in [heading, help, scroll, targetLabel, buttons, status, hint] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        NSLayoutConstraint.activate([
            heading.topAnchor.constraint(equalTo: content.topAnchor, constant: 22),
            heading.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            help.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 8),
            help.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            help.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            scroll.topAnchor.constraint(equalTo: help.bottomAnchor, constant: 18),
            scroll.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: help.trailingAnchor),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            targetLabel.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 12),
            targetLabel.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            targetLabel.trailingAnchor.constraint(equalTo: help.trailingAnchor),
            buttons.topAnchor.constraint(equalTo: targetLabel.bottomAnchor, constant: 10),
            buttons.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            status.topAnchor.constraint(equalTo: buttons.bottomAnchor, constant: 10),
            status.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            status.trailingAnchor.constraint(equalTo: help.trailingAnchor),
            status.heightAnchor.constraint(greaterThanOrEqualToConstant: 30),
            hint.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 6),
            hint.leadingAnchor.constraint(equalTo: heading.leadingAnchor),
            hint.trailingAnchor.constraint(equalTo: help.trailingAnchor),
            hint.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18)
        ])
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(editor)
    }

    func textDidChange(_ notification: Notification) {
        startButton.isEnabled = timer == nil && !editor.string.isEmpty
    }

    @objc private func enableAccessibility() {
        let granted = CGPreflightPostEventAccess()
        if permissionFlow.shouldRequest(granted: granted, explicitlyRequested: true) {
            _ = CGRequestPostEventAccess()
        }
        refreshPermission()
        guard !CGPreflightPostEventAccess() else { return }
        status.stringValue = "Enable this build in Accessibility. If already enabled, remove the old Paste2Type entry, add this app again, then reopen it."
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func startTyping() {
        guard timer == nil, !editor.string.isEmpty else { return }
        // Start never requests permission or opens System Settings. Check the
        // event-posting permission needed by CGEvent.post, not AX inspection.
        guard CGPreflightPostEventAccess() else {
            refreshPermission()
            status.stringValue = "Typing access is unavailable. Click Enable Accessibility. If its toggle is already on, remove the old entry and add this build again."
            return
        }
        guard let target = destination, !target.isTerminated else {
            status.stringValue = "Click a field in another app, then come back here to start."
            return
        }
        packets = TypingPlan.packets(for: editor.string)
        offset = 0
        focusedElement = nil
        activeTarget = target
        activationDeadline = Date().addingTimeInterval(1)
        editor.isEditable = false
        startButton.isEnabled = false
        stopButton.isEnabled = true
        status.stringValue = "Switching to \(target.localizedName ?? "destination")…"
        guard target.activate(options: []) else {
            finish("Could not return to the destination app. Click its field and try again.")
            return
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in self?.tick() }
    }

    private func focused(in pid: pid_t) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid),
                                                  kAXFocusedUIElementAttribute as CFString, &value)
        guard result == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private func tick() {
        guard let target = activeTarget else { finish("Stopped."); return }
        let escape = CGEventSource.keyState(.combinedSessionState, key: 53)
        let flags = CGEventSource.flagsState(.combinedSessionState)
        let modifiers = !flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]).isEmpty
        if escape { finish("Stopped."); return }
        // No countdown: begin on the first tick after the destination gains focus.
        // Activation is asynchronous; fail if it never completes instead of typing elsewhere.
        if offset == 0 && NSWorkspace.shared.frontmostApplication?.processIdentifier != target.processIdentifier {
            if Date() >= activationDeadline {
                finish("Could not focus the destination app. Click its field and try again.")
            }
            return
        }
        guard CGPreflightPostEventAccess() else { finish("Stopped: typing permission is no longer available."); return }
        guard TypingPlan.mayContinue(target: target.processIdentifier,
                                     frontmost: NSWorkspace.shared.frontmostApplication?.processIdentifier,
                                     escape: escape, modifiers: modifiers), !target.isTerminated else {
            finish("Stopped: destination changed or a modifier key was pressed.")
            return
        }
        let currentFocus = focused(in: target.processIdentifier)
        if offset == 0 { focusedElement = currentFocus }
        if let original = focusedElement {
            guard let currentFocus, CFEqual(original, currentFocus) else {
                finish("Stopped because the focused field changed.")
                return
            }
        }
        guard offset < packets.count else { finish("Finished sending \(packets.count) characters. Check the destination field."); return }
        guard let (down, up) = TypingPlan.events(for: packets[offset], source: eventSource) else {
            finish("Could not create a keyboard event.")
            return
        }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        offset += 1
        if offset % 10 == 0 { status.stringValue = "Typing… \(offset) / \(packets.count). Hold Esc to stop." }
    }

    @objc private func stopTyping() { finish("Stopped.") }

    private func finish(_ message: String) {
        timer?.invalidate()
        timer = nil
        packets.removeAll()
        activeTarget = nil
        focusedElement = nil
        editor.isEditable = true
        startButton.isEnabled = !editor.string.isEmpty
        stopButton.isEnabled = false
        status.stringValue = message
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { timer?.invalidate() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.regular)
app.delegate = delegate
app.run()
