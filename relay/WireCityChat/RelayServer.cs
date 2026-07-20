// Embedded IPX-over-WebSocket relay + static docs server.
// Same protocol as ../IpxRelay (the headless seed of the ViewOwl worker);
// this in-process version additionally lets local code join rooms as
// virtual nodes (the chat bot) without a WebSocket.

using System.Collections.Concurrent;
using System.IO;
using System.Net.WebSockets;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.StaticFiles;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Logging;

namespace WireCityChat;

public sealed class RelayServer
{
    private sealed class Room
    {
        public ConcurrentDictionary<ulong, Func<byte[], Task>> Clients { get; } = new();
        // node -> handle for WS callers that passed ?nick=; their chat
        // broadcasts get a "nick: " prefix at routing time, so the DOS
        // side needs no nick code at all.
        public ConcurrentDictionary<ulong, string> Nicks { get; } = new();
    }

    private readonly ConcurrentDictionary<string, Room> _rooms = new();
    private int _nodeCounter;
    private WebApplication? _ipxApp;
    private WebApplication? _docsApp;

    public event Action<string>? Log;
    // room, srcNode, packet - fired for every routed broadcast (bot's own included)
    public event Action<string, ulong, byte[]>? BroadcastRouted;
    // room, node, joined?
    public event Action<string, ulong, bool>? ClientChange;

    public int ClientCount(string roomId) =>
        _rooms.TryGetValue(roomId, out var r) ? r.Clients.Count : 0;

    // Live caller count per room - powers the arcade index "BBS online" header.
    public IReadOnlyDictionary<string, int> RoomSnapshot() =>
        _rooms.ToDictionary(kv => kv.Key, kv => kv.Value.Clients.Count);

    public async Task StartAsync(int ipxPort, string? docsPath, int docsPort)
    {
        var ipxBuilder = WebApplication.CreateBuilder();
        ipxBuilder.Logging.SetMinimumLevel(LogLevel.Warning);
        ipxBuilder.WebHost.UseUrls($"http://0.0.0.0:{ipxPort}");
        _ipxApp = ipxBuilder.Build();
        _ipxApp.UseWebSockets();
        _ipxApp.Map("/ipx/{roomId}", HandleWebSocketAsync);
        await _ipxApp.StartAsync();
        Log?.Invoke($"IPX relay on ws://localhost:{ipxPort}/ipx/<room>");

        if (docsPath is not null && Directory.Exists(docsPath))
        {
            var docsBuilder = WebApplication.CreateBuilder();
            docsBuilder.Logging.SetMinimumLevel(LogLevel.Warning);
            docsBuilder.WebHost.UseUrls($"http://localhost:{docsPort}");
            _docsApp = docsBuilder.Build();
            var contentTypes = new FileExtensionContentTypeProvider();
            contentTypes.Mappings[".jsdos"] = "application/octet-stream";
            contentTypes.Mappings[".wasm"] = "application/wasm";
            var files = new PhysicalFileProvider(Path.GetFullPath(docsPath));
            _docsApp.UseDefaultFiles(new DefaultFilesOptions { FileProvider = files });
            _docsApp.UseStaticFiles(new StaticFileOptions
            {
                FileProvider = files,
                ContentTypeProvider = contentTypes,
                ServeUnknownFileTypes = true,
            });
            // BBS status for the arcade index header: live caller count per room
            // (bots count as online users - they are BBS regulars). CORS-open so
            // a page on another origin (GitHub Pages) can read it too.
            _docsApp.MapGet("/api/bbs/status", (HttpContext c) =>
            {
                c.Response.Headers["Access-Control-Allow-Origin"] = "*";
                return Results.Json(RoomSnapshot());
            });
            await _docsApp.StartAsync();
            Log?.Invoke($"docs on http://localhost:{docsPort}/ ({docsPath})");
        }
        else
        {
            Log?.Invoke("docs folder not found - static server disabled");
        }
    }

