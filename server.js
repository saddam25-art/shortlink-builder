const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const fetch = require('node-fetch');
const cheerio = require('cheerio');
const { nanoid } = require('nanoid');

const app = express();
const PORT = process.env.PORT || 3000;

// JSON file database
const DB_FILE = path.join(__dirname, 'shortlinks.json');

// Initialize database
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

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Detect if request is from Facebook/social media crawler
function isCrawler(userAgent) {
  const crawlers = [
    'facebookexternalhit',
    'Facebot',
    'LinkedInBot',
    'Twitterbot',
    'WhatsApp',
    'TelegramBot',
    'Slackbot',
    'Discordbot',
    'Pinterest',
    'Googlebot',
    'bingbot'
  ];
  return crawlers.some(c => userAgent.toLowerCase().includes(c.toLowerCase()));
}

// API: Fetch metadata from URL (for article/content URL)
app.post('/api/fetch-metadata', async (req, res) => {
  try {
    const { url } = req.body;
    
    if (!url) {
      return res.status(400).json({ error: 'URL is required' });
    }

    console.log('Fetching metadata from:', url);

    // Handle Facebook URLs - use Facebook crawler
    let finalUrl = url;
    let response;
    
    if (url.includes('facebook.com/share/p/') || url.includes('facebook.com/story.php')) {
      // Use Facebook crawler for Facebook URLs
      response = await fetch(url, {
        headers: {
          'User-Agent': 'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)',
          'Accept': '*/*'
        },
        timeout: 15000,
        redirect: 'follow'
      });
    } else {
      // Use realistic browser User-Agent for other URLs
      response = await fetch(url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9,ms;q=0.8',
          'Accept-Encoding': 'gzip, deflate, br',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Sec-Ch-Ua': '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
          'Sec-Ch-Ua-Mobile': '?0',
          'Sec-Ch-Ua-Platform': '"Windows"',
          'Sec-Fetch-Dest': 'document',
          'Sec-Fetch-Mode': 'navigate',
          'Sec-Fetch-Site': 'none',
          'Sec-Fetch-User': '?1',
          'Upgrade-Insecure-Requests': '1'
        },
        timeout: 15000,
        redirect: 'follow'
      });
    }

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const html = await response.text();
    const $ = cheerio.load(html);

    // Extract OG meta tags (priority) or fallback
    let title = $('meta[property="og:title"]').attr('content') 
          || $('meta[name="title"]').attr('content')
          || $('title').text()
          || '';
    
    let description = $('meta[property="og:description"]').attr('content')
              || $('meta[name="description"]').attr('content')
              || '';
    
    let image = $('meta[property="og:image"]').attr('content')
          || $('meta[property="og:image:url"]').attr('content')
          || '';
    
    // Handle Facebook-specific content
    if (url.includes('facebook.com')) {
      // Try to extract from structured data
      const jsonData = $('script[type="application/ld+json"]').html();
      if (jsonData) {
        try {
          const parsed = JSON.parse(jsonData);
          if (Array.isArray(parsed)) {
            const article = parsed.find(item => item['@type'] === 'Article' || item['@type'] === 'NewsArticle');
            if (article) {
              title = article.headline || title;
              description = article.description || description;
              image = article.image?.[0] || image;
            }
          }
        } catch (e) {
          console.log('Failed to parse structured data');
        }
      }
      
      // Fallback: try to find first image in content
      if (!image) {
        const firstImage = $('img').first().attr('src');
        if (firstImage && !firstImage.includes('profile')) {
          image = firstImage;
        }
      }
    }
    
    const metadata = {
      title: title || 'No title found',
      description: description || 'No description found',
      image: image || ''
    };

    // Clean up
    metadata.title = metadata.title.trim();
    metadata.description = metadata.description.trim();
    metadata.image = metadata.image.trim();

    // Make image URL absolute if relative
    if (metadata.image && !metadata.image.startsWith('http')) {
      const urlObj = new URL(url);
      metadata.image = metadata.image.startsWith('/') 
        ? `${urlObj.protocol}//${urlObj.host}${metadata.image}`
        : `${urlObj.protocol}//${urlObj.host}/${metadata.image}`;
    }

    console.log('Metadata extracted:', metadata);
    res.json(metadata);

  } catch (error) {
    console.error('Fetch metadata error:', error.message);
    res.status(500).json({ error: 'Failed to fetch metadata: ' + error.message });
  }
});

