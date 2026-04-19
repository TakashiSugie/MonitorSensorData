/**
 * RepCount Sensor Monitor Server
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

// ─── Uploads Directory ───────────────────────────────────────────
// Cloud Run は /app 配下が読み取り専用のため、書き込み可能な /tmp を使用する
const UPLOADS_DIR = process.env.K_SERVICE
  ? '/tmp/uploads'
  : path.join(__dirname, 'uploads');
if (!fs.existsSync(UPLOADS_DIR)) {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
}

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

  // CSV file upload endpoint (raw text/csv stream)
  if (req.method === 'POST' && req.url === '/api/upload-csv') {
    const contentType = req.headers['content-type'] || '';
    if (!contentType.includes('text/csv')) {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Expected text/csv' }));
      return;
    }

    const xFileName = req.headers['x-file-name'];
    let filename = xFileName ? decodeURIComponent(xFileName) : `upload_${Date.now()}.csv`;
    
    // セキュリティ: ファイル名のサニタイズ
    const safeFilename = path.basename(filename).replace(/[^a-zA-Z0-9_.-]/g, '_');
    const filePath = path.join(UPLOADS_DIR, safeFilename);

    const writeStream = fs.createWriteStream(filePath);

    writeStream.on('finish', () => {
      console.log(`[Upload] Saved CSV stream to: ${safeFilename}`);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: true, filename: safeFilename }));
    });

    writeStream.on('error', (e) => {
      console.error('[Upload] WriteStream Error:', e);
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Failed to write file' }));
    });

    req.pipe(writeStream);
    return;
  }

  // アップロード済みCSVファイル一覧
  if (req.method === 'GET' && req.url === '/api/uploads') {
    fs.readdir(UPLOADS_DIR, (err, files) => {
      if (err) {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ files: [] }));
        return;
      }
      const csvFiles = files
        .filter(f => f.endsWith('.csv'))
        .map(f => {
          const filePath = path.join(UPLOADS_DIR, f);
          const stat = fs.statSync(filePath);
          return { filename: f, size: stat.size, modified: stat.mtime };
        })
        .sort((a, b) => new Date(b.modified) - new Date(a.modified));
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ files: csvFiles }));
    });
    return;
  }

  // アップロード済みCSVファイルのダウンロード
  const csvMatch = req.url.match(/^\/api\/uploads\/([^/?]+\.csv)$/);
  if (req.method === 'GET' && csvMatch) {
    const safeFilename = path.basename(csvMatch[1]).replace(/[^a-zA-Z0-9_.-]/g, '_');
    const filePath = path.join(UPLOADS_DIR, safeFilename);
    fs.readFile(filePath, (err, data) => {
      if (err) {
        res.writeHead(404, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'File not found' }));
        return;
      }
      res.writeHead(200, {
        'Content-Type': 'text/csv',
        'Content-Disposition': `attachment; filename="${safeFilename}"`,
      });
      res.end(data);
    });
    return;
  }

  // Static file serving
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  let pathname = url.pathname;
  let filePath = pathname === '/' ? '/index.html' : pathname;
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
    console.log('║   RepCount Sensor Monitor (Cloud Run)             ║');
    console.log('╠══════════════════════════════════════════════════════╣');
    console.log(`║   Service: ${process.env.K_SERVICE}`);
    console.log(`║   Revision: ${process.env.K_REVISION || 'unknown'}`);
    console.log(`║   Port: ${PORT}`);
    console.log('╚══════════════════════════════════════════════════════╝');
  } else {
    console.log('╔══════════════════════════════════════════════════════╗');
    console.log('║   RepCount Sensor Monitor                        ║');
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
