import Foundation

/// Minimal HTTP/1.1 request parsing for the local state bridge server.
/// Kept UI-free so the wire format is unit tested; the socket handling
/// stays in `App/StateBridgeServer.swift`.
public struct StateBridgeHTTPRequest {
    public let method: String
    public let path: String
    public let body: Data

    /// Returns nil while the request is still incomplete (missing header
    /// terminator or body bytes) or when the request is malformed/oversized.
    public init?(data: Data) {
        let separator = Data("\r\n\r\n".utf8)
        guard let headerRange = data.range(of: separator) else { return nil }
        guard let header = String(data: data[..<headerRange.lowerBound], encoding: .utf8) else { return nil }
        let lines = header.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        guard contentLength <= StateBridgeRequest.maxBodyBytes else { return nil }
        let bodyStart = headerRange.upperBound
        guard data.count - bodyStart >= contentLength else { return nil }

        method = String(parts[0])
        path = String(parts[1])
        body = Data(data[bodyStart..<bodyStart + contentLength])
    }
}

public struct StateBridgeHTTPResponse: Equatable {
    public let status: String
    public let contentType: String
    public let body: Data

    public init(status: String, contentType: String, body: Data) {
        self.status = status
        self.contentType = contentType
        self.body = body
    }

    public static func ok(_ body: String) -> StateBridgeHTTPResponse {
        StateBridgeHTTPResponse(status: "200 OK", contentType: "text/plain", body: Data(body.utf8))
    }

    public static func json(_ body: String) -> StateBridgeHTTPResponse {
        StateBridgeHTTPResponse(status: "200 OK", contentType: "application/json", body: Data(body.utf8))
    }

    public static func png(_ body: Data) -> StateBridgeHTTPResponse {
        StateBridgeHTTPResponse(status: "200 OK", contentType: "image/png", body: body)
    }

    public static let badRequest = StateBridgeHTTPResponse(status: "400 Bad Request", contentType: "text/plain", body: Data("bad request".utf8))
    public static let notFound = StateBridgeHTTPResponse(status: "404 Not Found", contentType: "text/plain", body: Data())
    public static let serviceUnavailable = StateBridgeHTTPResponse(status: "503 Service Unavailable", contentType: "text/plain", body: Data())

    public var data: Data {
        var header = ""
        header += "HTTP/1.1 \(status)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(body.count)\r\n"
        header += "Connection: close\r\n"
        header += "\r\n"
        return Data(header.utf8) + body
    }
}

public enum StateBridgePort {
    public static let fallback: UInt16 = 48800

    /// Resolves the listening port from `OPENNEKO_PORT`, falling back to
    /// 48800 when the variable is unset or not a valid UInt16.
    public static func resolve(environment: [String: String]) -> UInt16 {
        guard
            let raw = environment["OPENNEKO_PORT"],
            let port = UInt16(raw)
        else {
            return fallback
        }
        return port
    }
}
