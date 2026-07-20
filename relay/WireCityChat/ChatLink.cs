// How the bot reaches the room: either through the embedded relay
// (this instance hosts everything) or as a plain IPX-over-WS client of
// another relay (second bot instance, or later the ViewOwl pipe).

using System.Net.WebSockets;

namespace WireCityChat;

public interface IChatLink
{
    ulong BotNode { get; }
    int ClientCount { get; } // -1 = unknown (remote mode)
    event Action<string>? Log;
    event Action<ulong, byte[]>? PacketSeen; // srcNode, packet (bot's own included)
    event Action<ulong, bool>? ClientChange; // embedded mode only
    Task StartAsync();
    Task StopAsync();
    Task SendBroadcastAsync(ushort socket, byte[] payload);
}

public sealed class EmbeddedLink(BotSettings settings) : IChatLink
{
    private readonly RelayServer _relay = new();
    private ulong _node;

    public ulong BotNode => _node;
    public int ClientCount => _relay.ClientCount(settings.Room);
    public event Action<string>? Log;
    public event Action<ulong, byte[]>? PacketSeen;
    public event Action<ulong, bool>? ClientChange;

    public async Task StartAsync()
    {
        _relay.Log += m => Log?.Invoke(m);
        _relay.BroadcastRouted += (room, src, packet) =>
        {
            if (room == settings.Room) PacketSeen?.Invoke(src, packet);
        };
        _relay.ClientChange += (room, node, joined) =>
        {
            if (room == settings.Room) ClientChange?.Invoke(node, joined);
        };
        await _relay.StartAsync(settings.IpxPort, settings.FindDocsPath(), settings.DocsPort);
        _node = _relay.JoinVirtual(settings.Room);
    }

    public Task StopAsync() => _relay.StopAsync();

    public Task SendBroadcastAsync(ushort socket, byte[] payload) =>
        _relay.SendBroadcastAsync(settings.Room, _node, socket, payload);
}

public sealed class RemoteLink(BotSettings settings) : IChatLink
{
    private ClientWebSocket? _ws;
    private ulong _node;
    private readonly SemaphoreSlim _sendLock = new(1, 1);
    private CancellationTokenSource? _cts;

    public ulong BotNode => _node;
    public int ClientCount => -1;
    public event Action<string>? Log;
    public event Action<ulong, byte[]>? PacketSeen;
    public event Action<ulong, bool>? ClientChange { add { } remove { } }

    public async Task StartAsync()
    {
        _cts = new CancellationTokenSource();
        _ws = new ClientWebSocket();
        // ViewOwl's SecurityMiddleware rejects empty User-Agent with 400 -
        // identify ourselves like any polite client would.
        _ws.Options.SetRequestHeader("User-Agent", "WireCityChat/1.0 (+https://view.owlos.sk)");
        await _ws.ConnectAsync(new Uri(settings.RelayUrl), _cts.Token);
        Log?.Invoke($"connected to remote relay {settings.RelayUrl}");

        // DOSBox-style registration: 30-byte header, socket 0x0002.
        var reg = new byte[Ipx.HeaderSize];
        reg[0] = 0xFF; reg[1] = 0xFF; reg[3] = Ipx.HeaderSize;
        reg[17] = 0x02; reg[29] = 0x02;
        await SendRawAsync(reg);

        var ack = await ReceiveAsync(_cts.Token)
            ?? throw new InvalidOperationException("relay closed during registration");
        if (Ipx.DestSocket(ack) != Ipx.RegSocket)
            throw new InvalidOperationException("unexpected packet during registration");
        _node = Ipx.ReadNode(ack, 10);
        Log?.Invoke($"registered as {Ipx.NodeHex(_node)}");

        _ = Task.Run(ReceiveLoopAsync);
    }

    public async Task StopAsync()
    {
        _cts?.Cancel();
        if (_ws is { State: WebSocketState.Open })
            await _ws.CloseAsync(WebSocketCloseStatus.NormalClosure, "bye", CancellationToken.None);
    }

    public async Task SendBroadcastAsync(ushort socket, byte[] payload)
    {
        var packet = Ipx.BuildBroadcast(_node, socket, payload);
        await SendRawAsync(packet);
        // The relay does not echo to the sender - surface our own line locally.
        PacketSeen?.Invoke(_node, packet);
    }

    private async Task SendRawAsync(byte[] packet)
    {
        if (_ws is null) return;
        await _sendLock.WaitAsync();
        try
        {
            if (_ws.State == WebSocketState.Open)
                await _ws.SendAsync(packet, WebSocketMessageType.Binary, true, CancellationToken.None);
        }
        finally
        {
            _sendLock.Release();
        }
    }

    private async Task ReceiveLoopAsync()
    {
        try
        {
            while (_ws is { State: WebSocketState.Open } && _cts is { IsCancellationRequested: false })
            {
                var packet = await ReceiveAsync(_cts.Token);
                if (packet is null) break;
                if (Ipx.DestSocket(packet) == Ipx.RegSocket) continue;
                PacketSeen?.Invoke(Ipx.ReadNode(packet, 22), packet);
            }
        }
        catch (Exception e) when (e is WebSocketException or OperationCanceledException)
        {
        }
        Log?.Invoke("remote relay connection closed");
    }

    private async Task<byte[]?> ReceiveAsync(CancellationToken ct)
    {
        if (_ws is null) return null;
        var buffer = new byte[64 * 1024];
        var length = 0;
        WebSocketReceiveResult result;
        do
        {
            result = await _ws.ReceiveAsync(
                new ArraySegment<byte>(buffer, length, buffer.Length - length), ct);
            if (result.MessageType == WebSocketMessageType.Close) return null;
            length += result.Count;
        } while (!result.EndOfMessage);
        return length >= Ipx.HeaderSize ? buffer.AsSpan(0, length).ToArray() : await ReceiveAsync(ct);
    }
}
