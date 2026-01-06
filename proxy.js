const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();

// Add CORS headers
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  
  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }
  next();
});

// Proxy middleware
const proxy = createProxyMiddleware({
  target: 'http://localhost:3000',
  changeOrigin: true,
  onError: (err, req, res) => {
    console.error('Proxy error:', err);
    res.status(502).send('Bad Gateway');
  }
});

app.use('/', proxy);

const PORT = 80;
app.listen(PORT, () => {
  console.log(`Reverse proxy running on port ${PORT}`);
});
