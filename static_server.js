const fs = require('fs');
const http = require('http');
const path = require('path');

const root = path.resolve(__dirname, 'frontend', 'build', 'web');
const port = Number(process.env.PORT || 5000);
const types = {
  '.css': 'text/css',
  '.html': 'text/html',
  '.ico': 'image/x-icon',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.wasm': 'application/wasm',
};

http
  .createServer((req, res) => {
    const urlPath = decodeURIComponent((req.url || '/').split('?')[0]);
    const relativePath = urlPath === '/' ? 'index.html' : urlPath.slice(1);
    let filePath = path.resolve(root, relativePath);

    if (
      !filePath.startsWith(root) ||
      !fs.existsSync(filePath) ||
      fs.statSync(filePath).isDirectory()
    ) {
      filePath = path.join(root, 'index.html');
    }

    res.setHeader('Content-Type', types[path.extname(filePath)] || 'application/octet-stream');
    fs.createReadStream(filePath).pipe(res);
  })
  .listen(port, '0.0.0.0', () => {
    console.log(`frontend http://localhost:${port}`);
  });
