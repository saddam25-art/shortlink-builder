# Deploy Shortlink Builder ke VPS

## Server Info
- **IP:** 160.187.210.155
- **Hostname:** ip-160-187-210-155.my-advin.com
- **User:** root

---

## Langkah 1: SSH ke Server

```bash
ssh root@160.187.210.155
```

---

## Langkah 2: Install Node.js & Dependencies

```bash
# Update system
apt update && apt upgrade -y

# Install Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

# Verify installation
node -v
npm -v

# Install PM2 (process manager)
npm install -g pm2
```

---

## Langkah 3: Setup App Directory

```bash
# Create directory
mkdir -p /var/www/shortlink-builder/public
cd /var/www/shortlink-builder
```

---

## Langkah 4: Upload Files dari PC anda

Buka **new terminal** di PC anda dan run:

```powershell
# Upload semua files ke server
scp -r c:\Users\User\Desktop\ShortlinkBuilder\* root@160.187.210.155:/var/www/shortlink-builder/
```

Atau manual upload files ini:
- `server.js`
- `package.json`
- `public/index.html`

---

## Langkah 5: Install & Start App

```bash
cd /var/www/shortlink-builder

# Install dependencies
npm install

# Start with PM2
pm2 start server.js --name shortlink-builder

# Auto-start on reboot
pm2 startup
pm2 save

# Check status
pm2 status
pm2 logs shortlink-builder
```

---

## Langkah 6: Setup Nginx (Optional - untuk domain)

```bash
# Install Nginx
apt install -y nginx

# Create config
nano /etc/nginx/sites-available/shortlink

# Paste this:
server {
    listen 80;
    server_name 160.187.210.155 ip-160-187-210-155.my-advin.com;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}

# Enable site
ln -s /etc/nginx/sites-available/shortlink /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx
```

---

## Langkah 7: Open Firewall

```bash
# Allow HTTP
ufw allow 80
ufw allow 443
ufw allow 3000
```

---

## Access App

Selepas deploy, akses di:
- **Direct:** http://160.187.210.155:3000
- **Via Nginx:** http://160.187.210.155
- **Hostname:** http://ip-160-187-210-155.my-advin.com

---

## Troubleshooting

```bash
# Check if app running
pm2 status

# View logs
pm2 logs shortlink-builder

# Restart app
pm2 restart shortlink-builder

# Check port
netstat -tlnp | grep 3000
```
