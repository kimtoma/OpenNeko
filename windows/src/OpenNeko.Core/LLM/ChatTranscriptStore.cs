namespace OpenNeko.Core;

/// <summary>Markdown chat history on disk. Mirrors ChatTranscriptStore.swift (same file format).</summary>
public sealed class ChatTranscriptStore
{
    public const string FileName = "chat-history.md";
    private const string FormatMarker = "<!-- openNeko:chat-history:v1 -->";
    private const string UserMarker = "<!-- openNeko:message role=user -->";
    private const string AssistantMarker = "<!-- openNeko:message role=assistant -->";

    private readonly Func<DateTimeOffset> _now;

    public ChatTranscriptStore(string filePath, Func<DateTimeOffset>? now = null)
    {
        FilePath = filePath;
        _now = now ?? (() => DateTimeOffset.UtcNow);
    }

    public string FilePath { get; }

    public IReadOnlyList<ChatMessage> Load()
    {
        try { return File.Exists(FilePath) ? ParseMarkdown(File.ReadAllText(FilePath)) : Array.Empty<ChatMessage>(); }
        catch (IOException) { return Array.Empty<ChatMessage>(); }
    }

    public void Save(IReadOnlyList<ChatMessage> messages)
    {
        if (messages.Count == 0)
        {
            if (File.Exists(FilePath)) File.Delete(FilePath);
            return;
        }
        Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
        var temp = FilePath + ".tmp";
        File.WriteAllText(temp, Markdown(messages, _now()));
        File.Move(temp, FilePath, overwrite: true);
    }

    public static string Markdown(IReadOnlyList<ChatMessage> messages, DateTimeOffset updatedAt)
    {
        var lines = new List<string>
        {
            "# openNeko Chat History", "", FormatMarker, "",
            "_Saved locally by openNeko so the chat history can be restored after restart._", "",
            $"Last updated: {updatedAt.UtcDateTime:yyyy-MM-dd'T'HH:mm:ss'Z'}", "",
        };
        foreach (var message in messages)
        {
            lines.Add(message.Role == ChatRole.User ? UserMarker : AssistantMarker);
            lines.Add($"### {(message.Role == ChatRole.User ? "Me" : "openNeko")}");
            lines.Add("");
            lines.Add(message.Text);
            lines.Add("");
        }
        return string.Join("\n", lines);
    }

    public static IReadOnlyList<ChatMessage> ParseMarkdown(string markdown)
    {
        var lines = markdown.Replace("\r\n", "\n").Replace('\r', '\n').Split('\n');
        var messages = new List<ChatMessage>();
        ChatRole? currentRole = null;
        var body = new List<string>();
        var skippingTitle = false;

        void Commit()
        {
            if (currentRole is not ChatRole role) return;
            var text = string.Join("\n", TrimBlankLines(body));
            if (text.Trim().Length == 0) return;
            messages.Add(new ChatMessage(role, text));
        }

        foreach (var line in lines)
        {
            var marker = line.Trim() switch
            {
                UserMarker => ChatRole.User,
                AssistantMarker => ChatRole.Assistant,
                _ => (ChatRole?)null,
            };
            if (marker is not null)
            {
                Commit();
                currentRole = marker;
                body = new List<string>();
                skippingTitle = true;
                continue;
            }
            if (currentRole is null) continue;
            if (skippingTitle)
            {
                if (line.Trim().Length == 0) continue;
                skippingTitle = false;
                if (line.StartsWith("### ", StringComparison.Ordinal)) continue;
            }
            body.Add(line);
        }
        Commit();
        return messages;
    }

    private static List<string> TrimBlankLines(List<string> lines)
    {
        var result = new List<string>(lines);
        while (result.Count > 0 && result[0].Trim().Length == 0) result.RemoveAt(0);
        while (result.Count > 0 && result[^1].Trim().Length == 0) result.RemoveAt(result.Count - 1);
        return result;
    }
}
