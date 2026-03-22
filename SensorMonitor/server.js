/**
 * BenchSense Sensor Monitor Server
 * 
 * Apple WatchからHTTP POSTで受信したセンサーデータを
 * WebSocketでブラウザクライアントに中継する。
 * 
 * Usage: node server.js [port]
 * Default port: 8080 (Cloud Run 標準)
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const { WebSocketServer } = require('ws');
const os = require('os');

const PORT = parseInt(process.env.PORT) || parseInt(process.argv[2]) || 8080;
const IS_CLOUD_RUN = !!process.env.K_SERVICE;

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

  // リクエストログ（Cloud Run では Cloud Logging に出力される）
  if (IS_CLOUD_RUN) {
    console.log(JSON.stringify({
      severity: 'INFO',
      message: `${req.method} ${req.url}`,
      httpRequest: { requestMethod: req.method, requestUrl: req.url }
    }));
  }

  // Health check
  if (req.method === 'GET' && req.url === '/api/status') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'ok',
      clients: wss.clients.size,
      environment: IS_CLOUD_RUN ? 'cloud-run' : 'local',
      uptime: Math.floor(process.uptime())
    }));
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

// Cloud Run のアイドルタイムアウト対策: 30秒ごとに ping を送信
const WS_PING_INTERVAL = 30000;

wss.on('connection', (ws) => {
  console.log(`[WS] Client connected (total: ${wss.clients.size})`);

  ws.isAlive = true;
  ws.on('pong', () => { ws.isAlive = true; });

  ws.on('close', () => {
    console.log(`[WS] Client disconnected (total: ${wss.clients.size})`);
  });
});

// 定期的に ping を送信し、応答のないクライアントを切断
const pingInterval = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (ws.isAlive === false) {
      return ws.terminate();
    }
    ws.isAlive = false;
    ws.ping();
  });
}, WS_PING_INTERVAL);

wss.on('close', () => {
  clearInterval(pingInterval);
});

// ─── Graceful Shutdown ───────────────────────────────────────
// Cloud Run は SIGTERM を送信してインスタンスを停止する。
// 接続中のWebSocketクライアントに通知してから終了する。

function gracefulShutdown(signal) {
  console.log(`[Server] ${signal} received. Shutting down gracefully...`);

  // 新しい接続の受付を停止
  server.close(() => {
    console.log('[Server] HTTP server closed.');
  });

  // WebSocket クライアントに通知して切断
  wss.clients.forEach((ws) => {
    ws.close(1001, 'Server shutting down');
  });

  clearInterval(pingInterval);

  // 最大10秒待って強制終了
  setTimeout(() => {
    console.log('[Server] Forcing shutdown.');
    process.exit(0);
  }, 10000);
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// ─── Start ───────────────────────────────────────────────────

server.listen(PORT, '0.0.0.0', () => {
  console.log('');

  if (IS_CLOUD_RUN) {
    console.log('╔══════════════════════════════════════════════════════╗');
    console.log('║   BenchSense Sensor Monitor (Cloud Run)             ║');
    console.log('╠══════════════════════════════════════════════════════╣');
    console.log(`║   Service: ${process.env.K_SERVICE}`);
    console.log(`║   Revision: ${process.env.K_REVISION || 'unknown'}`);
    console.log(`║   Port: ${PORT}`);
    console.log('╚══════════════════════════════════════════════════════╝');
  } else {
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
  }

  console.log('');
});
