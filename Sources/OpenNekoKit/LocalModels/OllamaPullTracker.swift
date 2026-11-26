import Foundation

/// Aggregates the NDJSON progress stream of Ollama's `POST /api/pull`.
///
/// Each line is one JSON object such as
/// `{"status":"pulling 1a2b","digest":"sha256:1a2b","total":100,"completed":40}`,
/// ending with `{"status":"success"}` or `{"error":"..."}`.
public struct OllamaPullTracker: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case preparing
        case downloading
        case verifying
        case succeeded
        case failed(String)
    }

    public private(set) var phase: Phase = .preparing
    private var layers: [String: Layer] = [:]

    private struct Layer: Equatable, Sendable {
        var total: Int64
        var completed: Int64
    }

    public init() {}

    public var totalBytes: Int64 {
        layers.values.reduce(0) { $0 + $1.total }
    }

    public var completedBytes: Int64 {
        layers.values.reduce(0) { $0 + min($1.completed, $1.total) }
    }

    /// 0...1 across all layers seen so far; 1 once the pull succeeded.
    public var fractionCompleted: Double {
        if phase == .succeeded {
            return 1
        }
        let total = totalBytes
        guard total > 0 else {
            return 0
        }
        return min(1, max(0, Double(completedBytes) / Double(total)))
    }

    public var isFinished: Bool {
        switch phase {
        case .succeeded, .failed: true
        default: false
        }
    }

    /// Feed one line of the stream. Blank or unparsable lines are ignored.
    public mutating func consume(line: String) {
        guard !isFinished else {
            return
        }
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmed.isEmpty,
            let data = trimmed.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return
        }

        if let error = object["error"] as? String {
            phase = .failed(error)
            return
        }

        let status = (object["status"] as? String ?? "").lowercased()
        if status == "success" {
            phase = .succeeded
            return
        }

        if let digest = object["digest"] as? String, !digest.isEmpty {
            let total = Self.int64(object["total"]) ?? layers[digest]?.total ?? 0
            let completed = Self.int64(object["completed"]) ?? layers[digest]?.completed ?? 0
            layers[digest] = Layer(total: total, completed: completed)
            phase = .downloading
            return
        }

        if status.hasPrefix("verifying") || status.hasPrefix("writing") || status.hasPrefix("removing") {
            phase = .verifying
        }
    }

    private static func int64(_ value: Any?) -> Int64? {
        if let number = value as? NSNumber {
            return number.int64Value
        }
        return nil
    }
}
