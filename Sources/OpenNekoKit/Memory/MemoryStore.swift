import Foundation

/// The three memory files. They are plain Markdown so the user can open,
/// read, edit, or version them like any other note.
public enum MemoryFile: String, CaseIterable, Codable, Sendable {
    /// The cat's persona. Only the user edits it; the cat never writes here.
    case soul
    /// Lasting facts about the user. The cat proposes, the user approves.
    case user
    /// Recent context. The cat writes it, with an undo, and it is compacted.
    case memory

    public var fileName: String { "\(rawValue).md" }

    public var catCanWrite: Bool { self != .soul }

    /// How much of the file goes into a prompt (characters).
    public var promptCharacterLimit: Int {
        switch self {
        case .soul: 2_000
        case .user, .memory: 4_000
        }
    }
}

/// Reads and writes the memory folder (`~/.openneko/memory/` by default).
/// Every write is atomic; nothing is ever hard-deleted: overflow from
/// `memory.md` moves to `archive/YYYY-MM.md`.
public final class MemoryStore {
    public static let compactionByteLimit = 4_096

    public let directoryURL: URL
    private let fileManager: FileManager

    public init(
        directoryURL: URL = MemoryStore.defaultDirectoryURL(),
        fileManager: FileManager = .default
    ) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
    }

    public static func defaultDirectoryURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: String = NSHomeDirectory()
    ) -> URL {
        if let override = environment["OPENNEKO_MEMORY_DIR"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            return URL(fileURLWithPath: (override as NSString).expandingTildeInPath, isDirectory: true)
        }
        return URL(fileURLWithPath: homeDirectory, isDirectory: true)
            .appendingPathComponent(".openneko", isDirectory: true)
            .appendingPathComponent("memory", isDirectory: true)
    }

    public func url(for file: MemoryFile) -> URL {
        directoryURL.appendingPathComponent(file.fileName, isDirectory: false)
    }

    public var archiveDirectoryURL: URL {
        directoryURL.appendingPathComponent("archive", isDirectory: true)
    }

    /// The file's text, or "" when it does not exist yet.
    public func read(_ file: MemoryFile) -> String {
        guard
            let data = try? Data(contentsOf: url(for: file)),
            let text = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return text
    }

    public func snapshot() -> MemorySnapshot {
        MemorySnapshot(soul: read(.soul), user: read(.user), memory: read(.memory))
    }

    public func write(_ text: String, to file: MemoryFile) throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url(for: file), options: .atomic)
    }

    /// Adds one entry the cat wrote. Returns the stored line text, or nil when
    /// the file is not cat-writable or the entry is already there.
    @discardableResult
    public func append(
        _ entry: String,
        to file: MemoryFile,
        now: Date = Date(),
        calendar: Calendar = .current,
        languageCode: String? = nil
    ) throws -> String? {
        guard file.catCanWrite else { return nil }
        let current = read(file)
        let line = MemoryDocument.entryLine(entry, file: file, now: now, calendar: calendar)
        guard let updated = MemoryDocument.appending(
            line,
            to: current,
            header: MemoryCopy.fileHeader(file, languageCode: languageCode)
        ) else {
            return nil
        }
        try write(updated, to: file)
        if file == .memory {
            try compactIfNeeded(now: now, calendar: calendar)
        }
        return line
    }

    /// Undo for a line the cat just wrote.
    public func remove(_ line: String, from file: MemoryFile) throws {
        let current = read(file)
        let updated = MemoryDocument.removing(line, from: current)
        guard updated != current else { return }
        try write(updated, to: file)
    }

    /// Moves the oldest `memory.md` entries into `archive/YYYY-MM.md` once the
    /// file grows past `compactionByteLimit`.
    public func compactIfNeeded(now: Date = Date(), calendar: Calendar = .current) throws {
        let current = read(.memory)
        let result = MemoryDocument.compacted(current, byteLimit: Self.compactionByteLimit)
        guard !result.archived.isEmpty else { return }

        try fileManager.createDirectory(at: archiveDirectoryURL, withIntermediateDirectories: true)
        let archiveURL = archiveDirectoryURL.appendingPathComponent(
            "\(MemoryDocument.monthStamp(now, calendar: calendar)).md",
            isDirectory: false
        )
        var archive = (try? String(contentsOf: archiveURL, encoding: .utf8)) ?? ""
        if !archive.isEmpty, !archive.hasSuffix("\n") { archive += "\n" }
        archive += result.archived.map { "- \($0)" }.joined(separator: "\n") + "\n"
        try Data(archive.utf8).write(to: archiveURL, options: .atomic)
        try write(result.kept, to: .memory)
    }
}

public struct MemorySnapshot: Equatable, Sendable {
    public var soul: String
    public var user: String
    public var memory: String

    public static let empty = MemorySnapshot(soul: "", user: "", memory: "")

    public init(soul: String, user: String, memory: String) {
        self.soul = soul
        self.user = user
        self.memory = memory
    }
}
