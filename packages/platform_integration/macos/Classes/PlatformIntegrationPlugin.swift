import FlutterMacOS
import Cocoa

/// Entry point for the platform_integration macOS plugin.
///
/// Registers three MethodChannels:
/// - `com.grammarlens/accessibility` — AXUIElement-based text field access
/// - `com.grammarlens/hotkey` — global hotkey registration via NSEvent
/// - `com.grammarlens/clipboard` — system clipboard change monitoring
public class PlatformIntegrationPlugin: NSObject, FlutterPlugin {

    private var accessibilityBridge: AccessibilityBridge?
    private var hotkeyManager: HotkeyManager?
    private var clipboardMonitor: ClipboardMonitor?

    private var accessibilityChannel: FlutterMethodChannel?
    private var hotkeyChannel: FlutterMethodChannel?
    private var clipboardChannel: FlutterMethodChannel?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = PlatformIntegrationPlugin()

        // Accessibility channel
        let axChannel = FlutterMethodChannel(
            name: "com.grammarlens/accessibility",
            binaryMessenger: registrar.messenger
        )
        instance.accessibilityChannel = axChannel
        instance.accessibilityBridge = AccessibilityBridge()
        registrar.addMethodCallDelegate(instance, channel: axChannel)

        // Hotkey channel
        let hkChannel = FlutterMethodChannel(
            name: "com.grammarlens/hotkey",
            binaryMessenger: registrar.messenger
        )
        instance.hotkeyChannel = hkChannel
        instance.hotkeyManager = HotkeyManager(channel: hkChannel)
        registrar.addMethodCallDelegate(instance, channel: hkChannel)

        // Clipboard channel
        let cbChannel = FlutterMethodChannel(
            name: "com.grammarlens/clipboard",
            binaryMessenger: registrar.messenger
        )
        instance.clipboardChannel = cbChannel
        instance.clipboardMonitor = ClipboardMonitor(channel: cbChannel)
        registrar.addMethodCallDelegate(instance, channel: cbChannel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        // ── Accessibility ────────────────────────────────────────────────
        case "requestPermission":
            accessibilityBridge?.requestPermission(result: result)

        case "hasPermission":
            accessibilityBridge?.hasPermission(result: result)

        case "readFocusedElement":
            accessibilityBridge?.readFocusedElement(result: result)

        case "writeFocusedElement":
            let text = (call.arguments as? [String: Any])?["text"] as? String ?? ""
            accessibilityBridge?.writeFocusedElement(text: text, result: result)

        case "getSelectedText":
            accessibilityBridge?.getSelectedText(result: result)

        case "replaceSelectedText":
            let text = (call.arguments as? [String: Any])?["text"] as? String ?? ""
            accessibilityBridge?.replaceSelectedText(text: text, result: result)

        case "getFocusedAppName":
            accessibilityBridge?.getFocusedAppName(result: result)

        case "startFocusMonitoring":
            if let channel = accessibilityChannel {
                accessibilityBridge?.startFocusMonitoring(channel: channel, result: result)
            } else {
                result(false)
            }

        case "stopFocusMonitoring":
            accessibilityBridge?.stopFocusMonitoring(result: result)

        // ── Hotkey ───────────────────────────────────────────────────────
        case "registerHotkey":
            let shortcut = (call.arguments as? [String: Any])?["shortcut"] as? String ?? ""
            hotkeyManager?.registerHotkey(shortcut: shortcut, result: result)

        case "unregisterHotkey":
            let shortcut = (call.arguments as? [String: Any])?["shortcut"] as? String ?? ""
            hotkeyManager?.unregisterHotkey(shortcut: shortcut, result: result)

        // ── Clipboard ──────────────────────────────────────────────────────
        case "startMonitoring":
            clipboardMonitor?.startMonitoring(result: result)

        case "stopMonitoring":
            clipboardMonitor?.stopMonitoring(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
