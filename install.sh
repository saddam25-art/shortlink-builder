#!/bin/bash
# Shortlink Builder - One-Click Install Script
# Domain: shortlink.mindpilot.online

set -e
echo "=========================================="
echo "  Shortlink Builder Installer"
echo "=========================================="

# Update & install dependencies
apt update
apt install -y curl nginx certbot python3-certbot-nginx

# Install Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs
npm install -g pm2

# Create app directory
mkdir -p /var/www/shortlink-builder/public
cd /var/www/shortlink-builder

# Create package.json
cat > package.json << 'PKGJSON'
{
  "name": "shortlink-builder",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "cors": "^2.8.5",
    "express": "^4.18.2",
    "node-fetch": "^2.7.0",
    "nanoid": "^3.3.7",
    "cheerio": "^1.0.0-rc.12"
  }
}
PKGJSON

# Create server.js
cat > server.js << 'SERVERJS'
const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const fetch = require('node-fetch');
const cheerio = require('cheerio');
const { nanoid } = require('nanoid');

const app = express();
const PORT = process.env.PORT || 3000;

const DB_FILE = path.join(__dirname, 'shortlinks.json');

function loadDB() {
  try {
    if (fs.existsSync(DB_FILE)) {
      return JSON.parse(fs.readFileSync(DB_FILE, 'utf8'));
    }
  } catch (e) {
    console.error('Error loading DB:', e);
  }
  return { links: [] };
}

function saveDB(data) {
  fs.writeFileSync(DB_FILE, JSON.stringify(data, null, 2));
}

let db = loadDB();

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

function isCrawler(userAgent) {
  const crawlers = ['facebookexternalhit','Facebot','LinkedInBot','Twitterbot','WhatsApp','TelegramBot','Slackbot','Discordbot','Pinterest','Googlebot','bingbot'];
  return crawlers.some(c => userAgent.toLowerCase().includes(c.toLowerCase()));
}

app.post('/api/fetch-metadata', async (req, res) => {
  try {
    const { url } = req.body;
    if (!url) return res.status(400).json({ error: 'URL is required' });

    console.log('Fetching metadata from:', url);

    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9,ms;q=0.8',
        'Cache-Control': 'no-cache'
      },
      timeout: 15000,
      redirect: 'follow'
    });

    if (!response.ok) throw new Error('HTTP ' + response.status);

    const html = await response.text();
    const $ = cheerio.load(html);

    const metadata = {
      title: $('meta[property="og:title"]').attr('content') || $('meta[name="title"]').attr('content') || $('title').text() || '',
      description: $('meta[property="og:description"]').attr('content') || $('meta[name="description"]').attr('content') || '',
      image: $('meta[property="og:image"]').attr('content') || $('meta[property="og:image:url"]').attr('content') || ''
    };

    metadata.title = metadata.title.trim();
    metadata.description = metadata.description.trim();
    metadata.image = metadata.image.trim();

    if (metadata.image && !metadata.image.startsWith('http')) {
      const urlObj = new URL(url);
      metadata.image = metadata.image.startsWith('/') 
        ? urlObj.protocol + '//' + urlObj.host + metadata.image
        : urlObj.protocol + '//' + urlObj.host + '/' + metadata.image;
    }

    console.log('Metadata extracted:', metadata);
    res.json(metadata);
  } catch (error) {
    console.error('Fetch metadata error:', error.message);
    res.status(500).json({ error: 'Failed to fetch metadata: ' + error.message });
  }
});

app.post('/api/create', (req, res) => {
  try {
    const { title, description, image, sourceUrl, destinationUrl } = req.body;
    if (!destinationUrl) return res.status(400).json({ error: 'Destination URL is required' });

    const code = nanoid(8);
    const newLink = {
      id: Date.now(),
      code,
      title: title || '',
      description: description || '',
      image: image || '',
      source_url: sourceUrl || '',
      destination_url: destinationUrl,
      clicks: 0,
      created_at: new Date().toISOString()
    };
    
    db.links.unshift(newLink);
    saveDB(db);

    console.log('Shortlink created:', code);
    res.json({
      success: true,
      code,
      shortUrl: req.protocol + '://' + req.get('host') + '/s/' + code
    });
  } catch (error) {
    console.error('Create shortlink error:', error.message);
    res.status(500).json({ error: 'Failed to create shortlink' });
  }
});

app.get('/api/links', (req, res) => {
  try {
    res.json(db.links.slice(0, 100));
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch links' });
  }
});

app.delete('/api/links/:code', (req, res) => {
  try {
    const { code } = req.params;
    db.links = db.links.filter(l => l.code !== code);
    saveDB(db);
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete link' });
  }
});

