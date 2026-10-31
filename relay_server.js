// Standalone Zero-Dependency WebSocket Relay Server for "The Company Does Not Let You Leave"
// Runs natively on Node.js (v18+) without requiring any npm install!
// Also compatible with cloud hosting (Glitch, Render, Railway, Fly.io, Heroku, VPS).

const http = require('http');
const crypto = require('crypto');

const PORT = parseInt(process.env.PORT || '8912', 10);
const WS_GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

// Active Rooms: roomCode -> { code, name, hostPeerId, clients: Map<peerId, Client>, day, variant, createdAt }
const rooms = new Map();
let nextClientId = 1000;

class WSConnection {
  constructor(socket) {
    this.socket = socket;
    this.buffer = Buffer.alloc(0);
    this.isAlive = true;
    this.peerId = 0;
    this.roomCode = null;
    this.playerName = 'Janitor';

    socket.on('data', (chunk) => this.onData(chunk));
    socket.on('error', (err) => {
      // Ignore normal disconnect reset errors
    });
    socket.on('close', () => this.onClose());
  }

  send(data) {
    if (this.socket.destroyed) return;
    const isBuffer = Buffer.isBuffer(data);
    const payload = isBuffer ? data : Buffer.from(typeof data === 'string' ? data : JSON.stringify(data), 'utf8');
    const opcode = isBuffer ? 0x02 : 0x01; // 0x01 text, 0x02 binary
    const len = payload.length;

    let header;
    if (len <= 125) {
      header = Buffer.alloc(2);
      header[0] = 0x80 | opcode;
      header[1] = len;
    } else if (len <= 65535) {
      header = Buffer.alloc(4);
      header[0] = 0x80 | opcode;
      header[1] = 126;
      header.writeUInt16BE(len, 2);
    } else {
      header = Buffer.alloc(10);
      header[0] = 0x80 | opcode;
      header[1] = 127;
      header.writeBigUInt64BE(BigInt(len), 2);
    }

    try {
      this.socket.write(Buffer.concat([header, payload]));
    } catch (e) {}
  }

  sendJSON(obj) {
    this.send(JSON.stringify(obj));
  }

  onData(chunk) {
    this.buffer = Buffer.concat([this.buffer, chunk]);
    while (this.buffer.length >= 2) {
      const firstByte = this.buffer[0];
      const secondByte = this.buffer[1];
      const fin = (firstByte & 0x80) === 0x80;
      const opcode = firstByte & 0x0f;
      const masked = (secondByte & 0x80) === 0x80;
      let payloadLen = secondByte & 0x7f;
      let offset = 2;

      if (payloadLen === 126) {
        if (this.buffer.length < offset + 2) break;
        payloadLen = this.buffer.readUInt16BE(offset);
        offset += 2;
      } else if (payloadLen === 127) {
        if (this.buffer.length < offset + 8) break;
        payloadLen = Number(this.buffer.readBigUInt64BE(offset));
        offset += 8;
      }

      let maskKey = null;
      if (masked) {
        if (this.buffer.length < offset + 4) break;
        maskKey = this.buffer.subarray(offset, offset + 4);
        offset += 4;
      }

      if (this.buffer.length < offset + payloadLen) break;

      const payload = this.buffer.subarray(offset, offset + payloadLen);
      this.buffer = this.buffer.subarray(offset + payloadLen);

      if (masked && maskKey) {
        for (let i = 0; i < payload.length; i++) {
          payload[i] ^= maskKey[i % 4];
        }
      }

      if (opcode === 0x08) {
        // Close frame
        this.socket.end();
        return;
      } else if (opcode === 0x09) {
        // Ping -> reply Pong
        const pong = Buffer.alloc(2);
        pong[0] = 0x8a;
        pong[1] = 0;
        this.socket.write(pong);
      } else if (opcode === 0x01 || opcode === 0x02) {
        this.handleMessage(opcode === 0x01 ? payload.toString('utf8') : payload);
      }
    }
  }

