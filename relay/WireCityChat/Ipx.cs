// IPX packet helpers for the DOSBox/js-dos tunneling protocol.
// One WS binary message == one IPX packet (30-byte header + payload).
// Protocol notes: ../PROTOCOL.md

namespace WireCityChat;

public static class Ipx
{
    public const int HeaderSize = 30;
    public const ushort RegSocket = 0x0002;
    // CHAT.COM broadcast socket as seen on the wire (bytes 0x86 0x39 at
    // offset 16; the DOS side prints it as 3986h in its own byte order).
    public const ushort ChatSocket = 0x8639;
    public const ulong Broadcast = 0xFFFFFFFFFFFF;

    public static ulong ReadNode(ReadOnlySpan<byte> p, int offset)
    {
        ulong v = 0;
        for (var i = 0; i < 6; i++) v = (v << 8) | p[offset + i];
        return v;
    }

    public static void WriteNode(byte[] p, int offset, ulong node)
    {
        for (var i = 5; i >= 0; i--) { p[offset + i] = (byte)node; node >>= 8; }
    }

    public static string NodeHex(ulong node)
    {
        var b = new byte[6];
        WriteNode(b, 0, node);
        return string.Join(":", b.Select(x => x.ToString("x2")));
    }

    public static ushort DestSocket(ReadOnlySpan<byte> p) => (ushort)((p[16] << 8) | p[17]);

    public static bool IsRegistration(ReadOnlySpan<byte> p) =>
        p[0] == 0xFF && p[1] == 0xFF && DestSocket(p) == RegSocket && ReadNode(p, 10) == 0;

    // Mirrors DOSBox ipxserver.cpp ackClient(): the client learns its own
    // address from the dest-node field of this packet.
    public static byte[] RegAck(ulong clientNode)
    {
        var p = new byte[HeaderSize];
        p[0] = 0xFF; p[1] = 0xFF;
        p[3] = HeaderSize;
        WriteNode(p, 10, clientNode);
        p[17] = 0x02;
        p[21] = 0x01;
        p[29] = 0x02;
        return p;
    }

    public static byte[] BuildBroadcast(ulong srcNode, ushort socket, byte[] payload)
    {
        var p = new byte[HeaderSize + payload.Length + 1]; // +1: null terminator
        var len = p.Length;
        p[0] = 0xFF; p[1] = 0xFF;
        p[2] = (byte)(len >> 8); p[3] = (byte)len;
        for (var i = 10; i < 16; i++) p[i] = 0xFF;
        p[16] = (byte)(socket >> 8); p[17] = (byte)socket;
        WriteNode(p, 22, srcNode);
        p[28] = (byte)(socket >> 8); p[29] = (byte)socket;
        payload.CopyTo(p, HeaderSize);
        return p;
    }

    // CHAT.COM payload: ASCII line, null-terminated.
    public static string? PayloadText(ReadOnlySpan<byte> p)
    {
        if (p.Length <= HeaderSize) return null;
        var body = p[HeaderSize..];
        var end = body.IndexOf((byte)0);
        if (end >= 0) body = body[..end];
        if (body.Length == 0) return null;
        var chars = new char[body.Length];
        for (var i = 0; i < body.Length; i++)
            chars[i] = body[i] is >= 0x20 and < 0x7F ? (char)body[i] : '?';
        return new string(chars);
    }

    // Rebuild a chat packet as "nick: text". Header is copied verbatim
    // (src node, sockets); only length + payload change. Payload is
    // capped at 127 chars + NUL to fit the DOS side's 128-byte buffer.
    public static byte[] WithNickPrefix(byte[] packet, string nick)
    {
        var text = PayloadText(packet);
        if (text is null) return packet;
        var line = nick + ": " + text;
        if (line.Length > 127) line = line[..127];
        var payload = TextPayload(line);
        var p = new byte[HeaderSize + payload.Length + 1];
        Array.Copy(packet, p, HeaderSize);
        p[2] = (byte)(p.Length >> 8); p[3] = (byte)p.Length;
        payload.CopyTo(p, HeaderSize);
        return p;
    }

    public static byte[] TextPayload(string line)
    {
        var bytes = new byte[line.Length];
        for (var i = 0; i < line.Length; i++)
            bytes[i] = line[i] is >= (char)0x20 and < (char)0x7F ? (byte)line[i] : (byte)'?';
        return bytes;
    }
}
