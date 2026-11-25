using System.Text.Json;

namespace OpenNeko.Core;

public sealed class SpriteManifestException : Exception
{
    public SpriteManifestException(string reason) : base(reason) { }
}

/// <summary>state -> frame file names. Mirrors SpriteManifest.swift.</summary>
public sealed class SpriteManifest
{
    public SpriteManifest(byte[] data)
    {
        JsonDocument doc;
        try { doc = JsonDocument.Parse(data); }
        catch (JsonException) { throw new SpriteManifestException("invalidJSON"); }

        using (doc)
        {
            if (doc.RootElement.ValueKind != JsonValueKind.Object) throw new SpriteManifestException("invalidJSON");
            var parsed = new Dictionary<string, IReadOnlyList<string>>();
            foreach (var property in doc.RootElement.EnumerateObject())
            {
                if (property.Value.ValueKind != JsonValueKind.Array) continue;
                var frames = new List<string>();
                var valid = true;
                foreach (var item in property.Value.EnumerateArray())
                {
                    if (item.ValueKind != JsonValueKind.String) { valid = false; break; }
                    frames.Add(item.GetString()!);
                }
                if (valid) parsed[property.Name] = frames;
            }
            if (parsed.Count == 0) throw new SpriteManifestException("empty");
            States = parsed;
        }
    }

    public IReadOnlyDictionary<string, IReadOnlyList<string>> States { get; }

    public IReadOnlyList<string> Frames(string state) =>
        States.TryGetValue(state, out var frames) ? frames : Array.Empty<string>();

    public IReadOnlyList<string> StateNames => States.Keys.OrderBy(k => k, StringComparer.Ordinal).ToList();
}

public sealed record Skin(string Id, string Directory, SpriteManifest Manifest)
{
    /// <summary>Absolute PNG paths for a state, resolved inside this skin's directory.</summary>
    public IReadOnlyList<string> FramePaths(string state) =>
        Manifest.Frames(state).Select(f => System.IO.Path.Combine(Directory, f)).ToList();
}

/// <summary>Resolves bundled + installed skins. Mirrors SkinManager.swift.</summary>
public sealed class SkinManager
{
    public const string DefaultId = "default";

    private readonly string _bundledRoot;
    private readonly string? _externalRoot;

    public SkinManager(string bundledRoot, string? externalRoot = null)
    {
        _bundledRoot = bundledRoot;
        _externalRoot = externalRoot;
    }

    public IReadOnlyList<string> AvailableSkinIds()
    {
        var ids = new HashSet<string> { DefaultId };
        foreach (var root in new[] { _bundledRoot, _externalRoot })
        {
            if (root is null || !System.IO.Directory.Exists(root)) continue;
            foreach (var dir in System.IO.Directory.GetDirectories(root))
                ids.Add(System.IO.Path.GetFileName(dir));
        }
        return ids.OrderBy(i => i, StringComparer.Ordinal).ToList();
    }

    public Skin LoadSkin(string id)
    {
        var dir = DirectoryFor(id) ?? throw new FileNotFoundException("skinNotFound", id);
        SpriteManifest manifest;
        var own = System.IO.Path.Combine(dir, "manifest.json");
        SpriteManifest? ownManifest = null;
        if (File.Exists(own))
        {
            try { ownManifest = new SpriteManifest(File.ReadAllBytes(own)); }
            catch (SpriteManifestException) { }
        }
        manifest = ownManifest ?? RootManifest();
        return new Skin(id, dir, manifest);
    }

    public Skin LoadDefault()
    {
        try { return LoadSkin(DefaultId); }
        catch (Exception e) when (e is FileNotFoundException or SpriteManifestException or IOException)
        {
            return new Skin(DefaultId, _bundledRoot, new SpriteManifest("{\"idle\":[]}"u8.ToArray()));
        }
    }

    private SpriteManifest RootManifest()
    {
        var path = System.IO.Path.Combine(_bundledRoot, "manifest.json");
        if (!File.Exists(path)) throw new FileNotFoundException("manifestMissing", path);
        return new SpriteManifest(File.ReadAllBytes(path));
    }

    private string? DirectoryFor(string id)
    {
        if (id == DefaultId) return _bundledRoot;
        if (id.IndexOfAny(new[] { '/', '\\' }) >= 0 || id is "." or "..") return null;
        foreach (var root in new[] { _externalRoot, _bundledRoot })
        {
            if (root is null) continue;
            var dir = System.IO.Path.Combine(root, id);
            if (System.IO.Directory.Exists(dir)) return dir;
        }
        return null;
    }

    /// <summary>User-facing label: the default skin is the white cat.</summary>
    public static string Label(string id) => id == DefaultId ? "white" : id;
}