  handleMessage(msg) {
    let packet;
    if (typeof msg === 'string') {
      try {
        packet = JSON.parse(msg);
      } catch (e) {
        return;
      }
    } else {
      // Binary payload: relay directly to room
      if (this.roomCode && rooms.has(this.roomCode)) {
        const room = rooms.get(this.roomCode);
        for (const [pid, client] of room.clients) {
          if (pid !== this.peerId) {
            client.send(msg);
          }
        }
      }
      return;
    }

    const type = packet.type || packet.cmd;

    switch (type) {
      case 'ping':
        this.sendJSON({ type: 'pong' });
        break;

      case 'list_rooms':
        const roomList = [];
        const now = Date.now();
        for (const [code, r] of rooms.entries()) {
          roomList.push({
            code: r.code,
            name: r.name,
            host_name: r.hostName,
            players: r.clients.size,
            max_players: r.maxPlayers,
            day: r.day,
            variant: r.variant
          });
        }
        this.sendJSON({ type: 'room_list', rooms: roomList });
        break;

      case 'create_room': {
        const roomName = (packet.room_name || 'Facility Shift').trim().substring(0, 32);
        this.playerName = (packet.player_name || 'Janitor #1').trim().substring(0, 24);
        const maxP = Math.min(Math.max(parseInt(packet.max_players || '4', 10), 2), 6);
        const day = parseInt(packet.day || '1', 10);
        const variant = parseInt(packet.variant || '0', 10);

        // Generate clean 6-char Room Code: AGY-XXXX
        let code = '';
        const chars = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
        for (let attempt = 0; attempt < 100; attempt++) {
          let suffix = '';
          for (let i = 0; i < 4; i++) {
            suffix += chars[Math.floor(Math.random() * chars.length)];
          }
          code = 'AGY-' + suffix;
          if (!rooms.has(code)) break;
        }

        this.peerId = 1; // 1 is always Host
        this.roomCode = code;

        const room = {
          code: code,
          name: roomName,
          hostName: this.playerName,
          hostPeerId: 1,
          clients: new Map(),
          maxPlayers: maxP,
          day: day,
          variant: variant,
          createdAt: Date.now()
        };
        room.clients.set(1, this);
        rooms.set(code, room);

        console.log(`[ROOM CREATED] Code: ${code} | Name: "${roomName}" | Host: "${this.playerName}"`);

        this.sendJSON({
          type: 'room_created',
          room_code: code,
          peer_id: 1,
          name: roomName,
          players: [{ id: 1, name: this.playerName, is_host: true, ready: true }]
        });
        break;
      }

      case 'join_room': {
        const inputCode = (packet.room_code || '').trim().toUpperCase();
        this.playerName = (packet.player_name || 'Janitor #' + Math.floor(Math.random() * 90 + 10)).trim().substring(0, 24);

        if (!rooms.has(inputCode)) {
          this.sendJSON({ type: 'join_error', message: 'Mã phòng không tồn tại hoặc đã đóng!' });
          return;
        }

        const room = rooms.get(inputCode);
        if (room.clients.size >= room.maxPlayers) {
          this.sendJSON({ type: 'join_error', message: 'Phòng đã đầy người chơi!' });
          return;
        }

        // Find available peerId (2..maxPlayers)
        let newPeerId = 2;
        while (room.clients.has(newPeerId)) {
          newPeerId++;
        }

        this.peerId = newPeerId;
        this.roomCode = inputCode;
        room.clients.set(newPeerId, this);

        console.log(`[PEER JOINED] Room ${inputCode}: Peer ${newPeerId} ("${this.playerName}")`);

        // Build player list
        const playerList = [];
        for (const [pid, cl] of room.clients.entries()) {
          playerList.push({
            id: pid,
            name: cl.playerName,
            is_host: pid === 1,
            ready: pid === 1
          });
        }

        // Notify joined client
        this.sendJSON({
          type: 'joined_room',
          room_code: inputCode,
          peer_id: newPeerId,
          room_name: room.name,
          host_id: 1,
          day: room.day,
          variant: room.variant,
          players: playerList
        });

        // Broadcast to other peers in room
        const peerJoinedEvt = {
          type: 'peer_joined',
          peer_id: newPeerId,
          player_name: this.playerName
        };
        for (const [pid, cl] of room.clients.entries()) {
          if (pid !== newPeerId) {
            cl.sendJSON(peerJoinedEvt);
          }
        }
        break;
      }

      case 'relay': {
        // Forward game packet to peers
        if (!this.roomCode || !rooms.has(this.roomCode)) return;
        const room = rooms.get(this.roomCode);
        const target = packet.target || 'all'; // 'all', 'others', or peer_id number
        const payload = packet.data;
        const outMsg = {
          type: 'relay',
          from: this.peerId,
          data: payload
        };

        if (target === 'all') {
          for (const [pid, cl] of room.clients.entries()) {
            cl.sendJSON(outMsg);
          }
        } else if (target === 'others' || !target) {
          for (const [pid, cl] of room.clients.entries()) {
            if (pid !== this.peerId) {
              cl.sendJSON(outMsg);
            }
          }
        } else if (typeof target === 'number') {
          const targetClient = room.clients.get(target);
          if (targetClient) {
            targetClient.sendJSON(outMsg);
          }
        }
        break;
      }

      case 'leave_room':
        this.leaveCurrentRoom();
        break;
    }
  }

