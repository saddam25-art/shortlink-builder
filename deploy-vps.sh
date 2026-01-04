#!/bin/bash
# Deployment script for Shortlink Builder
# Server: 160.187.210.155 (Linux)

echo "=== Shortlink Builder VPS Deployment ==="

# Update system
apt update && apt upgrade -y

# Install Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# Install PM2 for process management
npm install -g pm2

# Create app directory
mkdir -p /var/www/shortlink-builder
cd /var/www/shortlink-builder

# Create package.json
cat > package.json << 'EOF'
{
  "name": "shortlink-builder",
  "version": "1.0.0",
  "description": "Shortlink Builder - Artikel to Shopee Affiliate",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "cors": "^2.8.5",
    "express": "^4.18.2",
    "node-fetch": "^2.7.0",
    "nanoid": "^3.3.7",
    "cheerio": "^1.0.0-rc.12"
  }
}
EOF

# Install dependencies
npm install

# Create public directory
mkdir -p public

echo "=== Files created. Now upload server.js and public/index.html ==="
echo "=== Or run the full setup script below ==="
