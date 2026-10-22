import AppKit
import CoreGraphics
import OpenNekoKit

enum ScreenPetWindowDetector {
    static func candidates(
        screenFrames: [CGRect],
        fallbackScreenFrame: CGRect?,
        excludingPID: pid_t = ProcessInfo.processInfo.processIdentifier
    ) -> [ScreenPetCandidate] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return windows.compactMap { info in
            let ownerPID = info[kCGWindowOwnerPID as String] as? Int ?? -1
            guard
                (info[kCGWindowIsOnscreen as String] as? Int ?? 0) != 0,
                ownerPID != Int(excludingPID),
                (info[kCGWindowAlpha as String] as? Double ?? 0) > 0.05,
                let frame = appKitFrame(
                    from: info[kCGWindowBounds as String],
                    screenFrames: screenFrames,
                    fallbackScreenFrame: fallbackScreenFrame
                )
            else {
                return nil
            }
            let ownerName = info[kCGWindowOwnerName as String] as? String ?? ""
            let windowName = info[kCGWindowName as String] as? String ?? ""
            let windowNumber = info[kCGWindowNumber as String] ?? ""
            let candidate = ScreenPetCandidate(
                id: "\(windowNumber)",
                ownerName: ownerName,
                windowName: windowName,
                frame: frame
            )
            return ScreenPetEncounter.isCodexPetCandidate(candidate) ? candidate : nil
        }
    }

    private static func appKitFrame(
        from value: Any?,
        screenFrames: [CGRect],
        fallbackScreenFrame: CGRect?
    ) -> CGRect? {
        guard
            let dictionary = value as? NSDictionary,
            let cgFrame = CGRect(dictionaryRepresentation: dictionary)
        else {
            return nil
        }
        let screenFrame = screenFrames.first { frame in
            cgFrame.midX >= frame.minX && cgFrame.midX <= frame.maxX
        } ?? fallbackScreenFrame
        guard let screenFrame else { return nil }
        return CGRect(
            x: cgFrame.minX,
            y: screenFrame.maxY - cgFrame.maxY,
            width: cgFrame.width,
            height: cgFrame.height
        )
    }
}
