using System.Text.Json;

namespace OpenNeko.Core;

public sealed record StateBridgeEvent(CatState State, string Source, string? Message);

public sealed class StateBridgeRequestException : Exception
{
    public StateBridgeRequestException(string reason) : base(reason) { Reason = reason; }
    public string Reason { get; }
}

/// <summary>Decodes POST /state bodies. Mirrors StateBridgeRequest.swift.</summary>
public static class StateBridgeRequest
{
    public const int MaxBodyBytes = 4096;

    public static StateBridgeEvent Parse(ReadOnlySpan<byte> data)
    {
        string? rawState, source, message;
        try
        {
            using var doc = JsonDocument.Parse(data.ToArray());
            if (doc.RootElement.ValueKind != JsonValueKind.Object) throw new StateBridgeRequestException("invalidPayload");
            rawState = StringField(doc.RootElement, "state");
            source = StringField(doc.RootElement, "source");
            message = StringField(doc.RootElement, "message");
        }
        catch (JsonException)
        {
            throw new StateBridgeRequestException("invalidPayload");
        }
        catch (InvalidOperationException)
        {
            throw new StateBridgeRequestException("invalidPayload");
        }

        if (rawState is null || MappedState(rawState) is not CatState state)
            throw new StateBridgeRequestException("invalidState");

        var trimmedMessage = message is null ? null : TextUtil.Prefix(message, 120);
        return new StateBridgeEvent(
            state,
            TextUtil.Prefix(source ?? "agent", 40),
            string.IsNullOrEmpty(trimmedMessage) ? null : trimmedMessage);
    }

    private static string? StringField(JsonElement root, string name)
    {
        if (!root.TryGetProperty(name, out var value) || value.ValueKind == JsonValueKind.Null) return null;
        // Mirrors Swift's Decodable: a non-string value is a decoding failure.
        if (value.ValueKind != JsonValueKind.String) throw new StateBridgeRequestException("invalidPayload");
        return value.GetString();
    }

    private static CatState? MappedState(string raw) => raw switch
    {
        "waiting" => CatState.Hover,
        "clicked" => CatState.Click,
        _ => CatStateExtensions.FromRawValue(raw),
    };
}
