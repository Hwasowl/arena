// Test server: serves the bundled preview and saves POSTed canvas captures (data URLs) as JPEG files.
const http = require('http'), fs = require('fs'), path = require('path');
const dir = __dirname, html = path.join(__dirname, '..', 'Gojo-preview.html');
fs.mkdirSync(path.join(dir, 'shots'), { recursive: true });
http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (req.method === 'POST' && url.pathname === '/shot') {
    let body = '';
    req.on('data', c => body += c);
    req.on('end', () => {
      const name = (url.searchParams.get('name') || 'shot').replace(/[^a-z0-9_-]/gi, '');
      fs.writeFileSync(path.join(dir, 'shots', name + '.jpg'), Buffer.from(body.split(',')[1] || '', 'base64'));
      res.end('ok');
    });
    return;
  }
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(fs.readFileSync(html));
}).listen(4599, '127.0.0.1');
