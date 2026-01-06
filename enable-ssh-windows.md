# Enable SSH on Windows Server for GitHub Deploy

## Method 1: Enable OpenSSH Server (Recommended)

### Step 1: Connect via RDP
```
mstsc /v:160.187.210.155
Username: Administrator
Password: 2K!#thWF0tkSAtN2Y8JFicVn
```

### Step 2: Install OpenSSH Server
1. Buka **PowerShell as Administrator**
2. Run:
```powershell
# Install OpenSSH Server
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Start SSH service
Start-Service sshd

# Set SSH to start automatically
Set-Service -Name sshd -StartupType 'Automatic'

# Configure firewall for SSH
New-NetFirewallRule -DisplayName "Allow SSH" -Direction Inbound -LocalPort 22 -Protocol TCP -Action Allow

# Check SSH status
Get-Service sshd
```

### Step 3: Test SSH
From your PC:
```cmd
ssh Administrator@160.187.210.155
```

---

## Method 2: Use PowerShell Remoting (Alternative)

Update GitHub Actions to use WinRM instead of SSH.

---

## Method 3: Use FTP/SFTP for File Transfer

Install FileZilla Server on Windows and use GitHub Actions to upload files.

---

## After SSH is Enabled

1. Update GitHub secrets:
   - `SERVER_USER`: `Administrator` (not root)
   - `SERVER_PASSWORD`: `2K!#thWF0tkSAtN2Y8JFicVn`
   - `SERVER_HOST`: `160.187.210.155`

2. Push code to trigger deploy:
```cmd
git commit --allow-empty -m "Deploy to Windows Server"
git push origin main
```

---

## Troubleshooting

### SSH Connection Refused
```powershell
# Check if SSH is running
Get-Service sshd

# Restart SSH service
Restart-Service sshd

# Check firewall
Get-NetFirewallRule -DisplayName "Allow SSH"
```

### Permission Denied
- Make sure password is correct
- Try connecting from RDP first to verify credentials

---

## Quick Test Commands

From PowerShell (in RDP):
```powershell
# Test Node.js installation
node --version

# Test npm
npm --version

# Test PM2
pm2 --version

# Check if port 3000 is available
netstat -an | findstr 3000
```
