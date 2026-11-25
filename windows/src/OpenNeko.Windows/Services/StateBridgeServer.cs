using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Threading;
using OpenNeko.Core;

namespace OpenNeko.Windows.Services;

/// <summary>
/// Local HTTP state bridge on 127.0.0.1 (counterpart of StateBridgeServer.swift).
/// Parsing and routing live in OpenNeko.Core; handlers run on the UI dispatcher.
/// </summary>
internal sealed class StateBridgeServer : IDisposable
{
    public sealed class Handlers
    {
        public Func<CatState> CurrentState { get; init; } = () => CatState.Idle;
        public Func<int> KeyDownCount { get; init; } = () => 0;
        public Func<string?> PositionJson { get; init; } = () => null;
        public Func<byte[]?> CapturePng { get; init; } = () => null;
        public Func<string?> SettingsJson { get; init; } = () => null;
        public Func<string?> AgentJson { get; init; } = () => null;
        public Func<string?> TypingJson { get; init; } = () => null;
        public Func<string?> DebugTyping { get; init; } = () => null;
        public Action<StateBridgeEvent> OnEvent { get; init; } = _ => { };
    }

    private readonly ushort _port;
    private readonly Handlers _handlers;
    private readonly Dispatcher _dispatcher;
    private readonly CancellationTokenSource _cts = new();
    private TcpListener? _listener;

    public StateBridgeServer(ushort port, Handlers handlers, Dispatcher dispatcher)
    {
        _port = port;
        _handlers = handlers;
        _dispatcher = dispatcher;
    }

    public ushort Port => _port;

    public bool Start()
    {
        try
        {
            _listener = new TcpListener(IPAddress.Loopback, _port);
            _listener.Start();
        }
        catch (SocketException)
        {
            _listener = null;
            return false;
        }
        _ = AcceptLoop(_listener, _cts.Token);
        return true;
    }

    public void Dispose()
    {
        _cts.Cancel();
        _listener?.Stop();
        _listener = null;
    }

    private async Task AcceptLoop(TcpListener listener, CancellationToken token)
    {
        while (!token.IsCancellationRequested)
        {
            TcpClient client;
            try { client = await listener.AcceptTcpClientAsync(token).ConfigureAwait(false); }
            catch { return; }
            _ = Task.Run(() => Handle(client, token), token);
        }
    }

    private async Task Handle(TcpClient client, CancellationToken token)
    {
        using (client)
        {
            try
            {
                using var timeout = CancellationTokenSource.CreateLinkedTokenSource(token);
                timeout.CancelAfter(TimeSpan.FromSeconds(5));
                var stream = client.GetStream();
                var buffer = new MemoryStream();
                var chunk = new byte[8192];
                StateBridgeHttpResponse response;
                while (true)
                {
                    var read = await stream.ReadAsync(chunk, timeout.Token).ConfigureAwait(false);
                    if (read > 0) buffer.Write(chunk, 0, read);
                    var request = StateBridgeHttpRequest.TryParse(buffer.GetBuffer().AsSpan(0, (int)buffer.Length));
                    if (request is not null)
                    {
                        response = Respond(request);
                        break;
                    }
                    if (read == 0 || buffer.Length > StateBridgeRequest.MaxBodyBytes + 4096)
                    {
                        response = StateBridgeHttpResponse.BadRequest;
                        break;
                    }
                }
                var bytes = response.ToBytes();
                await stream.WriteAsync(bytes, timeout.Token).ConfigureAwait(false);
            }
            catch
            {
                // connection reset / timeout: nothing to answer
            }
        }
    }

    private StateBridgeHttpResponse Respond(StateBridgeHttpRequest request)
    {
        switch (StateBridgeRouter.Route(request.Method, request.Path))
        {
            case StateBridgeRoute.PostState:
                StateBridgeEvent evt;
                try { evt = StateBridgeRequest.Parse(request.Body); }
                catch (StateBridgeRequestException) { return StateBridgeHttpResponse.BadRequest; }
                _dispatcher.Invoke(() => _handlers.OnEvent(evt));
                return StateBridgeHttpResponse.Ok("ok");
            case StateBridgeRoute.Health:
                return StateBridgeHttpResponse.Ok("openneko");
            case StateBridgeRoute.Anim:
                return StateBridgeHttpResponse.Json(_dispatcher.Invoke(() => StateBridgeRouter.AnimJson(_handlers.CurrentState(), _handlers.KeyDownCount())));
            case StateBridgeRoute.Position:
                return StateBridgeHttpResponse.Json(_dispatcher.Invoke(_handlers.PositionJson) ?? "{}");
            case StateBridgeRoute.Capture:
                var png = _dispatcher.Invoke(_handlers.CapturePng);
                return png is null ? StateBridgeHttpResponse.ServiceUnavailable : StateBridgeHttpResponse.Png(png);
            case StateBridgeRoute.DebugSettings:
                return Json(_handlers.SettingsJson);
            case StateBridgeRoute.DebugAgent:
                return Json(_handlers.AgentJson);
            case StateBridgeRoute.DebugTyping:
                return Json(_handlers.TypingJson);
            case StateBridgeRoute.PostDebugTyping:
                return Json(_handlers.DebugTyping);
            default:
                return StateBridgeHttpResponse.NotFound;
        }
    }

    private StateBridgeHttpResponse Json(Func<string?> handler)
    {
        var payload = _dispatcher.Invoke(handler);
        return payload is null ? StateBridgeHttpResponse.ServiceUnavailable : StateBridgeHttpResponse.Json(payload);
    }
}
