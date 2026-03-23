# OpenClaw Backup Script
# Backs up configuration files and data to external directory

$SourceDir = "D:\Chunny\Projects\AI\openclaw"
$BackupDir = "D:\Chunny\Projects\AI\openclaw_backup"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$CurrentBackupDir = Join-Path $BackupDir $Timestamp

# Files and directories to backup
$ItemsToBackup = @(
    ".env.chunny_1",
    ".env.chunny_2",
    ".env.chunny_3",
    ".gitignore",
    ".dockerignore",
    "Dockerfile",
    "docker-compose.yml",
    "requirements.txt",
    "supervisord.conf",
    "data"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  OpenClaw Backup Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Create backup directory
Write-Host "Creating backup directory: $CurrentBackupDir" -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $CurrentBackupDir | Out-Null

# Backup each item
$SuccessCount = 0
$FailCount = 0

foreach ($Item in $ItemsToBackup) {
    $SourcePath = Join-Path $SourceDir $Item

    if (Test-Path $SourcePath) {
        try {
            Write-Host "Backing up: $Item" -ForegroundColor Green

            if ((Get-Item $SourcePath) -is [System.IO.DirectoryInfo]) {
                # Copy directory recursively
                Copy-Item -Path $SourcePath -Destination (Join-Path $CurrentBackupDir $Item) -Recurse -Force
            } else {
                # Copy file
                Copy-Item -Path $SourcePath -Destination (Join-Path $CurrentBackupDir $Item) -Force
            }
            $SuccessCount++
        } catch {
            Write-Host "  ERROR: Failed to backup $Item - $_" -ForegroundColor Red
            $FailCount++
        }
    } else {
        Write-Host "SKIPPED: $Item (not found)" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Backup Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Location: $CurrentBackupDir" -ForegroundColor Yellow
Write-Host "Success: $SuccessCount items" -ForegroundColor Green
if ($FailCount -gt 0) {
    Write-Host "Failed: $FailCount items" -ForegroundColor Red
}
