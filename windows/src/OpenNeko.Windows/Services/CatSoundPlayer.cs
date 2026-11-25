using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Media;
using OpenNeko.Core;

namespace OpenNeko.Windows.Services;

/// <summary>Plays the synthesized blips (see CatSoundSynth). Counterpart of CatSoundPlayer.swift.</summary>
internal sealed class CatSoundPlayer
{
    private readonly Dictionary<CatSoundEffect, SoundPlayer> _players = new();
    private readonly Dictionary<CatSoundEffect, double> _lastPlayedAt = new();
    private readonly Stopwatch _clock = Stopwatch.StartNew();

    public void Play(CatSoundEffect effect)
    {
        if (!CatSoundSynth.ShouldPlay(_lastPlayedAt, effect, _clock.Elapsed.TotalSeconds)) return;
        if (!_players.TryGetValue(effect, out var player))
        {
            player = new SoundPlayer(new MemoryStream(CatSoundSynth.Wav(effect)));
            player.Load();
            _players[effect] = player;
        }
        try { player.Play(); }
        catch { /* audio device unavailable: stay silent */ }
    }
}
