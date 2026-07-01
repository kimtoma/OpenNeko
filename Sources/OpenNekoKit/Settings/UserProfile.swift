import Foundation

public struct UserProfile: Codable, Equatable, Sendable {
    public static let empty = UserProfile()

    public var name: String
    public var birthDate: String
    public var birthTime: String
    public var calendar: String

    public init(
        name: String = "",
        birthDate: String = "",
        birthTime: String = "",
        calendar: String = "solar"
    ) {
        self.name = Self.sanitized(name, limit: 64)
        self.birthDate = Self.sanitized(birthDate, limit: 32)
        self.birthTime = Self.sanitized(birthTime, limit: 16)
        switch calendar {
        case "lunar":
            self.calendar = "lunar"
        case "unknown":
            self.calendar = "unknown"
        default:
            self.calendar = "solar"
        }
    }

    public var isEmpty: Bool {
        name.isEmpty && birthDate.isEmpty && birthTime.isEmpty
    }

    public func normalized() -> UserProfile {
        UserProfile(
            name: name,
            birthDate: birthDate,
            birthTime: birthTime,
            calendar: calendar
        )
    }

    public static func sanitized(_ value: String, limit: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(limit))
    }
}
