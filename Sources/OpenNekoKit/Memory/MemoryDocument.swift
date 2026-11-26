import Foundation

/// Line-level editing of a memory file. An entry is a Markdown bullet
/// (`- text`); everything else (headings, the user's own prose) is kept as is.
public enum MemoryDocument {
    /// Entry texts in file order, without the leading `- `.
    public static func entries(in text: String) -> [String] {
        lines(text).compactMap(entryText)
    }

    /// The text written for a new entry. `memory.md` entries carry the day so
    /// old context can be told apart from new.
    public static func entryLine(
        _ entry: String,
        file: MemoryFile,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let clean = singleLine(entry)
        guard file == .memory else { return clean }
        return "\(dayStamp(now, calendar: calendar)): \(clean)"
    }

    /// Appends `- line`. Returns nil when the same entry is already present
    /// (dates and spacing are ignored when comparing).
    public static func appending(_ line: String, to text: String, header: String) -> String? {
        let clean = singleLine(line)
        guard !clean.isEmpty else { return nil }
        let key = comparisonKey(clean)
        if entries(in: text).contains(where: { comparisonKey($0) == key }) {
            return nil
        }
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "\(header)\n"
            : text
        if !result.hasSuffix("\n") { result += "\n" }
        // Keep a blank line between a heading or paragraph and the first bullet.
        let lastContent = lines(result).last { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if let lastContent, entryText(lastContent) == nil, !result.hasSuffix("\n\n") {
            result += "\n"
        }
        return result + "- \(clean)\n"
    }

    /// Removes the last bullet that matches `line` (used for undo).
    public static func removing(_ line: String, from text: String) -> String {
        let key = comparisonKey(singleLine(line))
        var all = lines(text)
        guard let index = all.lastIndex(where: { entryText($0).map(comparisonKey) == key }) else {
            return text
        }
        all.remove(at: index)
        return all.joined(separator: "\n")
    }

    /// Drops the oldest bullets until the text fits in three quarters of
    /// `byteLimit`. Nothing is lost: the dropped entries are returned so the
    /// caller can archive them.
    public static func compacted(_ text: String, byteLimit: Int) -> (kept: String, archived: [String]) {
        guard text.utf8.count > byteLimit else { return (text, []) }
        let target = byteLimit * 3 / 4
        var all = lines(text)
        var archived: [String] = []
        while all.joined(separator: "\n").utf8.count > target,
              let index = all.firstIndex(where: { entryText($0) != nil }) {
            if let entry = entryText(all[index]) { archived.append(entry) }
            all.remove(at: index)
        }
        return (all.joined(separator: "\n"), archived)
    }

    /// Lowercased, whitespace-collapsed, without a leading `YYYY-MM-DD:`.
    public static func comparisonKey(_ entry: String) -> String {
        var text = singleLine(entry).lowercased()
        if let range = text.range(of: #"^\d{4}-\d{2}-\d{2}:\s*"#, options: .regularExpression) {
            text.removeSubrange(range)
        }
        return text
    }

    public static func singleLine(_ text: String) -> String {
        var clean = text
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        while clean.hasPrefix("- ") || clean.hasPrefix("* ") {
            clean = String(clean.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        while clean.contains("  ") {
            clean = clean.replacingOccurrences(of: "  ", with: " ")
        }
        return clean
    }

    public static func dayStamp(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    public static func monthStamp(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 1970, c.month ?? 1)
    }

    static func lines(_ text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }

    static func entryText(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") else { return nil }
        let text = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }
}