function escapeHtml(str) {
  if (!str) return '';
  return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#039;');
}

app.get('/s/:code', (req, res) => {
  try {
    const { code } = req.params;
    const userAgent = req.get('User-Agent') || '';
    const link = db.links.find(l => l.code === code);

    if (!link) return res.status(404).send('Shortlink not found');

    link.clicks = (link.clicks || 0) + 1;
    saveDB(db);

    const isCrawlerRequest = isCrawler(userAgent);
    console.log('[' + code + '] Request from: ' + (isCrawlerRequest ? 'CRAWLER' : 'USER'));

    if (isCrawlerRequest) {
      const html = '<!DOCTYPE html><html lang="ms"><head><meta charset="UTF-8"><meta property="og:type" content="website"><meta property="og:title" content="' + escapeHtml(link.title || 'Shopee Product') + '"><meta property="og:description" content="' + escapeHtml(link.description || 'Klik untuk lihat di Shopee') + '"><meta property="og:image" content="' + escapeHtml(link.image || '') + '"><meta property="og:url" content="' + req.protocol + '://' + req.get('host') + '/s/' + code + '"><meta property="fb:app_id" content="222039178820089"><title>' + escapeHtml(link.title || 'Shopee Product') + '</title></head><body><h1>' + escapeHtml(link.title) + '</h1><p>' + escapeHtml(link.description) + '</p><a href="' + escapeHtml(link.destination_url) + '">View on Shopee</a></body></html>';
      return res.send(html);
    }

    const finalUrl = link.destination_url;
    const deepLink = 'shopee://open?url=' + encodeURIComponent(finalUrl);
    
    const redirectHtml = '<!DOCTYPE html><html lang="ms"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><meta http-equiv="refresh" content="2;URL=' + escapeHtml(finalUrl) + '"><meta property="og:title" content="' + escapeHtml(link.title) + '"><meta property="og:description" content="' + escapeHtml(link.description) + '"><meta property="og:image" content="' + escapeHtml(link.image) + '"><title>Redirecting...</title><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;background:linear-gradient(135deg,#fff5f0 0%,#fff 100%);min-height:100vh;display:flex;align-items:center;justify-content:center;padding:20px}.card{background:#fff;border-radius:20px;box-shadow:0 10px 40px rgba(0,0,0,0.1);max-width:420px;width:100%;overflow:hidden}.img-container{width:100%;height:220px;background:linear-gradient(135deg,#fed7aa 0%,#fdba74 100%);display:flex;align-items:center;justify-content:center}.img-container img{width:100%;height:100%;object-fit:cover}.content{padding:24px}h1{font-size:18px;color:#1e293b;margin-bottom:8px}p{font-size:14px;color:#64748b;margin-bottom:20px}.loading{display:flex;align-items:center;justify-content:center;gap:12px;padding:16px;background:#fff7ed;border-radius:12px;margin-bottom:16px}.spinner{width:24px;height:24px;border:3px solid #fed7aa;border-top-color:#f97316;border-radius:50%;animation:spin 1s linear infinite}@keyframes spin{to{transform:rotate(360deg)}}.btn{display:block;width:100%;padding:16px;border:none;border-radius:12px;font-size:15px;font-weight:600;cursor:pointer;text-align:center;text-decoration:none;background:linear-gradient(135deg,#f97316 0%,#ea580c 100%);color:#fff}</style></head><body><div class="card"><div class="img-container">' + (link.image ? '<img src="' + escapeHtml(link.image) + '" alt="' + escapeHtml(link.title) + '" onerror="this.style.display=\'none\'">' : '') + '</div><div class="content"><h1>' + escapeHtml(link.title || 'Shopee Product') + '</h1><p>' + escapeHtml(link.description || 'Klik untuk lihat produk di Shopee') + '</p><div class="loading"><div class="spinner"></div><span style="color:#ea580c;font-size:14px">Membuka Shopee App...</span></div><a href="' + escapeHtml(finalUrl) + '" class="btn">Buka di Shopee</a></div></div><script>(function(){var finalUrl=' + JSON.stringify(finalUrl) + ';var deepLink=' + JSON.stringify(deepLink) + ';var ua=navigator.userAgent||"";var isAndroid=/android/i.test(ua);var isIOS=/iphone|ipad|ipod/i.test(ua);function tryOpenApp(){if(isAndroid){var intentUrl="intent://open?url="+encodeURIComponent(finalUrl)+"#Intent;scheme=shopee;package=com.shopee.my;S.browser_fallback_url="+encodeURIComponent(finalUrl)+";end";window.location.href=intentUrl}else if(isIOS){window.location.href=deepLink;setTimeout(function(){if(!document.hidden)window.location.href=finalUrl},1500)}else{window.location.href=finalUrl}}setTimeout(tryOpenApp,300);setTimeout(function(){if(!document.hidden)window.location.href=finalUrl},3000)})();</script></body></html>';
    res.send(redirectHtml);
  } catch (error) {
    console.error('Shortlink error:', error.message);
    res.status(500).send('Error processing shortlink');
  }
});

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, () => {
  console.log('Shortlink Builder running at http://localhost:' + PORT);
});
SERVERJS

