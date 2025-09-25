# Space Engineers Server Manager (PowerShell)

A robust **PowerShell automation script** for managing a [Space Engineers Dedicated Server](https://www.spaceengineersgame.com/dedicated-servers/).  
This script keeps your SE server updated, backed up, monitored, and auto-restarted if it crashes. It also integrates with **Discord webhooks** for rich notifications.

---

## ✨ Features
- **Automatic Updates**  
  Uses SteamCMD to check for and apply server updates.
- **Automated Backups**  
  Creates timestamped ZIP backups of your instance folder. Keeps the 5 most recent.
- **Crash Detection & Auto-Restart**  
  Monitors the server process, restarts automatically if it crashes.
- **Discord Notifications**  
  Sends detailed messages to a Discord channel via webhook (embed-only messages).
- **Admin Privilege Check**  
  Ensures script runs elevated (required for SE server operations).

---

## 📋 Requirements
- Windows 10/11 Pro or Windows Server.
- PowerShell **5.1+** (comes with Windows) or **PowerShell 7+** (`pwsh`).
- [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD) installed.
- A valid Discord webhook URL.

---

## ⚙️ Setup

1. **Download/clone this repo**  
   Place `se_server_manager.ps1` somewhere convenient.

2. **Edit configuration**  
   Open the script in VS Code and update the following:
   ```powershell
   $steamCmdPath       = "C:\SteamCMD\steamcmd.exe"
   $serverInstallDir   = "C:\SEDS"
   $serverInstancePath = "C:\ProgramData\SpaceEngineersDedicated\InstanceName"
   $backupPath         = "C:\SEDS\Backups"
   $discordWebhookUrl  = "https://discord.com/api/webhooks/XXXX/XXXX"
   ```

3. **Save as UTF-8 with BOM**  
   In VS Code: *File → Save with Encoding → UTF-8 with BOM*.  
   (Prevents emoji garbling in Discord.)

4. **Run as Administrator**  
   - Right-click → *Run with PowerShell (Admin)*  
   - Or use Task Scheduler to run elevated on startup.

---

## ▶️ Usage

Run the script manually:

```powershell
.\se_server_manager.ps1
```

Or schedule it (recommended):

Open **Task Scheduler** →  
Create Task → Run with highest privileges  

Trigger: **At startup or login**  
Action: Run powershell.exe or pwsh.exe with:

```powershell
-File "C:\Path\se_server_manager.ps1"
```

---

## 🖥️ Discord Notifications
The script sends embed-only messages like:

- 🔄 Update Check  
- 💾 Backup Started  
- ✅ Backup Successful  
- 🧹 Backup Cleanup  
- 🚀 Server Starting  
- 💥 Crash Detected  
- 🛑 Server Stopped  

Each embed includes a title, description, timestamp, and footer (`Server Manager`).

---

## 🔧 Troubleshooting
- **Emoji showing as `ðŸ§¹`** → Save script as **UTF-8 with BOM**.  
- **No Discord messages** → Check webhook URL validity & firewall.  
- **SteamCMD errors** → Ensure `$steamCmdPath` is correct and reachable.  
- **Server not found** → Verify `$serverInstallDir` path and confirm `SpaceEngineersDedicated.exe` exists.

---

## 📜 License
MIT License — free to use, modify, and distribute. Credit appreciated.

---

## 🤝 Contributing
Pull requests are welcome! Open an issue for bugs, suggestions, or feature requests.
