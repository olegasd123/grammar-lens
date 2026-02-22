import Cocoa
import FlutterMacOS

/// Monitors the macOS system clipboard for changes using `NSPasteboard.changeCount` polling.
///
/// There is no system notification for clipboard changes on macOS, so we use a
/// lightweight timer (500 ms interval) that compares the current `changeCount`
/// against the last seen value. When a change is detected, the new text content
/// (if any) is forwarded to the Dart side via `FlutterMethodChannel`.
class ClipboardMonitor {

    private weak var channel: FlutterMethodChannel?
    private var timer: Timer?
    private var lastChangeCount: Int

    init(channel: FlutterMethodChannel) {
        self.channel = channel
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    // MARK: - Public API

    /// Begin polling the system clipboard. Idempotent — calling while already
    /// monitoring is a no-op.
    func startMonitoring(result: @escaping FlutterResult) {
        guard timer == nil else {
            result(true)
            return
        }

        // Snapshot the current change count so we don't fire for the
        // clipboard content that already exists before monitoring starts.
        lastChangeCount = NSPasteboard.general.changeCount

        timer = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: true
        ) { [weak self] _ in
            self?.checkClipboard()
        }

        // Ensure the timer fires even when the run loop is in tracking mode
        // (e.g. during menu interaction or window dragging).
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }

        result(true)
    }

    /// Stop polling the system clipboard.
    func stopMonitoring(result: @escaping FlutterResult) {
        timer?.invalidate()
        timer = nil
        result(true)
    }

    // MARK: - Private

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount

        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let text = pasteboard.string(forType: .string) else { return }

        // Dispatch to main thread for FlutterMethodChannel safety.
        DispatchQueue.main.async { [weak self] in
            self?.channel?.invokeMethod("onClipboardChanged", arguments: text)
        }
    }
}