// API: Create shortlink
app.post('/api/create', (req, res) => {
  try {
    const { title, description, image, sourceUrl, destinationUrl } = req.body;

    if (!destinationUrl) {
      return res.status(400).json({ error: 'Destination URL is required' });
    }

    // Generate unique short code
    const code = nanoid(8);

    // Insert into database
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
      shortUrl: `${req.protocol}://${req.get('host')}/s/${code}`
    });

  } catch (error) {
    console.error('Create shortlink error:', error.message);
    res.status(500).json({ error: 'Failed to create shortlink' });
  }
});

// API: Get all shortlinks
app.get('/api/links', (req, res) => {
  try {
    res.json(db.links.slice(0, 100));
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch links' });
  }
});

// API: Delete shortlink
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

// SHORTLINK REDIRECT - This is the magic!
// When Facebook crawler visits: serve HTML with OG tags
// When user visits: redirect to Shopee (try app first, fallback to web)
app.get('/s/:code', (req, res) => {
  try {
    const { code } = req.params;
    const userAgent = req.get('User-Agent') || '';

    // Get shortlink from database
    const link = db.links.find(l => l.code === code);

    if (!link) {
      return res.status(404).send('Shortlink not found');
    }

    // Update click count
    link.clicks = (link.clicks || 0) + 1;
    saveDB(db);

    const isCrawlerRequest = isCrawler(userAgent);
    console.log(`[${code}] Request from: ${isCrawlerRequest ? 'CRAWLER' : 'USER'} - ${userAgent.substring(0, 50)}`);

    // For crawlers (Facebook, etc): serve HTML with OG meta tags
    // This is how Facebook gets the preview!
    if (isCrawlerRequest) {
      const html = `<!DOCTYPE html>
<html lang="ms">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta property="og:type" content="website">
  <meta property="og:title" content="${escapeHtml(link.title || 'Shopee Product')}">
  <meta property="og:description" content="${escapeHtml(link.description || 'Klik untuk lihat di Shopee')}">
  <meta property="og:image" content="${escapeHtml(link.image || '')}">
  <meta property="og:url" content="${req.protocol}://${req.get('host')}/s/${code}">
  <meta property="fb:app_id" content="222039178820089">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${escapeHtml(link.title || 'Shopee Product')}">
  <meta name="twitter:description" content="${escapeHtml(link.description || 'Klik untuk lihat di Shopee')}">
  <meta name="twitter:image" content="${escapeHtml(link.image || '')}">
  <title>${escapeHtml(link.title || 'Shopee Product')}</title>
</head>
<body>
  <h1>${escapeHtml(link.title || 'Shopee Product')}</h1>
  <p>${escapeHtml(link.description || '')}</p>
  <a href="${escapeHtml(link.destination_url)}">View on Shopee</a>
</body>
</html>`;
      return res.send(html);
    }

    // For real users: serve redirect page that tries to open Shopee app
    // Similar to how Facebook's l.php works with "refresh" header
    const redirectHtml = generateRedirectPage(link);
    res.send(redirectHtml);

  } catch (error) {
    console.error('Shortlink error:', error.message);
    res.status(500).send('Error processing shortlink');
  }
});

