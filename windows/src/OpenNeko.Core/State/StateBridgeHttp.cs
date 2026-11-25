using System.Text;

namespace OpenNeko.Core;

/// <summary>Minimal HTTP/1.1 request parsing for the local state bridge. Mirrors StateBridgeHTTP.swift.</summary>
public sealed class StateBridgeHttpRequest
{
    private StateBridgeHttpRequest(string method, string path, byte[] body)
    {
        Method = method;
        Path = path;
        Body = body;
    }

    public string Method { get; }
    public string Path { get; }
    public byte[] Body { get; }

    /// <summary>Returns null while incomplete or when malformed/oversized.</summary>
    public static StateBridgeHttpRequest? TryParse(ReadOnlySpan<byte> data)
    {
        var separator = "\r\n\r\n"u8;
        var headerEnd = data.IndexOf(separator);
        if (headerEnd < 0) return null;

        string header;
        try
        {
            header = new UTF8Encoding(false, true).GetString(data[..headerEnd]);
        }
        catch (DecoderFallbackException)
        {
            return null;
        }

        var lines = header.Split("\r\n");
        var parts = lines[0].Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length < 2) return null;

        var headers = new Dictionary<string, string>();
        foreach (var line in lines.Skip(1))
        {
            var colon = line.IndexOf(':');
            if (colon < 0) continue;
            headers[line[..colon].ToLowerInvariant()] = line[(colon + 1)..].Trim(' ', '\t');
        }

        var contentLength = headers.TryGetValue("content-length", out var raw) && int.TryParse(raw, out var n) ? n : 0;
        if (contentLength > StateBridgeRequest.MaxBodyBytes) return null;
        if (contentLength < 0) contentLength = 0;
        var bodyStart = headerEnd + separator.Length;
        if (data.Length - bodyStart < contentLength) return null;

        return new StateBridgeHttpRequest(parts[0], parts[1], data.Slice(bodyStart, contentLength).ToArray());
    }
}

public sealed record StateBridgeHttpResponse(string Status, string ContentType, byte[] Body)
{
    public static StateBridgeHttpResponse Ok(string body) => new("200 OK", "text/plain", Encoding.UTF8.GetBytes(body));
    public static StateBridgeHttpResponse Json(string body) => new("200 OK", "application/json", Encoding.UTF8.GetBytes(body));
    public static StateBridgeHttpResponse Png(byte[] body) => new("200 OK", "image/png", body);
    public static readonly StateBridgeHttpResponse BadRequest = new("400 Bad Request", "text/plain", Encoding.UTF8.GetBytes("bad request"));
    public static readonly StateBridgeHttpResponse NotFound = new("404 Not Found", "text/plain", Array.Empty<byte>());
    public static readonly StateBridgeHttpResponse ServiceUnavailable = new("503 Service Unavailable", "text/plain", Array.Empty<byte>());

    public byte[] ToBytes()
    {
        var header = $"HTTP/1.1 {Status}\r\nContent-Type: {ContentType}\r\nContent-Length: {Body.Length}\r\nConnection: close\r\n\r\n";
        var headerBytes = Encoding.UTF8.GetBytes(header);
        var result = new byte[headerBytes.Length + Body.Length];
        headerBytes.CopyTo(result, 0);
        Body.CopyTo(result, headerBytes.Length);
        return result;
    }
}

public static class StateBridgePort
{
    public const ushort Fallback = 48800;

    public static ushort Resolve(IReadOnlyDictionary<string, string?> environment) =>
        environment.TryGetValue("OPENNEKO_PORT", out var raw) && ushort.TryParse(raw, out var port) ? port : Fallback;
}

/// <summary>Route table for the state bridge: which (method, path) pairs exist. Keeps routing testable.</summary>
public enum StateBridgeRoute { PostState, Health, Anim, Position, Capture, DebugSettings, DebugAgent, DebugTyping, PostDebugTyping, NotFound }

public static class StateBridgeRouter
{
    public static StateBridgeRoute Route(string method, string path) => (method, path) switch
    {
        ("POST", "/state") => StateBridgeRoute.PostState,
        ("GET", "/health") => StateBridgeRoute.Health,
        ("GET", "/anim") => StateBridgeRoute.Anim,
        ("GET", "/pos") or ("GET", "/debug/position") => StateBridgeRoute.Position,
        ("GET", "/capture") => StateBridgeRoute.Capture,
        ("GET", "/debug/settings") => StateBridgeRoute.DebugSettings,
        ("GET", "/debug/agent") => StateBridgeRoute.DebugAgent,
        ("GET", "/debug/typing") => StateBridgeRoute.DebugTyping,
        ("POST", "/debug/typing") => StateBridgeRoute.PostDebugTyping,
        _ => StateBridgeRoute.NotFound,
    };

    public static string AnimJson(CatState state, int keyDownCount) =>
        $"{{\"anim\":\"{state.RawValue()}\",\"keydownCount\":{keyDownCount}}}";
}
