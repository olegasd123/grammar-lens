import Cocoa
import ApplicationServices
import FlutterMacOS

/// Wraps macOS Accessibility APIs (AXUIElement) to read and write text
/// in focused text fields of other applications.
///
/// Requires the user to grant Accessibility permission in
/// System Settings > Privacy & Security > Accessibility.
class AccessibilityBridge {

    private let systemWide = AXUIElementCreateSystemWide()
    private var workspaceObserver: NSObjectProtocol?
    private var axObserver: AXObserver?
    private var monitoredPid: pid_t = 0

    // MARK: - Permission

    /// Prompt the user to grant Accessibility permission if not already granted.
    /// Returns `true` if already trusted.
    func requestPermission(result: @escaping FlutterResult) {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true
        ] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        result(trusted)
    }

    /// Check whether Accessibility permission has been granted.
    func hasPermission(result: @escaping FlutterResult) {
        result(AXIsProcessTrusted())
    }

    // MARK: - Read / Write

    /// Read the full text content of the currently focused UI element.
    func readFocusedElement(result: @escaping FlutterResult) {
        guard AXIsProcessTrusted() else { result(nil); return }
        guard let element = getFocusedUIElement() else { result(nil); return }

        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(
            element, kAXValueAttribute as CFString, &value
        )
        if err == .success, let text = value as? String {
            result(text)
        } else {
            result(nil)
        }
    }

    /// Replace the full text content of the currently focused UI element.
    func writeFocusedElement(text: String, result: @escaping FlutterResult) {
        guard AXIsProcessTrusted() else { result(false); return }
        guard let element = getFocusedUIElement() else { result(false); return }

        let err = AXUIElementSetAttributeValue(
            element, kAXValueAttribute as CFString, text as CFTypeRef
        )
        result(err == .success)
    }

    /// Read the currently selected text in the focused element.
    func getSelectedText(result: @escaping FlutterResult) {
        guard AXIsProcessTrusted() else { result(nil); return }
        guard let element = getFocusedUIElement() else { result(nil); return }

        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(
            element, kAXSelectedTextAttribute as CFString, &value
        )
        if err == .success, let text = value as? String {
            result(text)
        } else {
            result(nil)
        }
    }

    /// Replace the currently selected text in the focused element.
    func replaceSelectedText(text: String, result: @escaping FlutterResult) {
        guard AXIsProcessTrusted() else { result(false); return }
        guard let element = getFocusedUIElement() else { result(false); return }

        let err = AXUIElementSetAttributeValue(
            element, kAXSelectedTextAttribute as CFString, text as CFTypeRef
        )
        result(err == .success)
    }

    /// Get the localised name of the currently focused application.
    func getFocusedAppName(result: @escaping FlutterResult) {
        result(NSWorkspace.shared.frontmostApplication?.localizedName)
    }

    // MARK: - Focus Monitoring

    /// Begin observing focus changes across all applications.
    /// Sends `onFocusChanged` events back to Dart via [channel].
    func startFocusMonitoring(channel: FlutterMethodChannel, result: @escaping FlutterResult) {
        // Monitor app activation changes
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            self.onAppActivated(channel: channel)
        }

        // Set up AXObserver for the current frontmost app
        setupAXObserver(channel: channel)

        result(true)
    }

    /// Stop observing focus changes.
    func stopFocusMonitoring(result: @escaping FlutterResult) {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
        teardownAXObserver()
        result(true)
    }

    // MARK: - Private Helpers

    /// Traverse the accessibility tree to find the currently focused UI element.
    ///
    /// Path: system-wide → focused application → focused UI element
    private func getFocusedUIElement() -> AXUIElement? {
        var focusedApp: AnyObject?
        let appErr = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )
        guard appErr == .success, let app = focusedApp else { return nil }

        // swiftlint:disable:next force_cast
        let appElement = app as! AXUIElement

        var focusedElement: AnyObject?
        let elemErr = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        guard elemErr == .success else { return nil }

        // swiftlint:disable:next force_cast
        return focusedElement as! AXUIElement?
    }

    /// Get the accessibility role of an element (e.g., "AXTextField", "AXTextArea").
    private func getElementRole(_ element: AXUIElement) -> String {
        var role: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        return (role as? String) ?? "Unknown"
    }

    /// Called when a new application gains focus.
    private func onAppActivated(channel: FlutterMethodChannel) {
        // Re-attach the AXObserver to the newly focused app
        teardownAXObserver()
        setupAXObserver(channel: channel)

        // Send a focus event
        sendFocusEvent(channel: channel)
    }

    /// Create an AXObserver for the frontmost application's PID to track
    /// focus changes within that app.
    private func setupAXObserver(channel: FlutterMethodChannel) {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let pid = frontApp.processIdentifier
        monitoredPid = pid

        let appElement = AXUIElementCreateApplication(pid)

        var observer: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon = refcon else { return }
            let channelPtr = Unmanaged<FlutterMethodChannel>
                .fromOpaque(refcon)
                .takeUnretainedValue()
            // Dispatch to main queue so it's safe to call Flutter
            DispatchQueue.main.async {
                AccessibilityBridge.sendFocusEventStatic(channel: channelPtr)
            }
        }

        let err = AXObserverCreate(pid, callback, &observer)
        guard err == .success, let obs = observer else { return }

        // Pass the channel pointer as refcon
        let refcon = Unmanaged.passUnretained(channel).toOpaque()

        AXObserverAddNotification(
            obs,
            appElement,
            kAXFocusedUIElementChangedNotification as CFString,
            refcon
        )

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(obs),
            .defaultMode
        )

        axObserver = obs
    }

    /// Remove the current AXObserver.
    private func teardownAXObserver() {
        if let obs = axObserver {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(obs),
                .defaultMode
            )
            axObserver = nil
        }
        monitoredPid = 0
    }

    /// Send a focus-change event to Dart.
    private func sendFocusEvent(channel: FlutterMethodChannel) {
        AccessibilityBridge.sendFocusEventStatic(channel: channel)
    }

    /// Static helper for sending focus events (callable from the C callback).
    fileprivate static func sendFocusEventStatic(channel: FlutterMethodChannel) {
        let bridge = AccessibilityBridge()
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""

        var elementType = "Unknown"
        var text: String?

        if let element = bridge.getFocusedUIElement() {
            elementType = bridge.getElementRole(element)

            var value: AnyObject?
            let err = AXUIElementCopyAttributeValue(
                element, kAXValueAttribute as CFString, &value
            )
            if err == .success, let str = value as? String {
                text = str
            }
        }

        channel.invokeMethod("onFocusChanged", arguments: [
            "appName": appName,
            "elementType": elementType,
            "text": text as Any,
        ])
    }
}
