namespace OpenNeko.Core;

public enum CatSoundEffect { Chirp, Pluck, Land, Success, Error }

/// <summary>
/// Synthesizes the small UI blips as in-memory 16-bit mono WAV files. macOS uses
/// built-in system sounds (Pop, Tink, Frog, Hero, Basso); Windows has no quiet
/// equivalents, so the app plays these short tones instead. Volumes match macOS.
/// </summary>
public static class CatSoundSynth
{
    public const int SampleRate = 22_050;
    public const double ThrottleSeconds = 0.12;

    private sealed record Note(double Frequency, double Duration);

    public static double Volume(CatSoundEffect effect) => effect switch
    {
        CatSoundEffect.Success => 0.42,
        CatSoundEffect.Error => 0.34,
        _ => 0.26,
    };

    public static byte[] Wav(CatSoundEffect effect)
    {
        var notes = effect switch
        {
            CatSoundEffect.Chirp => new[] { new Note(1320, 0.05), new Note(1760, 0.06) },
            CatSoundEffect.Pluck => new[] { new Note(1046, 0.045) },
            CatSoundEffect.Land => new[] { new Note(220, 0.07) },
            CatSoundEffect.Success => new[] { new Note(784, 0.08), new Note(988, 0.08), new Note(1318, 0.14) },
            _ => new[] { new Note(330, 0.12), new Note(247, 0.18) },
        };
        var volume = Volume(effect);
        var samples = new List<short>();
        foreach (var note in notes)
        {
            var count = (int)(note.Duration * SampleRate);
            for (var i = 0; i < count; i++)
            {
                var t = (double)i / SampleRate;
                var attack = Math.Min(1.0, i / (SampleRate * 0.004));
                var release = Math.Pow(1.0 - (double)i / count, 2);
                var value = Math.Sin(2 * Math.PI * note.Frequency * t) * attack * release * volume;
                samples.Add((short)(value * short.MaxValue));
            }
        }
        return Encode(samples);
    }

    /// <summary>Returns true when the effect may play now (per-effect throttle like CatSoundPlayer.swift).</summary>
    public static bool ShouldPlay(IDictionary<CatSoundEffect, double> lastPlayedAt, CatSoundEffect effect, double now)
    {
        if (lastPlayedAt.TryGetValue(effect, out var previous) && now - previous < ThrottleSeconds) return false;
        lastPlayedAt[effect] = now;
        return true;
    }

    private static byte[] Encode(List<short> samples)
    {
        using var stream = new MemoryStream();
        using var writer = new BinaryWriter(stream);
        var dataLength = samples.Count * 2;
        writer.Write("RIFF"u8);
        writer.Write(36 + dataLength);
        writer.Write("WAVE"u8);
        writer.Write("fmt "u8);
        writer.Write(16);
        writer.Write((short)1);
        writer.Write((short)1);
        writer.Write(SampleRate);
        writer.Write(SampleRate * 2);
        writer.Write((short)2);
        writer.Write((short)16);
        writer.Write("data"u8);
        writer.Write(dataLength);
        foreach (var s in samples) writer.Write(s);
        writer.Flush();
        return stream.ToArray();
    }
}
