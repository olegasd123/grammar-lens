import Cocoa
import Carbon.HIToolbox
import FlutterMacOS

/// Manages global hotkey registration using NSEvent monitors.
///
/// Registers both global monitors (fires when the app is in the background)
/// and local monitors (fires when the app is in the foreground).
/// When a registered hotkey fires, it brings the GrammarLens window to front
/// and notifies Dart via the `onHotkeyPressed` method channel callback.
class HotkeyManager {

    private let channel: FlutterMethodChannel

    /// Active monitors keyed by shortcut string (e.g. "cmd+shift+g").
    /// Each value is a tuple of (globalMonitor, localMonitor).
    private var monitors: [String: (global: Any?, local: Any?)] = [:]

    init(channel: FlutterMethodChannel) {
        self.channel = channel
    }

    // MARK: - Public API

    func registerHotkey(shortcut: String, result: @escaping FlutterResult) {
        guard AXIsProcessTrusted() else {
            result(FlutterError(
                code: "NO_PERMISSION",
                message: "Accessibility permission required for global hotkeys",
                details: nil
            ))
            return
        }

        // Unregister existing monitor for this shortcut if any
        unregisterMonitor(shortcut)

        let parsed = parseShortcut(shortcut)

        // Global monitor — fires when GrammarLens is NOT the active app
        let globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .keyDown
        ) { [weak self] event in
            if self?.matchesShortcut(event: event, parsed: parsed) == true {
                self?.onHotkeyFired(shortcut: shortcut)
            }
        }

        // Local monitor — fires when GrammarLens IS the active app
        let localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown
        ) { [weak self] event in
            if self?.matchesShortcut(event: event, parsed: parsed) == true {
                self?.onHotkeyFired(shortcut: shortcut)
                return nil // consume the event
            }
            return event
        }

        monitors[shortcut] = (global: globalMonitor, local: localMonitor)
        result(nil) // success
    }

    func unregisterHotkey(shortcut: String, result: @escaping FlutterResult) {
        unregisterMonitor(shortcut)
        result(nil)
    }

    func dispose() {
        for shortcut in monitors.keys {
            unregisterMonitor(shortcut)
        }
    }

    // MARK: - Private

    private func unregisterMonitor(_ shortcut: String) {
        guard let pair = monitors.removeValue(forKey: shortcut) else { return }
        if let global = pair.global {
            NSEvent.removeMonitor(global)
        }
        if let local = pair.local {
            NSEvent.removeMonitor(local)
        }
    }

    private func onHotkeyFired(shortcut: String) {
        // Bring GrammarLens to front
        NSApp.activate(ignoringOtherApps: true)

        // Notify Dart
        DispatchQueue.main.async { [weak self] in
            self?.channel.invokeMethod("onHotkeyPressed", arguments: shortcut)
        }
    }

    /// Check if an NSEvent matches the parsed shortcut.
    private func matchesShortcut(
        event: NSEvent,
        parsed: (modifiers: NSEvent.ModifierFlags, keyCode: UInt16)
    ) -> Bool {
        let relevantFlags: NSEvent.ModifierFlags = [
            .command, .shift, .option, .control,
        ]
        let eventMods = event.modifierFlags.intersection(relevantFlags)
        return eventMods == parsed.modifiers && event.keyCode == parsed.keyCode
    }

    /// Parse a shortcut string like "cmd+shift+g" into modifier flags + key code.
    private func parseShortcut(
        _ shortcut: String
    ) -> (modifiers: NSEvent.ModifierFlags, keyCode: UInt16) {
        let parts = shortcut.lowercased().split(separator: "+").map(String.init)
        var modifiers: NSEvent.ModifierFlags = []
        var keyCode: UInt16 = 0

        for part in parts {
            switch part {
            case "cmd", "command":
                modifiers.insert(.command)
            case "shift":
                modifiers.insert(.shift)
            case "alt", "option":
                modifiers.insert(.option)
            case "ctrl", "control":
                modifiers.insert(.control)
            default:
                keyCode = Self.keyCodeForCharacter(part)
            }
        }

        return (modifiers, keyCode)
    }

    /// Map a single character to the corresponding macOS virtual key code.
    private static func keyCodeForCharacter(_ char: String) -> UInt16 {
        let map: [String: Int] = [
            "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C,
            "d": kVK_ANSI_D, "e": kVK_ANSI_E, "f": kVK_ANSI_F,
            "g": kVK_ANSI_G, "h": kVK_ANSI_H, "i": kVK_ANSI_I,
            "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
            "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O,
            "p": kVK_ANSI_P, "q": kVK_ANSI_Q, "r": kVK_ANSI_R,
            "s": kVK_ANSI_S, "t": kVK_ANSI_T, "u": kVK_ANSI_U,
            "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
            "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
            "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2,
            "3": kVK_ANSI_3, "4": kVK_ANSI_4, "5": kVK_ANSI_5,
            "6": kVK_ANSI_6, "7": kVK_ANSI_7, "8": kVK_ANSI_8,
            "9": kVK_ANSI_9,
            "space": kVK_Space, "return": kVK_Return, "tab": kVK_Tab,
            "escape": kVK_Escape, "esc": kVK_Escape,
        ]
        return UInt16(map[char] ?? 0)
    }
}