    public async Task StopAsync()
    {
        using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(2));
        if (_ipxApp is not null) await _ipxApp.StopAsync(cts.Token);
        if (_docsApp is not null) await _docsApp.StopAsync(cts.Token);
    }

    // ---- virtual nodes (the bot) ----

    public ulong JoinVirtual(string roomId)
    {
        var room = _rooms.GetOrAdd(roomId, _ => new Room());
        var node = MakeNode(Interlocked.Increment(ref _nodeCounter) | 0x8000);
        // Virtual nodes only broadcast; unicast to them is dropped silently.
        room.Clients[node] = _ => Task.CompletedTask;
        Log?.Invoke($"[bot] joined '{roomId}' as {Ipx.NodeHex(node)}");
        ClientChange?.Invoke(roomId, node, true);
        return node;
    }

    public Task SendBroadcastAsync(string roomId, ulong srcNode, ushort socket, byte[] payload)
    {
        var room = _rooms.GetOrAdd(roomId, _ => new Room());
        var packet = Ipx.BuildBroadcast(srcNode, socket, payload);
        return RouteAsync(roomId, room, srcNode, packet);
    }

    // ---- websocket clients (browsers) ----

    private async Task HandleWebSocketAsync(HttpContext ctx)
    {
        if (!ctx.WebSockets.IsWebSocketRequest)
        {
            ctx.Response.StatusCode = 400;
            return;
        }
        var roomId = (string)(ctx.Request.RouteValues["roomId"] ?? "default");
        var nick = SanitizeNick(ctx.Request.Query["nick"].ToString());
        using var ws = await ctx.WebSockets.AcceptWebSocketAsync();
        var room = _rooms.GetOrAdd(roomId, _ => new Room());
        var sendLock = new SemaphoreSlim(1, 1);
        ulong node = 0;

        async Task Deliver(byte[] packet)
        {
            await sendLock.WaitAsync();
            try
            {
                if (ws.State == WebSocketState.Open)
                    await ws.SendAsync(packet, WebSocketMessageType.Binary, true, CancellationToken.None);
            }
            catch (Exception e) when (e is WebSocketException or ObjectDisposedException)
            {
                // peer went away mid-send; the receive loop cleans up
            }
            finally
            {
                sendLock.Release();
            }
        }

        Log?.Invoke($"[+] connection into room '{roomId}'");
        try
        {
            var buffer = new byte[64 * 1024];
            while (ws.State == WebSocketState.Open)
            {
                var length = 0;
                WebSocketReceiveResult result;
                do
                {
                    result = await ws.ReceiveAsync(
                        new ArraySegment<byte>(buffer, length, buffer.Length - length), CancellationToken.None);
                    if (result.MessageType == WebSocketMessageType.Close) return;
                    length += result.Count;
                } while (!result.EndOfMessage);

                if (result.MessageType != WebSocketMessageType.Binary || length < Ipx.HeaderSize) continue;

                var packet = buffer.AsSpan(0, length).ToArray();
                if (Ipx.IsRegistration(packet))
                {
                    var justRegistered = false;
                    if (node == 0)
                    {
                        node = MakeNode(Interlocked.Increment(ref _nodeCounter));
                        room.Clients[node] = Deliver;
                        if (nick.Length > 0) room.Nicks[node] = nick;
                        Log?.Invoke($"[reg] '{roomId}': assigned node {Ipx.NodeHex(node)}"
                            + (nick.Length > 0 ? $" nick '{nick}'" : ""));
                        ClientChange?.Invoke(roomId, node, true);
                        justRegistered = true;
                    }
                    // The ack MUST reach the client before any other packet:
                    // the js-dos client reads its own address out of the first
                    // FFFF-checksum frame it sees. An announce racing ahead of
                    // the ack poisons the client with a broadcast address and
                    // kills the whole tunnel (the 2026-07-18 regression).
                    await Deliver(Ipx.RegAck(node));
                    if (justRegistered)
                    {
                        // Announce the arrival so the room feels alive and the
                        // bots know a caller showed up. Also our visitor count.
                        _ = AnnounceAsync(roomId, room, "* new caller on the wire");
                    }
                    continue;
                }
                if (node == 0) continue;
                await RouteAsync(roomId, room, node, packet);
            }
        }
        catch (Exception e) when (e is WebSocketException or OperationCanceledException or IOException)
        {
            Log?.Invoke($"[!] '{roomId}': {e.Message}");
        }
        finally
        {
            if (node != 0)
            {
                room.Clients.TryRemove(node, out _);
                room.Nicks.TryRemove(node, out _);
                Log?.Invoke($"[-] '{roomId}': node {Ipx.NodeHex(node)} left");
                ClientChange?.Invoke(roomId, node, false);
            }
        }
    }

    // System lines come from a reserved node no client ever gets.
    private const ulong SystemNode = 0x0A00FFFF86FF;

    private Task AnnounceAsync(string roomId, Room room, string text) =>
        RouteAsync(roomId, room, SystemNode,
            Ipx.BuildBroadcast(SystemNode, Ipx.ChatSocket, Ipx.TextPayload(text)));

    private async Task RouteAsync(string roomId, Room room, ulong srcNode, byte[] packet)
    {
        var destNode = Ipx.ReadNode(packet, 10);
        if (destNode == Ipx.Broadcast)
        {
            // Callers with a handle get it stamped onto their chat lines.
            if (Ipx.DestSocket(packet) == Ipx.ChatSocket
                && room.Nicks.TryGetValue(srcNode, out var nick))
                packet = Ipx.WithNickPrefix(packet, nick);
            foreach (var (node, deliver) in room.Clients)
                if (node != srcNode)
                    await deliver(packet);
            BroadcastRouted?.Invoke(roomId, srcNode, packet);
        }
        else if (room.Clients.TryGetValue(destNode, out var deliver))
        {
            await deliver(packet);
        }
    }

    private static ulong MakeNode(int n) =>
        ((ulong)(0x0A000000u | (uint)n) << 16) | (uint)(0x8600 + (n & 0xFF));

    // ASCII word chars only, max 10, and never a bot/system name -
    // those prefixes drive the bots' who-is-speaking logic.
    private static string SanitizeNick(string raw)
    {
        var s = new string(raw.Where(c =>
            c is >= 'a' and <= 'z' or >= 'A' and <= 'Z' or >= '0' and <= '9' or '_' or '-')
            .Take(10).ToArray());
        if (s.Length == 0) return "";
        return s.ToLowerInvariant() is "alex" or "boris" or "sys" ? "x" + s[..Math.Min(9, s.Length)] : s;
    }
}
