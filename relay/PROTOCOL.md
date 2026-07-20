# js-dos IPX-over-WebSocket protocol (reversed from the local v8 copy)

Sources: docs/jsdos/js-dos.js, docs/jsdos/emulators/emulators.js,
docs/jsdos/emulators/wdosbox.js + strings in wdosbox.wasm. 2026-07-17.

## Transport chain

```
DOS app --INT 7Ah/2Fh--> DOSBox IPX core (wasm)
  --em_net_send/ws-net-send--> emulators.js host
  --WebSocket binary message--> relay server
```

- The host side (`emulators.js`, `ws-net-connect` handler) does simply
  `new WebSocket(address); binaryType="arraybuffer"` and pipes bytes both
  ways **unchanged**. No extra framing on the wire:
  **one WS binary message == one complete IPX packet** (30-byte header +
  payload).
- The wasm core is the classic DOSBox IPX tunneling client (`ipx.cpp`),
  confirmed by wasm strings ("IPX Tunneling Client connected to server
  at %s", "IPX address is %d:%d:%d:%d:%d:%d").

## Room URL convention

The js-dos UI builds the address as:

```
<backendHost> + ":1900/ipx/" + room.replaceAll("@","_")
```

e.g. `wss://netherlands.dos.zone:1900/ipx/wirecity`. Port **1900 is
hard-appended** by the UI, so a production relay must be reachable on
port 1900 (or we call `ci.networkConnect(0, url)` ourselves with any
URL). `Dos()` options accept `ipx: [{name, host}]`, `ipxBackend: name`,
`room: string` — so a page can point the built-in UI at our relay.
`emulators.js` prefixes `ws://`/`wss://` by page protocol if missing.

## IPX header (30 bytes, big-endian on-wire)

```
offset size  field
0      2     checksum        (0xFFFF = "no checksum", always FFFF)
2      2     length          (header+payload, BE)
4      1     transport ctl   (0)
5      1     packet type     (0)
6      4     dest network    (0)
10     6     dest node       (relay-assigned address or FF*6 broadcast)
16     2     dest socket     (BE; 0x0002 = registration/echo)
18     4     src network     (0; server uses 1 in its ack)
22     6     src node
28     2     src socket
```

DOSBox convention: the 6-byte node = 4-byte IPv4 + 2-byte UDP port of
the client. Over WS there is no IP/port — the relay may assign any
unique 6 bytes.

## Handshake (DOSBox ipx.cpp / ipxserver.cpp semantics)

1. Client connects to `wss://host:1900/ipx/<room>` and sends a 30-byte
   registration packet: checksum=FFFF, length=30, dest socket=0x0002,
   src socket=0x0002, all addresses zero.
2. Server replies with a 30-byte packet: checksum=FFFF, length=30,
   **dest node = the address it assigns to this client**, dest
   socket=0x0002, src network=1, src node = server address, src
   socket=0x0002. The client copies dest node into its local IPX
   address ("IPX address is ..." log line).
3. After that the relay routes every message by the dest node field:
   - dest node == FF FF FF FF FF FF → broadcast to every client in the
     room except the sender (CHAT.ASM has an own-echo filter anyway,
     commit b0c53e7 on the network branch);
   - otherwise unicast to the client whose assigned node matches;
   - packets to socket 0x0002 with checksum FFFF and zero dest node are
     (re-)registration requests, answer them, do not route.

Empirical byte log of a real js-dos connect: see the IpxRelay output
(it hex-dumps the first packets of every connection). Confirmed
2026-07-17: the registration packet on the wire is exactly
`ff ff 00 1e 00 00 | dest 0/0/0002 | src 0/0/0002`.

The dev relay lives in IpxRelay/ (C# / ASP.NET minimal, net9.0 - the
ViewOwl worker seed): `dotnet run --port 1900`.

## Rooms

The URL path after `/ipx/` is the room id. Clients in different rooms
never see each other. This maps 1:1 onto the future ViewOwl worker:
one WS endpoint, path-addressed rooms, per-room client tables.

## Carry-over gotchas

- The WS path is binary-clean — no nibble armour (that saga was
  DOSBox-nullmodem-specific).
- Bundles must be renamed per release (IndexedDB caches by URL).
- Player page needs `noNetworking:false`; bundle conf needs
  `[ipx] ipx=true`.
