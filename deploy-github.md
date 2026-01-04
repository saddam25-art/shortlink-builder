# Deploy Shortlink Builder dengan GitHub

## Langkah 1: Create GitHub Repo

1. Pergi ke https://github.com
2. Click **New repository**
3. Repository name: `shortlink-builder`
4. Public/Private (Public untuk free)
5. Click **Create repository**

## Langkah 2: Push Code ke GitHub

Buka **Command Prompt** di PC anda:

```cmd
cd C:\Users\User\Desktop\ShortlinkBuilder
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/shortlink-builder.git
git push -u origin main
```

## Langkah 3: Setup GitHub Secrets

1. Di GitHub repo, pergi ke **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add 3 secrets:

| Name | Value |
|------|-------|
| `SERVER_HOST` | `160.187.210.155` |
| `SERVER_USER` | `root` |
| `SERVER_PASSWORD` | `2K!#thWF0tkSAtN2Y8JFicVn` |

## Langkah 4: Enable GitHub Actions

1. Pergi ke **Actions** tab
2. Click **I understand my workflows, go ahead and enable them**

## Langkah 5: Deploy!

Push code atau trigger manual:

```cmd
git push origin main
```

Atau:
1. Pergi ke **Actions** tab
2. Click **Deploy to VPS** workflow
3. Click **Run workflow**

## Result

App akan auto-deploy ke:
- **Direct:** http://160.187.210.155:3000
- **Via Nginx:** http://160.187.210.155

## Setup Domain (Optional)

Untuk guna `shortlink.mindpilot.online`:

1. Add A Record: `shortlink → 160.187.210.155`
2. SSH ke server dan run:
   ```bash
   certbot --nginx -d shortlink.mindpilot.online
   ```

---

## Kelebihan GitHub Deploy

✅ **Auto-deploy** - Push code = auto update  
✅ **Version control** - Boleh revert changes  
✅ **CI/CD** - Automated testing & deployment  
✅ **Free** - GitHub Actions free untuk public repo  
✅ **Backup** - Code selamat di GitHub  

---

## Troubleshooting

Jika deploy gagal:
1. Check **Actions** tab untuk error logs
2. Verify secrets betul
3. Ensure server accessible via SSH
4. Check if server has internet access
