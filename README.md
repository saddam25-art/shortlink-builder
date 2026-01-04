# Shortlink Builder

Standalone app untuk buat shortlink dengan preview dari artikel dan redirect ke Shopee affiliate.

## Features
- Fetch metadata dari URL artikel (title, description, image)
- Generate shortlink dengan custom preview
- Auto-redirect ke Shopee app/web
- Facebook crawler support (OG meta tags)

## Deploy

### GitHub Actions (Auto-deploy)
1. Fork repo ini
2. Add secrets di GitHub repo:
   - `SERVER_HOST`: IP server
   - `SERVER_USER`: root
   - `SERVER_PASSWORD`: password SSH
3. Push code → auto-deploy

### Manual Deploy
```bash
# Clone repo
git clone <repo-url>
cd shortlink-builder

# Install
npm install

# Start
npm start
```

## Usage
1. Buka http://localhost:3000
2. Paste URL artikel → Fetch metadata
3. Paste Shopee affiliate URL
4. Generate shortlink
5. Share di Facebook

## API Endpoints
- `POST /api/fetch-metadata` - Fetch metadata dari URL
- `POST /api/create` - Create shortlink
- `GET /api/links` - Get all shortlinks
- `DELETE /api/links/:code` - Delete shortlink
- `GET /s/:code` - Redirect endpoint

## Tech Stack
- Node.js + Express
- Cheerio (HTML parsing)
- SQLite (JSON file storage)
- PM2 (process manager)
