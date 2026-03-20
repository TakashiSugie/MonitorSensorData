/**
 * BenchSense Sensor Monitor Server
 * 
 * Apple WatchからHTTP POSTで受信したセンサーデータを
 * WebSocketでブラウザクライアントに中継する。
 * 
 * Usage: node server.js [port]
 * Default port: 8765
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const { WebSocketServer } = require('ws');
const os = require('os');

const PORT = parseInt(process.argv[2]) || 8765;

// ─── HTTP Server ─────────────────────────────────────────────

const server = http.createServer((req, res) => {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Health check
  if (req.method === 'GET' && req.url === '/api/status') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', clients: wss.clients.size }));
    return;
  }

  // Sensor data endpoint
  if (req.method === 'POST' && req.url === '/api/sensor-data') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const data = JSON.parse(body);
        // Broadcast to all WebSocket clients
        const message = JSON.stringify(data);
        wss.clients.forEach(client => {
          if (client.readyState === 1) { // OPEN
            client.send(message);
          }
        });
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ received: true }));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Invalid JSON' }));
      }
    });
    return;
  }

  // Static file serving
  let filePath = req.url === '/' ? '/index.html' : req.url;
  filePath = path.join(__dirname, filePath);

  const extMap = {
    '.html': 'text/html',
    '.css': 'text/css',
    '.js': 'application/javascript',
    '.json': 'application/json',
    '.png': 'image/png',
    '.svg': 'image/svg+xml',
  };
  const ext = path.extname(filePath);
  const contentType = extMap[ext] || 'text/plain';

  fs.readFile(filePath, (err, content) => {
    if (err) {
      res.writeHead(404);
      res.end('Not Found');
      return;
    }
    res.writeHead(200, { 'Content-Type': contentType });
    res.end(content);
  });
});

// ─── WebSocket Server ────────────────────────────────────────

const wss = new WebSocketServer({ server });

wss.on('connection', (ws) => {
  console.log(`[WS] Client connected (total: ${wss.clients.size})`);
  ws.on('close', () => {
    console.log(`[WS] Client disconnected (total: ${wss.clients.size})`);
  });
});

// ─── Start ───────────────────────────────────────────────────

server.listen(PORT, '0.0.0.0', () => {
  console.log('');
  console.log('╔══════════════════════════════════════════════════════╗');
  console.log('║   BenchSense Sensor Monitor                        ║');
  console.log('╠══════════════════════════════════════════════════════╣');
  console.log(`║   Dashboard: http://localhost:${PORT}                 ║`);
  console.log('║                                                      ║');
  console.log('║   Network IPs (use one of these in Watch app):       ║');

  const interfaces = os.networkInterfaces();
  for (const [name, addrs] of Object.entries(interfaces)) {
    for (const addr of addrs) {
      if (addr.family === 'IPv4' && !addr.internal) {
        const line = `║     ${name}: http://${addr.address}:${PORT}`;
        console.log(line + ' '.repeat(Math.max(0, 55 - line.length)) + '║');
      }
    }
  }

  console.log('║                                                      ║');
  console.log('║   Waiting for Watch data...                          ║');
  console.log('╚══════════════════════════════════════════════════════╝');
  console.log('');
});
