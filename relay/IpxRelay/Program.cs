// Dev IPX-over-WebSocket relay speaking the DOSBox/js-dos tunneling protocol.
// One WS binary message == one IPX packet (30-byte header + payload).
// Rooms are addressed by URL path: ws://localhost:1900/ipx/<room>.
// Protocol notes: ../PROTOCOL.md. This app is the seed of the ViewOwl worker.
//
// Run:  dotnet run [--port 1900]

using System.Collections.Concurrent;
using System.Net.WebSockets;

const int HeaderSize = 30;
const ushort RegSocket = 0x0002;
const ulong Broadcast = 0xFFFFFFFFFFFF;

var port = 1900;
var portArgIndex = Array.IndexOf(args, "--port");
if (portArgIndex >= 0 && portArgIndex + 1 < args.Length) port = int.Parse(args[portArgIndex + 1]);

var rooms = new ConcurrentDictionary<string, Room>();
var nodeCounter = 0;

var builder = WebApplication.CreateBuilder();
builder.Logging.SetMinimumLevel(LogLevel.Warning);
builder.WebHost.UseUrls($"http://0.0.0.0:{port}");
var app = builder.Build();
app.UseWebSockets();

app.Map("/ipx/{roomId}", async (HttpContext ctx, string roomId) =>
{
    if (!ctx.WebSockets.IsWebSocketRequest)
    {
        ctx.Response.StatusCode = 400;
        return;
    }
    using var ws = await ctx.WebSockets.AcceptWebSocketAsync();
    var room = rooms.GetOrAdd(roomId, _ => new Room());
    var client = new Client(ws);
    ulong node = 0;
    Log($"[+] connection into room '{roomId}' from {ctx.Connection.RemoteIpAddress}:{ctx.Connection.RemotePort}");
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

            if (result.MessageType != WebSocketMessageType.Binary)
            {
                Log($"[?] text frame ignored ({length}b)");
                continue;
            }
            if (length < HeaderSize)
            {
                Log($"[?] short frame ({length}b): {Hex(buffer, length)}");
                continue;
            }

            var msg = buffer.AsSpan(0, length);
            var checksum = (ushort)(msg[0] << 8 | msg[1]);
            var destNode = ReadNode(msg, 10);
            var destSock = (ushort)(msg[16] << 8 | msg[17]);
            var srcNode = ReadNode(msg, 22);

            if (node == 0) Log($"[reg?] first packet in '{roomId}': {Hex(buffer, Math.Min(length, 48))}");

            var isRegistration = checksum == 0xFFFF && destSock == RegSocket && destNode == 0;
            if (isRegistration)
            {
                if (node == 0)
                {
                    var n = Interlocked.Increment(ref nodeCounter);
                    node = MakeNode(n);
                    room.Clients[node] = client;
                    Log($"[reg] '{roomId}': assigned node {NodeHex(node)}");
                }
                await client.SendAsync(RegAck(node));
                continue;
            }

            if (node == 0)
            {
                Log($"[?] pre-registration packet dropped: {Hex(buffer, Math.Min(length, 48))}");
                continue;
            }

            var packet = msg.ToArray();
            if (destNode == Broadcast)
            {
                var peers = room.Clients.Where(kv => kv.Key != node).Select(kv => kv.Value).ToList();
                foreach (var peer in peers) await peer.SendAsync(packet);
                Log($"[bcast] '{roomId}' {NodeHex(node)} -> {peers.Count} peers, {length}b sock={destSock:x4}");
            }
            else if (room.Clients.TryGetValue(destNode, out var target))
            {
                await target.SendAsync(packet);
                Log($"[ucast] '{roomId}' {NodeHex(srcNode)} -> {NodeHex(destNode)}, {length}b");
            }
            else
            {
                Log($"[drop] '{roomId}' no such node {NodeHex(destNode)}");
            }
        }
    }
    catch (Exception e) when (e is WebSocketException or OperationCanceledException or IOException)
    {
        Log($"[!] '{roomId}' error: {e.Message}");
    }
    finally
    {
        if (node != 0)
        {
            room.Clients.TryRemove(node, out _);
            Log($"[-] '{roomId}': node {NodeHex(node)} left");
        }
        if (room.Clients.IsEmpty) rooms.TryRemove(roomId, out _);
        Log($"[-] connection closed, room '{roomId}' size={room.Clients.Count}");
    }
});

Log($"IPX relay listening on ws://localhost:{port}/ipx/<room>");
app.Run();

// DOSBox packs IPv4+port into the 6-byte node; any unique bytes work over WS.
static ulong MakeNode(int n) =>
    ((ulong)(0x0A000000u | (uint)n) << 16) | (uint)(0x8600 + (n & 0xFF));

static ulong ReadNode(ReadOnlySpan<byte> msg, int offset)
{
    ulong v = 0;
    for (var i = 0; i < 6; i++) v = (v << 8) | (ulong)msg[offset + i];
    return v;
}

// Mirrors DOSBox ipxserver.cpp ackClient(): the client learns its own
// address from the dest-node field of this packet.
static byte[] RegAck(ulong clientNode)
{
    var p = new byte[HeaderSize];
    p[0] = 0xFF; p[1] = 0xFF;                  // checksum
    p[2] = 0x00; p[3] = HeaderSize;            // length
    WriteNode(p, 10, clientNode);              // dest node = assigned address
    p[17] = 0x02;                              // dest socket
    p[21] = 0x01;                              // src network = 1 (server)
    p[29] = 0x02;                              // src socket
    return p;
}

static void WriteNode(byte[] p, int offset, ulong node)
{
    for (var i = 5; i >= 0; i--) { p[offset + i] = (byte)node; node >>= 8; }
}

static string NodeHex(ulong node)
{
    var b = new byte[6];
    WriteNode(b, 0, node);
    return string.Join(":", b.Select(x => x.ToString("x2")));
}

static string Hex(byte[] buffer, int length) =>
    string.Join(" ", buffer.Take(length).Select(b => b.ToString("x2")));

static void Log(string message) => Console.WriteLine(message);

sealed class Room
{
    public ConcurrentDictionary<ulong, Client> Clients { get; } = new();
}

// WebSocket.SendAsync must not run concurrently per socket.
sealed class Client(WebSocket ws)
{
    private readonly SemaphoreSlim _sendLock = new(1, 1);

    public async Task SendAsync(byte[] packet)
    {
        await _sendLock.WaitAsync();
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
            _sendLock.Release();
        }
    }
}