  leaveCurrentRoom() {
    if (!this.roomCode || !rooms.has(this.roomCode)) return;
    const room = rooms.get(this.roomCode);
    room.clients.delete(this.peerId);
    console.log(`[PEER LEFT] Room ${this.roomCode}: Peer ${this.peerId} ("${this.playerName}")`);

    if (this.peerId === 1 || room.clients.size === 0) {
      // Host left or empty room: notify remaining and delete room
      for (const [pid, cl] of room.clients.entries()) {
        cl.sendJSON({ type: 'host_left', message: 'Chủ phòng đã thoát. Phòng giải tán.' });
        cl.roomCode = null;
        cl.peerId = 0;
      }
      rooms.delete(this.roomCode);
      console.log(`[ROOM CLOSED] Room ${this.roomCode} disbanded.`);
    } else {
      // Regular client left: notify remaining
      const leftEvt = { type: 'peer_left', peer_id: this.peerId, player_name: this.playerName };
      for (const [pid, cl] of room.clients.entries()) {
        cl.sendJSON(leftEvt);
      }
    }

    this.roomCode = null;
    this.peerId = 0;
  }

  onClose() {
    this.leaveCurrentRoom();
  }
}

// HTTP Server handling status endpoint and WebSocket upgrade
const server = http.createServer((req, res) => {
  if (req.url === '/health' || req.url === '/status') {
    res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
    res.end(JSON.stringify({
      status: 'online',
      active_rooms: rooms.size,
      version: '1.0.0',
      service: 'The Company Does Not Let You Leave - Cloud Relay'
    }));
    return;
  }

  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(`<!DOCTYPE html>
<html>
<head>
  <title>Aethelgard Relay Server</title>
  <style>
    body { background: #0c0e12; color: #38ef7d; font-family: monospace; padding: 2rem; }
    h1 { color: #11998e; }
    .badge { background: #1a222d; padding: 8px 14px; border-radius: 4px; display: inline-block; color: #fff; }
  </style>
</head>
<body>
  <h1>🏢 The Company Does Not Let You Leave</h1>
  <h2>WebSocket Cloud Relay Server — ONLINE</h2>
  <p class="badge">Active Rooms: <b>${rooms.size}</b> | Port: <b>${PORT}</b></p>
  <p>Status: Ready for cross-network Co-Op multiplayer shifts.</p>
</body>
</html>`);
});

server.on('upgrade', (req, socket, head) => {
  const key = req.headers['sec-websocket-key'];
  if (!key) {
    socket.destroy();
    return;
  }

  const hash = crypto.createHash('sha1').update(key + WS_GUID).digest('base64');
  const responseHeaders = [
    'HTTP/1.1 101 Switching Protocols',
    'Upgrade: websocket',
    'Connection: Upgrade',
    `Sec-WebSocket-Accept: ${hash}`,
    '\r\n'
  ];

  socket.write(responseHeaders.join('\r\n'));
  const conn = new WSConnection(socket);
});

// Periodic room cleanup for inactive/stale rooms (>6 hours)
setInterval(() => {
  const now = Date.now();
  for (const [code, r] of rooms.entries()) {
    if (r.clients.size === 0 || now - r.createdAt > 6 * 3600 * 1000) {
      rooms.delete(code);
    }
  }
}, 60000);

server.listen(PORT, '0.0.0.0', () => {
  console.log(`================================================================`);
  console.log(`🚀 RELAY SERVER IS RUNNING ON PORT ${PORT}`);
  console.log(`   Local URL: ws://127.0.0.1:${PORT}`);
  console.log(`   Health Check: http://127.0.0.1:${PORT}/status`);
  console.log(`   Cross-network: Deploy to Glitch / Render / Railway for 24/7 free hosting`);
  console.log(`================================================================`);
});
