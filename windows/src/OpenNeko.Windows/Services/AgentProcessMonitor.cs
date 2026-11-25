using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Management;
using System.Threading.Tasks;
using OpenNeko.Core;

namespace OpenNeko.Windows.Services;

/// <summary>
/// Samples local processes (name, command line, CPU) via WMI and hands them to
/// AgentProcessDetector. Counterpart of AgentProcessMonitor.swift (`ps -axo pcpu,command`).
/// </summary>
internal sealed class AgentProcessMonitor
{
    private readonly Dictionary<uint, TimeSpan> _previousCpu = new();
    private readonly Stopwatch _clock = new();
    private bool _isScanning;

    public async Task<IReadOnlyList<AgentProcessActivity>?> ScanAsync()
    {
        if (_isScanning) return null;
        _isScanning = true;
        try
        {
            return await Task.Run(Scan).ConfigureAwait(true);
        }
        finally
        {
            _isScanning = false;
        }
    }

    private IReadOnlyList<AgentProcessActivity> Scan()
    {
        var elapsed = _clock.IsRunning ? _clock.Elapsed : TimeSpan.Zero;
        _clock.Restart();
        var samples = new List<ProcessSample>();
        var seen = new HashSet<uint>();
        try
        {
            using var searcher = new ManagementObjectSearcher("SELECT ProcessId, Name, CommandLine, KernelModeTime, UserModeTime FROM Win32_Process");
            using var results = searcher.Get();
            foreach (ManagementObject process in results)
            {
                using (process)
                {
                    var pid = Convert.ToUInt32(process["ProcessId"] ?? 0u);
                    var name = process["Name"] as string ?? "";
                    var commandLine = process["CommandLine"] as string;
                    var cpuTime = TimeSpan.FromTicks((long)(Convert.ToUInt64(process["KernelModeTime"] ?? 0UL) + Convert.ToUInt64(process["UserModeTime"] ?? 0UL)));
                    seen.Add(pid);
                    var cpu = _previousCpu.TryGetValue(pid, out var previous)
                        ? AgentProcessDetector.CpuPercent(previous, cpuTime, elapsed)
                        : 0;
                    _previousCpu[pid] = cpuTime;
                    samples.Add(new ProcessSample(name, commandLine, cpu));
                }
            }
        }
        catch (Exception e) when (e is ManagementException or System.Runtime.InteropServices.COMException or UnauthorizedAccessException)
        {
            Debug.WriteLine($"[openNeko] agent scan failed: {e.Message}");
            return Array.Empty<AgentProcessActivity>();
        }
        foreach (var gone in _previousCpu.Keys.Where(pid => !seen.Contains(pid)).ToList()) _previousCpu.Remove(gone);
        return AgentProcessDetector.Detect(samples);
    }
}
