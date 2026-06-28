import AppKit

enum CatSoundEffect: String {
    case chirp
    case pluck
    case land
    case success
    case error
}

final class CatSoundPlayer {
    private var lastPlayedAt: [CatSoundEffect: TimeInterval] = [:]
    private let throttle: TimeInterval = 0.12

    func play(_ effect: CatSoundEffect) {
        let now = ProcessInfo.processInfo.systemUptime
        if let previous = lastPlayedAt[effect], now - previous < throttle {
            return
        }
        lastPlayedAt[effect] = now

        for name in soundNames(for: effect) {
            if let sound = NSSound(named: NSSound.Name(name)) {
                sound.volume = volume(for: effect)
                sound.play()
                return
            }
        }

        NSSound.beep()
    }

    private func soundNames(for effect: CatSoundEffect) -> [String] {
        switch effect {
        case .chirp:
            ["Pop", "Ping"]
        case .pluck:
            ["Tink", "Pop"]
        case .land:
            ["Frog", "Pop"]
        case .success:
            ["Hero", "Glass", "Ping"]
        case .error:
            ["Basso", "Funk", "Sosumi"]
        }
    }

    private func volume(for effect: CatSoundEffect) -> Float {
        switch effect {
        case .success:
            0.42
        case .error:
            0.34
        default:
            0.26
        }
    }
}
