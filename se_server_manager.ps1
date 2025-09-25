<#
.SYNOPSIS
A PowerShell script to manage a Space Engineers Dedicated Server.

.DESCRIPTION
This script automates running and maintaining a Space Engineers server:
- Runs update checks with SteamCMD before startup.
- Creates timestamped backups (retains latest 5).
- Monitors server process for crashes/unexpected exits.
- Restarts automatically if a crash is detected.
- Sends rich notifications to a Discord webhook for key events.

.NOTES
Author: Scryptolog1st
Requires: PowerShell 5.1+ (Windows) or PowerShell 7+
Version: 1.4 (stable)
#>

#================================================================================================
# CONFIGURATION (edit these values for your setup)
#================================================================================================

# SteamCMD location
$steamCmdPath     = "C:\SteamCMD\steamcmd.exe"

# Install directory for SE
$serverInstallDir = "C:\SEDS"

# Instance data path (worlds, saves, configs)
$serverInstancePath = "C:\ProgramData\SpaceEngineersDedicated\server1"

# Backup location
$backupPath = "C:\SEDS\Backups"

# Discord webhook URL (must be valid)
$discordWebhookUrl = "https://discord.com/api/webhooks/XXXXXXXXX/XXXXXXXXXXXXXXXXXXXXXXXX"

#================================================================================================
# Discord Notification Function DO NOT EDIT BELOW THIS LINE!!!
#================================================================================================

function Send-DiscordNotification {
    param(
        [string]$Title,
        [string]$Message,
        [int]$Color = 3447003   # Default blue
    )

    if (-not $discordWebhookUrl -or $discordWebhookUrl -eq "YOUR_NEW_DISCORD_WEBHOOK_URL") {
        Write-Warning "Discord webhook not configured."
        return
    }

    # Normalize
    $norm = {
        param($s)
        if ($null -eq $s) { return "" }
        ($s -replace "`r`n", "`n") -replace "`r", "`n"
    }
    $Title   = & $norm $Title
    $Message = & $norm $Message

    # Build embed-only payload
    $embed = @{
        title       = $Title
        description = $Message
        color       = $Color
        timestamp   = (Get-Date).ToUniversalTime().ToString("o")
        footer      = @{ text = "Server Manager" }
    }

    $json = @{ embeds = @($embed) } | ConvertTo-Json -Depth 6 -Compress
    $utf8 = [System.Text.Encoding]::UTF8
    $bodyBytes = $utf8.GetBytes($json)

    try {
        $resp = Invoke-WebRequest -Uri $discordWebhookUrl `
            -Method Post `
            -ContentType 'application/json; charset=utf-8' `
            -Body $bodyBytes `
            -ErrorAction Stop
        Write-Host "Discord OK: $($resp.StatusCode)"
    }
    catch {
        Write-Warning "Discord failed: $($_.Exception.Message)"
    }
}

#================================================================================================
# Backup Function
#================================================================================================

function New-Backup {
    if (-NOT (Test-Path $serverInstancePath)) {
        $msg = "Instance path not found at '$serverInstancePath'."
        Write-Warning $msg
        Send-DiscordNotification "⚠ Backup Skipped" $msg 16753920
        return
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $backupFileName = "SE_Backup_$timestamp.zip"
    $backupFullPath = Join-Path $backupPath $backupFileName

    $msg = "Creating backup of '$serverInstancePath' to '$backupFullPath'..."
    Write-Host $msg
    Send-DiscordNotification "💾 Backup Started" $msg 3447003

    try {
        Compress-Archive -Path "$serverInstancePath\*" -DestinationPath $backupFullPath -Force
        $msg = "Backup complete: $backupFullPath"
        Write-Host $msg -ForegroundColor Green
        Send-DiscordNotification "✅ Backup Successful" $msg 32768

        # Retention policy: keep 5
        $allBackups = Get-ChildItem -Path $backupPath -Filter "*.zip" | Sort-Object CreationTime -Descending
        if ($allBackups.Count -gt 5) {
            $backupsToDelete = $allBackups | Select-Object -Skip 5
            foreach ($file in $backupsToDelete) {
                Remove-Item -Path $file.FullName -Force
            }
            $deleteMsg = "Cleaned up $($backupsToDelete.Count) old backup(s)."
            Send-DiscordNotification "🧹 Backup Cleanup" $deleteMsg 9807270
        }
    }
    catch {
        $err = "Backup failed: $($_.Exception.Message)"
        Write-Error $err
        Send-DiscordNotification "❌ Backup Failed" $err 15158332
    }
}

#================================================================================================
# Update Function
#================================================================================================

function Invoke-UpdateServer {
    $msg = "Checking for updates via SteamCMD..."
    Write-Host $msg
    Send-DiscordNotification "🔄 Update Check" $msg 3447003

    # Always backup before update
    New-Backup

    $steamCmdArgs = "+force_install_dir `"$serverInstallDir`" +login anonymous +app_update 298740 validate +quit"
    Start-Process -FilePath $steamCmdPath -ArgumentList $steamCmdArgs -Wait -NoNewWindow

    $msg = "Update process complete."
    Write-Host $msg -ForegroundColor Green
    Send-DiscordNotification "✅ Update Complete" $msg 32768
}

#================================================================================================
# Admin Check
#================================================================================================

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Run this script as Administrator."
    Read-Host "Press Enter to exit"
    exit
}

#================================================================================================
# Path Checks
#================================================================================================

if (-NOT (Test-Path $steamCmdPath)) { Write-Error "SteamCMD not found at $steamCmdPath"; exit }
if (-NOT (Test-Path $serverInstallDir)) { New-Item -ItemType Directory -Path $serverInstallDir | Out-Null }
if (-NOT (Test-Path $backupPath)) { New-Item -ItemType Directory -Path $backupPath | Out-Null }

#================================================================================================
# Main Execution Loop
#================================================================================================

Invoke-UpdateServer
$serverExePath = Join-Path $serverInstallDir "DedicatedServer64\SpaceEngineersDedicated.exe"

if (-NOT (Test-Path $serverExePath)) {
    $msg = "Server exe not found at '$serverExePath'."
    Write-Error $msg
    Send-DiscordNotification "❌ Critical Error" $msg 15158332
    exit
}

$restartDelaySeconds = 10
$crashCount = 0

while ($true) {
    Write-Host "Starting Space Engineers server..."
    Send-DiscordNotification "🚀 Server Starting" "Launching server at $serverExePath" 32768

    try {
        $proc = Start-Process -FilePath $serverExePath -ArgumentList "-console -path `"$serverInstancePath`"" -PassThru -Wait
        $exitCode = $proc.ExitCode

        if ($exitCode -eq 0) {
            $msg = "Server stopped cleanly. Exit Code: $exitCode"
            Write-Host $msg -ForegroundColor Yellow
            Send-DiscordNotification "🛑 Server Stopped" $msg 16753920
            break
        } else {
            $crashCount++
            $msg = "Crash detected (Exit: $exitCode). Restarting in $restartDelaySeconds sec. Crash #$crashCount"
            Write-Warning $msg
            Send-DiscordNotification "💥 Crash Detected" $msg 15158332
        }
    }
    catch {
        $crashCount++
        $errMsg = "Failed to start server: $($_.Exception.Message)"
        Write-Error $errMsg
        Send-DiscordNotification "❌ Start Failed" $errMsg 15158332
    }

    Start-Sleep -Seconds $restartDelaySeconds
}

Write-Host "Script execution finished." -ForegroundColor Cyan
Read-Host "Press Enter to close"
