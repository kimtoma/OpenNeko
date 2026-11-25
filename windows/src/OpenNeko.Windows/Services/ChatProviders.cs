using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using OpenNeko.Core;

namespace OpenNeko.Windows.Services;

/// <summary>A chat failure with a ready-to-show, localized bubble message.</summary>
internal sealed class ChatFailure : Exception
{
    public ChatFailure(string userMessage) : base(userMessage) { UserMessage = userMessage; }
    public string UserMessage { get; }
}

internal static class ChatProviders
{
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(120) };

    public static Task<string> ReplyAsync(AIProviderConfig config, string? apiKey, IReadOnlyList<ChatMessage> history, string system,
        string languageCode, Action<string>? onPartial, CancellationToken token)
    {
        var kind = CliKindExtensions.FromProvider(config.Type);
        return kind is CliKind cli
            ? CliReplyAsync(cli, config.Model, history, system, languageCode, token)
            : HttpReplyAsync(config, apiKey, history, system, languageCode, onPartial, token);
    }

    // ---- HTTP providers (counterpart of App/HTTPChatProvider.swift) ----

    private static async Task<string> HttpReplyAsync(AIProviderConfig config, string? apiKey, IReadOnlyList<ChatMessage> history, string system,
        string lang, Action<string>? onPartial, CancellationToken token)
    {
        var stream = onPartial is not null && config.Type == AIProviderType.OpenAICompatible;
        HttpChatRequest descriptor;
        try
        {
            descriptor = HttpChatRequestBuilder.Build(config, apiKey, history, system, stream);
        }
        catch (HttpChatConfigurationException e)
        {
            throw new ChatFailure(HttpChatErrors.ConfigurationMessage(e.Kind, lang));
        }

        using var request = new HttpRequestMessage(new HttpMethod(descriptor.Method), descriptor.Url);
        if (descriptor.Body is not null)
        {
            request.Content = new ByteArrayContent(descriptor.Body);
            request.Content.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue("application/json");
        }
        foreach (var (key, value) in descriptor.Headers)
        {
            if (key.Equals("Content-Type", StringComparison.OrdinalIgnoreCase)) continue;
            request.Headers.TryAddWithoutValidation(key, value);
        }

        try
        {
            using var response = await Http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, token).ConfigureAwait(false);
            if (!response.IsSuccessStatusCode)
            {
                var body = await ReadLimitedAsync(response, 4096, token).ConfigureAwait(false);
                var (kind, _) = HttpChatErrors.Classify((int)response.StatusCode, body);
                throw new ChatFailure(HttpChatErrors.UserMessage(kind, lang));
            }
            if (stream)
            {
                using var reader = new StreamReader(await response.Content.ReadAsStreamAsync(token).ConfigureAwait(false), Encoding.UTF8);
                var full = new StringBuilder();
                while (await reader.ReadLineAsync(token).ConfigureAwait(false) is string line)
                {
                    var evt = HttpChatStreamParser.ParseOpenAIEventLine(line);
                    if (evt is null) continue;
                    if (evt.IsDone) break;
                    full.Append(evt.Text);
                    onPartial!(full.ToString());
                }
                return HttpChatStreamParser.NonEmpty(full.ToString());
            }
            var data = await response.Content.ReadAsByteArrayAsync(token).ConfigureAwait(false);
            return HttpChatResponseParser.Parse(data, config.Type);
        }
        catch (HttpChatConfigurationException)
        {
            throw new ChatFailure(HttpChatErrors.UserMessage(HttpChatErrorKind.Empty, lang));
        }
        catch (OperationCanceledException) when (token.IsCancellationRequested)
        {
            throw;
        }
        catch (ChatFailure)
        {
            throw;
        }
        catch (Exception)
        {
            throw new ChatFailure(HttpChatErrors.UserMessage(HttpChatErrorKind.Connection, lang));
        }
    }

    private static async Task<string> ReadLimitedAsync(HttpResponseMessage response, int limit, CancellationToken token)
    {
        var stream = await response.Content.ReadAsStreamAsync(token).ConfigureAwait(false);
        var buffer = new byte[limit];
        var total = 0;
        int read;
        while (total < limit && (read = await stream.ReadAsync(buffer.AsMemory(total, limit - total), token).ConfigureAwait(false)) > 0) total += read;
        return Encoding.UTF8.GetString(buffer, 0, total);
    }

    // ---- CLI login providers (counterpart of CodexChatProvider / AgentCLIChatProvider) ----

    public static string? ResolveCli(CliKind kind) =>
        WindowsCommandLine.Resolve(kind.ExecutableName(), EnvironmentMap(), File.Exists);

    private static async Task<string> CliReplyAsync(CliKind kind, string model, IReadOnlyList<ChatMessage> history, string system,
        string lang, CancellationToken token)
    {
        var executable = ResolveCli(kind) ?? throw new ChatFailure(CliChatFailure.UserMessage(CliFailureKind.Missing, kind, lang));
        var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        var tempRoot = Path.Combine(Path.GetTempPath(), "openneko-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(tempRoot);
        try
        {
            var plan = CliChatPlanner.Plan(kind, model, history, system, lang,
                allowsMultilineArguments: !WindowsCommandLine.IsCmdShim(executable), home, Path.Combine(tempRoot, "last-message.txt"));
            ProcessLaunch launch;
            try
            {
                launch = WindowsCommandLine.Launch(executable, plan.Arguments, Environment.GetEnvironmentVariable("ComSpec") ?? "cmd.exe");
            }
            catch (ArgumentException)
            {
                throw new ChatFailure(CliChatFailure.UserMessage(CliFailureKind.Cli, kind, lang));
            }

            var info = new ProcessStartInfo(launch.FileName)
            {
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardInput = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                StandardInputEncoding = new UTF8Encoding(false),
                StandardOutputEncoding = Encoding.UTF8,
                StandardErrorEncoding = Encoding.UTF8,
                WorkingDirectory = home,
            };
            if (launch.ArgumentList is not null)
                foreach (var arg in launch.ArgumentList) info.ArgumentList.Add(arg);
            else
                info.Arguments = launch.RawArguments;
            info.Environment["NO_COLOR"] = "1";

            using var process = new Process { StartInfo = info };
            try { process.Start(); }
            catch (Win32Exception) { throw new ChatFailure(CliChatFailure.UserMessage(CliFailureKind.Missing, kind, lang)); }

            var stdoutTask = process.StandardOutput.ReadToEndAsync();
            var stderrTask = process.StandardError.ReadToEndAsync();
            await process.StandardInput.WriteAsync(plan.StandardInput).ConfigureAwait(false);
            process.StandardInput.Close();

            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(token);
            timeout.CancelAfter(TimeSpan.FromSeconds(120));
            try
            {
                await process.WaitForExitAsync(timeout.Token).ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
                try { process.Kill(entireProcessTree: true); } catch { }
                if (token.IsCancellationRequested) throw;
                throw new ChatFailure(CliChatFailure.UserMessage(CliFailureKind.Timeout, kind, lang));
            }

            var stdout = await stdoutTask.ConfigureAwait(false);
            var stderr = await stderrTask.ConfigureAwait(false);
            if (process.ExitCode != 0)
            {
                var output = TextUtil.Suffix(string.IsNullOrEmpty(stderr) ? stdout : stderr, 12_000);
                throw new ChatFailure(CliChatFailure.UserMessage(CliChatFailure.Classify(output), kind, lang));
            }

            var text = plan.OutputFile is string outFile && File.Exists(outFile)
                ? File.ReadAllText(outFile, Encoding.UTF8).Trim()
                : stdout.Trim();
            if (text.Length == 0) throw new ChatFailure(CliChatFailure.UserMessage(CliFailureKind.Empty, kind, lang));
            return text;
        }
        finally
        {
            try { Directory.Delete(tempRoot, recursive: true); } catch { }
        }
    }

    public static IReadOnlyDictionary<string, string?> EnvironmentMap() =>
        Environment.GetEnvironmentVariables().Cast<System.Collections.DictionaryEntry>()
            .ToDictionary(e => (string)e.Key, e => e.Value as string, StringComparer.OrdinalIgnoreCase);
}