// Generate redirect page (like Facebook's l.php)
function generateRedirectPage(link) {
  const finalUrl = link.destination_url;
  const deepLink = `shopee://open?url=${encodeURIComponent(finalUrl)}`;
  
  return `<!DOCTYPE html>
<html lang="ms">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="refresh" content="2;URL=${escapeHtml(finalUrl)}">
  <meta property="og:type" content="website">
  <meta property="og:title" content="${escapeHtml(link.title || 'Shopee Product')}">
  <meta property="og:description" content="${escapeHtml(link.description || 'Klik untuk lihat di Shopee')}">
  <meta property="og:image" content="${escapeHtml(link.image || '')}">
  <title>${escapeHtml(link.title || 'Redirecting...')}</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: linear-gradient(135deg, #fff5f0 0%, #fff 100%);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .card {
      background: #fff;
      border-radius: 20px;
      box-shadow: 0 10px 40px rgba(0,0,0,0.1);
      max-width: 420px;
      width: 100%;
      overflow: hidden;
    }
    .img-container {
      width: 100%;
      height: 220px;
      background: linear-gradient(135deg, #fed7aa 0%, #fdba74 100%);
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .img-container img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
    .content {
      padding: 24px;
    }
    h1 {
      font-size: 18px;
      color: #1e293b;
      margin-bottom: 8px;
      line-height: 1.4;
    }
    p {
      font-size: 14px;
      color: #64748b;
      margin-bottom: 20px;
      line-height: 1.5;
    }
    .loading {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 12px;
      padding: 16px;
      background: #fff7ed;
      border-radius: 12px;
      margin-bottom: 16px;
    }
    .spinner {
      width: 24px;
      height: 24px;
      border: 3px solid #fed7aa;
      border-top-color: #f97316;
      border-radius: 50%;
      animation: spin 1s linear infinite;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    .loading-text {
      color: #ea580c;
      font-size: 14px;
      font-weight: 500;
    }
    .btn {
      display: block;
      width: 100%;
      padding: 16px;
      border: none;
      border-radius: 12px;
      font-size: 15px;
      font-weight: 600;
      cursor: pointer;
      text-align: center;
      text-decoration: none;
      transition: all 0.2s;
    }
    .btn-primary {
      background: linear-gradient(135deg, #f97316 0%, #ea580c 100%);
      color: #fff;
    }
    .btn-primary:hover {
      transform: translateY(-2px);
      box-shadow: 0 4px 12px rgba(249, 115, 22, 0.4);
    }
    .shopee-logo {
      width: 20px;
      height: 20px;
      margin-right: 8px;
      vertical-align: middle;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="img-container">
      ${link.image ? `<img src="${escapeHtml(link.image)}" alt="${escapeHtml(link.title)}" onerror="this.style.display='none'">` : `
      <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="#f97316" stroke-width="1.5">
        <path d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>`}
    </div>
    <div class="content">
      <h1>${escapeHtml(link.title || 'Shopee Product')}</h1>
      <p>${escapeHtml(link.description || 'Klik untuk lihat produk di Shopee')}</p>
      <div class="loading">
        <div class="spinner"></div>
        <span class="loading-text">Membuka Shopee App...</span>
      </div>
      <a href="${escapeHtml(finalUrl)}" class="btn btn-primary" id="openBtn">
        <svg class="shopee-logo" viewBox="0 0 24 24" fill="currentColor">
          <path d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z"/>
        </svg>
        Buka di Shopee
      </a>
    </div>
  </div>

  <script>
    (function() {
      var finalUrl = ${JSON.stringify(finalUrl)};
      var deepLink = ${JSON.stringify(deepLink)};
      var ua = navigator.userAgent || '';
      var isAndroid = /android/i.test(ua);
      var isIOS = /iphone|ipad|ipod/i.test(ua);
      var isFacebookApp = /FBAN|FBAV|FB_IAB/i.test(ua);

      function tryOpenApp() {
        if (isAndroid) {
          // Android Intent URL - works best from Facebook app
          var intentUrl = 'intent://open?url=' + encodeURIComponent(finalUrl) + 
            '#Intent;scheme=shopee;package=com.shopee.my;S.browser_fallback_url=' + 
            encodeURIComponent(finalUrl) + ';end';
          window.location.href = intentUrl;
        } else if (isIOS) {
          // iOS - try universal link first, then deep link
          window.location.href = deepLink;
          setTimeout(function() {
            if (!document.hidden) {
              window.location.href = finalUrl;
            }
          }, 1500);
        } else {
          // Desktop - direct redirect
          window.location.href = finalUrl;
        }
      }

      // Try to open app after short delay
      setTimeout(tryOpenApp, 300);

      // Fallback: if still on page after 3 seconds, redirect to web
      setTimeout(function() {
        if (!document.hidden) {
          window.location.href = finalUrl;
        }
      }, 3000);
    })();
  </script>
</body>
</html>`;
}

// Escape HTML to prevent XSS
function escapeHtml(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

// Serve frontend
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Start server
app.listen(PORT, () => {
  console.log(`\n🚀 Shortlink Builder Server running at http://localhost:${PORT}`);
  console.log(`\n📋 How it works:`);
  console.log(`   1. Open http://localhost:${PORT} in browser`);
  console.log(`   2. Paste article URL (mstar, etc) → Click Fetch to get title/desc/image`);
  console.log(`   3. Paste Shopee affiliate URL as destination`);
  console.log(`   4. Click Generate → Get shortlink`);
  console.log(`   5. Share shortlink on Facebook → Preview shows article content`);
  console.log(`   6. When user clicks → Redirects to Shopee app/web\n`);
});