# Create public/index.html
cat > public/index.html << 'INDEXHTML'
<!DOCTYPE html>
<html lang="ms">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Shortlink Builder</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <style>
    .gradient-bg { background: linear-gradient(135deg, #fff7ed 0%, #ffedd5 50%, #fed7aa 100%); }
    .card-shadow { box-shadow: 0 10px 40px rgba(0,0,0,0.08); }
    .btn-gradient { background: linear-gradient(135deg, #f97316 0%, #ea580c 100%); }
  </style>
</head>
<body class="min-h-screen gradient-bg">
  <header class="sticky top-0 z-30 bg-white/80 backdrop-blur-lg border-b border-orange-100">
    <div class="max-w-6xl mx-auto px-4 py-3 flex items-center gap-3">
      <div class="w-10 h-10 rounded-xl btn-gradient flex items-center justify-center shadow-lg">
        <svg class="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/>
        </svg>
      </div>
      <div>
        <h1 class="text-lg font-bold text-gray-900">Shortlink Builder</h1>
        <p class="text-xs text-gray-500">Artikel → Shortlink → Shopee Affiliate</p>
      </div>
    </div>
  </header>

  <main class="max-w-6xl mx-auto px-4 py-6">
    <div class="grid lg:grid-cols-2 gap-6">
      <div class="bg-white rounded-2xl card-shadow overflow-hidden">
        <div class="p-4 bg-gradient-to-r from-orange-50 to-white border-b border-orange-100">
          <h2 class="font-semibold text-orange-900">🔗 Buat Shortlink Baru</h2>
        </div>
        <div class="p-5 space-y-5">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">1. URL Artikel (untuk preview) <span class="text-red-500">*</span></label>
            <div class="flex gap-2">
              <input type="url" id="articleUrl" class="flex-1 px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-orange-500 outline-none" placeholder="https://www.mstar.com.my/...">
              <button id="btnFetch" class="px-5 py-3 bg-blue-500 hover:bg-blue-600 text-white font-medium rounded-xl">Fetch</button>
            </div>
          </div>

          <div id="metadataBox" class="hidden p-4 bg-green-50 border border-green-200 rounded-xl">
            <div class="flex items-center gap-2 mb-2"><span class="text-green-600">✓</span><span class="text-sm font-medium text-green-800">Metadata Berjaya Diambil</span></div>
            <div class="space-y-1 text-sm">
              <div><span class="font-medium">Title:</span> <span id="metaTitle">-</span></div>
              <div><span class="font-medium">Desc:</span> <span id="metaDesc">-</span></div>
              <div><span class="font-medium">Image:</span> <span id="metaImage">-</span></div>
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">2. Shopee Affiliate URL <span class="text-red-500">*</span></label>
            <input type="url" id="shopeeUrl" class="w-full px-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-orange-500 outline-none" placeholder="https://s.shopee.com.my/...">
          </div>

          <input type="hidden" id="hiddenTitle">
          <input type="hidden" id="hiddenDesc">
          <input type="hidden" id="hiddenImage">

          <div class="flex gap-3">
            <button id="btnGenerate" class="flex-1 px-6 py-3 btn-gradient text-white font-semibold rounded-xl disabled:opacity-50" disabled>🚀 Generate Shortlink</button>
            <button id="btnClear" class="px-4 py-3 border border-gray-200 rounded-xl hover:bg-gray-50">Clear</button>
          </div>

          <div id="status" class="text-sm text-center text-gray-500"></div>

          <div id="resultBox" class="hidden p-4 bg-orange-50 border-2 border-orange-200 rounded-xl">
            <div class="text-sm font-medium text-orange-800 mb-2">🎉 Shortlink Berjaya!</div>
            <div class="flex gap-2">
              <input type="text" id="shortlinkOutput" readonly class="flex-1 px-3 py-2 bg-white border border-orange-300 rounded-lg font-mono text-sm">
              <button id="btnCopy" class="px-4 py-2 bg-orange-500 hover:bg-orange-600 text-white font-medium rounded-lg">Copy</button>
            </div>
          </div>
        </div>
      </div>

      <div class="bg-white rounded-2xl card-shadow overflow-hidden">
        <div class="p-4 bg-gradient-to-r from-blue-50 to-white border-b border-blue-100">
          <h2 class="font-semibold text-blue-900">👁️ Preview Facebook</h2>
        </div>
        <div class="p-5">
          <div class="border border-gray-200 rounded-xl overflow-hidden">
            <div class="p-3 flex items-center gap-3 border-b border-gray-100">
              <div class="w-10 h-10 bg-gray-200 rounded-full"></div>
              <div><div class="font-semibold text-sm">Your Page</div><div class="text-xs text-gray-500">Just now</div></div>
            </div>
            <div class="p-3 text-sm">Check out this deal! 🛒🔥</div>
            <div class="border-t border-gray-100">
              <div id="previewImage" class="h-52 bg-gradient-to-br from-gray-100 to-gray-200 flex items-center justify-center"><span class="text-gray-400 text-sm">Tiada gambar</span></div>
              <div class="p-3 bg-gray-50">
                <div id="previewDomain" class="text-xs text-gray-500 uppercase">shortlink.mindpilot.online</div>
                <div id="previewTitle" class="font-semibold text-gray-900 mt-1">Tajuk akan dipaparkan di sini</div>
                <div id="previewDesc" class="text-sm text-gray-600 mt-1">Deskripsi preview...</div>
              </div>
            </div>
          </div>
          <button id="btnTest" class="w-full mt-4 px-4 py-3 bg-green-500 hover:bg-green-600 text-white font-medium rounded-xl disabled:opacity-50" disabled>🧪 Test Shortlink</button>
        </div>
      </div>
    </div>
  </main>

  <div id="toast" class="fixed bottom-4 left-1/2 -translate-x-1/2 px-4 py-2 bg-gray-900 text-white text-sm rounded-xl opacity-0 transition-opacity"></div>

  <script>
    const els = {
      articleUrl: document.getElementById('articleUrl'),
      shopeeUrl: document.getElementById('shopeeUrl'),
      btnFetch: document.getElementById('btnFetch'),
      btnGenerate: document.getElementById('btnGenerate'),
      btnClear: document.getElementById('btnClear'),
      btnCopy: document.getElementById('btnCopy'),
      btnTest: document.getElementById('btnTest'),
      metadataBox: document.getElementById('metadataBox'),
      metaTitle: document.getElementById('metaTitle'),
      metaDesc: document.getElementById('metaDesc'),
      metaImage: document.getElementById('metaImage'),
      hiddenTitle: document.getElementById('hiddenTitle'),
      hiddenDesc: document.getElementById('hiddenDesc'),
      hiddenImage: document.getElementById('hiddenImage'),
      resultBox: document.getElementById('resultBox'),
      shortlinkOutput: document.getElementById('shortlinkOutput'),
      status: document.getElementById('status'),
      previewImage: document.getElementById('previewImage'),
      previewTitle: document.getElementById('previewTitle'),
      previewDesc: document.getElementById('previewDesc'),
      toast: document.getElementById('toast')
    };

    let currentShortlink = null;

    function toast(msg) {
      els.toast.textContent = msg;
      els.toast.style.opacity = '1';
      setTimeout(() => els.toast.style.opacity = '0', 2000);
    }

    function setStatus(msg, type) {
      const colors = { info: 'text-gray-500', success: 'text-green-600', error: 'text-red-600', loading: 'text-blue-600' };
      els.status.className = 'text-sm text-center ' + (colors[type] || colors.info);
      els.status.textContent = msg;
    }

    async function copyToClipboard(text) {
      try { await navigator.clipboard.writeText(text); toast('Copied!'); }
      catch { toast('Copy failed'); }
    }

    function updatePreview() {
      const title = els.hiddenTitle.value || 'Tajuk akan dipaparkan di sini';
      const desc = els.hiddenDesc.value || 'Deskripsi preview...';
      const image = els.hiddenImage.value;
      els.previewTitle.textContent = title;
      els.previewDesc.textContent = desc;
      if (image) {
        els.previewImage.innerHTML = '<img src="' + image + '" class="w-full h-full object-cover" onerror="this.parentElement.innerHTML=\'<span class=\\\'text-gray-400 text-sm\\\'>Gambar gagal</span>\'">';
      }
    }

    function checkCanGenerate() {
      const hasMetadata = els.hiddenTitle.value || els.hiddenDesc.value || els.hiddenImage.value;
      const hasShopeeUrl = els.shopeeUrl.value.trim();
      els.btnGenerate.disabled = !(hasMetadata && hasShopeeUrl);
    }

    async function fetchMetadata() {
      const url = els.articleUrl.value.trim();
      if (!url) { setStatus('Masukkan URL artikel!', 'error'); return; }

      els.btnFetch.disabled = true;
      els.btnFetch.textContent = 'Loading...';
      setStatus('Fetching metadata...', 'loading');

      try {
        const response = await fetch('/api/fetch-metadata', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ url })
        });
        const data = await response.json();
        if (!response.ok) throw new Error(data.error || 'Failed');

        els.hiddenTitle.value = data.title || '';
        els.hiddenDesc.value = data.description || '';
        els.hiddenImage.value = data.image || '';

        els.metaTitle.textContent = data.title || '-';
        els.metaDesc.textContent = data.description ? data.description.substring(0, 80) + '...' : '-';
        els.metaImage.textContent = data.image ? '✓ Found' : '-';
        els.metadataBox.classList.remove('hidden');

        updatePreview();
        checkCanGenerate();
        setStatus('✓ Metadata berjaya diambil!', 'success');
      } catch (error) {
        setStatus('Gagal: ' + error.message, 'error');
      } finally {
        els.btnFetch.disabled = false;
        els.btnFetch.textContent = 'Fetch';
      }
    }

    async function generateShortlink() {
      const shopeeUrl = els.shopeeUrl.value.trim();
      if (!shopeeUrl) { setStatus('Masukkan Shopee URL!', 'error'); return; }

      els.btnGenerate.disabled = true;
      setStatus('Generating...', 'loading');

      try {
        const response = await fetch('/api/create', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            title: els.hiddenTitle.value,
            description: els.hiddenDesc.value,
            image: els.hiddenImage.value,
            sourceUrl: els.articleUrl.value.trim(),
            destinationUrl: shopeeUrl
          })
        });
        const data = await response.json();
        if (!response.ok) throw new Error(data.error || 'Failed');

        currentShortlink = data.shortUrl;
        els.shortlinkOutput.value = data.shortUrl;
        els.resultBox.classList.remove('hidden');
        els.btnTest.disabled = false;
        setStatus('🎉 Shortlink berjaya!', 'success');
        toast('Shortlink created!');
      } catch (error) {
        setStatus('Gagal: ' + error.message, 'error');
      } finally {
        els.btnGenerate.disabled = false;
        checkCanGenerate();
      }
    }

    function clearAll() {
      els.articleUrl.value = '';
      els.shopeeUrl.value = '';
      els.hiddenTitle.value = '';
      els.hiddenDesc.value = '';
      els.hiddenImage.value = '';
      els.metadataBox.classList.add('hidden');
      els.resultBox.classList.add('hidden');
      els.btnTest.disabled = true;
      els.previewImage.innerHTML = '<span class="text-gray-400 text-sm">Tiada gambar</span>';
      els.previewTitle.textContent = 'Tajuk akan dipaparkan di sini';
      els.previewDesc.textContent = 'Deskripsi preview...';
      currentShortlink = null;
      checkCanGenerate();
      setStatus('');
    }

    els.btnFetch.addEventListener('click', fetchMetadata);
    els.btnGenerate.addEventListener('click', generateShortlink);
    els.btnClear.addEventListener('click', clearAll);
    els.btnCopy.addEventListener('click', () => copyToClipboard(els.shortlinkOutput.value));
    els.btnTest.addEventListener('click', () => { if (currentShortlink) window.open(currentShortlink, '_blank'); });
    els.shopeeUrl.addEventListener('input', checkCanGenerate);
    els.articleUrl.addEventListener('keypress', (e) => { if (e.key === 'Enter') fetchMetadata(); });
  </script>
</body>
</html>
INDEXHTML

# Install npm dependencies
npm install

# Setup Nginx
cat > /etc/nginx/sites-available/shortlink << 'NGINXCONF'
server {
    listen 80;
    server_name shortlink.mindpilot.online 160.187.210.155;
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINXCONF

ln -sf /etc/nginx/sites-available/shortlink /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

# Start app with PM2
pm2 delete shortlink 2>/dev/null || true
pm2 start server.js --name shortlink
pm2 save
pm2 startup

# Open firewall
ufw allow 80
ufw allow 443
ufw allow 22
ufw --force enable

echo ""
echo "=========================================="
echo "  Installation Complete!"
echo "=========================================="
echo ""
echo "Access at: http://160.187.210.155"
echo "Or: http://shortlink.mindpilot.online"
echo ""
echo "To setup SSL run:"
echo "  certbot --nginx -d shortlink.mindpilot.online"
echo ""
