# Deploy Shortlink Builder ke Azure

## Langkah 1: Create Azure Account

1. Pergi ke https://azure.microsoft.com
2. Click **"Start free"**
3. Login dengan Microsoft account
4. Dapat $200 credit + 12 months free services

## Langkah 2: Create App Service

### Via Azure Portal
1. **Portal Home** → **+ Create a resource**
2. Search: **"App Service"**
3. Click **Create**
4. **Basics tab:**
   - **Subscription:** Free Trial
   - **Resource Group:** Create new → `shortlink-rg`
   - **Name:** `shortlink-builder`
   - **Publish:** Code
   - **Runtime stack:** Node.js 20 LTS
   - **Operating system:** Linux
   - **Region:** East Asia (Singapore)
   - **Pricing plan:** F1 (Free)
5. Click **Next: Deployment**

### Setup GitHub Deployment
1. **Continuous Deployment:** On
2. **GitHub:** Connect
3. **Authorize** Azure
4. **Organization:** saddam25-art
5. **Repository:** shortlink-builder
6. **Branch:** main
7. Click **Next: Monitoring**
8. Click **Next: Tags**
9. Click **Review + create**
10. Click **Create**

## Langkah 3: Configure App Service

### 1. Environment Variables
Di App Service → **Configuration** → **Application settings**:
```
WEBSITE_NODE_DEFAULT_VERSION = 20
WEBSITE_RUN_FROM_PACKAGE = 1
```

### 2. Custom Domain
1. App Service → **Custom domains**
2. Add: `shortlink.mindpilot.online`
3. Setup DNS A record:
   - Type: A
   - Name: shortlink
   - Value: Azure IP address

### 3. SSL Certificate
1. App Service → **TLS/SSL settings**
2. Add free SSL certificate
3. Enable HTTPS only

## Langkah 4: Test Deployment

App akan auto-deploy setiap push ke GitHub:
- **URL:** https://shortlink-builder.azurewebsites.net
- **Custom:** https://shortlink.mindpilot.online

## Alternative: Azure CLI Commands

```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login
az login

# Create resource group
az group create --name shortlink-rg --location "East Asia"

# Create app service plan
az appservice plan create --name shortlink-free --resource-group shortlink-rg --sku FREE --is-linux

# Create web app
az webapp create --resource-group shortlink-rg --plan shortlink-free --name shortlink-builder --runtime "NODE|20-lts"

# Configure GitHub deployment
az webapp deployment source config --repo-url https://github.com/saddam25-art/shortlink-builder --branch main --manual-integration --resource-group shortlink-rg --name shortlink-builder
```

## Benefits Azure vs VPS

| Azure | VPS |
|-------|-----|
| ✅ Auto-scaling | ❌ Manual scaling |
| ✅ Auto-backup | ❌ Manual backup |
| ✅ SSL included | ❌ Manual SSL |
| ✅ 99.9% uptime | ❌ Self-managed |
| ✅ Global CDN | ❌ Single location |
| ❌ Limited free tier | ✅ Full control |
| ❌ Pay-per-use | ✅ Fixed cost |

## Cost Estimate

- **Free Tier (F1):** RM0/bulan
- **Basic (B1):** RM50/bulan (1GB RAM, 60GB storage)
- **Standard (S1):** RM200/bulan (2GB RAM, 250GB storage)

Free tier cukup untuk development dan low traffic.
