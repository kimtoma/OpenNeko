import AppKit
import OpenNekoKit

/// Receives text the user sends through the macOS Services menu
/// ("openNeko: Explain / Translate / Summarize", declared in Info.plist).
/// Only the explicitly sent selection is read; no screen capture.
final class SelectedTextServiceProvider: NSObject {
    var handler: ((SelectedTextAction, String) -> Void)?

    @objc func handleSelectedText(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        guard
            let action = SelectedTextAction(userData: userData),
            let text = pboard.string(forType: .string),
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            error.pointee = "openNeko: no text" as NSString
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.handler?(action, text)
        }
    }
}
