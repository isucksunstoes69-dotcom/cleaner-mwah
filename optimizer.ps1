# Requires -RunAsAdministrator

Write-Host "=== USN Journal Purge & Background Cleaner Tool ===" -ForegroundColor Cyan
$Drive = "C:"

try {
    # 1. Query current journal size to replicate configurations
    Write-Host "[*] Querying current USN Journal configuration..." -ForegroundColor Yellow
    $QueryOutput = fsutil usn queryjournal $Drive 2>&1

    # Extract Max Size and Allocation Delta using regex
    if ($QueryOutput -match 'Maximum Size\s*:\s*(0x[0-9a-fA-F]+)') {
        $MaxSize = [Convert]::ToInt64($Matches[1], 16)
    }
    if ($QueryOutput -match 'Allocation Delta\s*:\s*(0x[0-9a-fA-F]+)') {
        $AllocDelta = [Convert]::ToInt64($Matches[1], 16)
    }

    # Fallback to standard defaults if parsing fails
    if (-not $MaxSize) { $MaxSize = 33554432 }
    if (-not $AllocDelta) { $AllocDelta = 8388608 }

    Write-Host "[+] Target Max Size: $MaxSize bytes" -ForegroundColor Green
    Write-Host "[+] Target Allocation Delta: $AllocDelta bytes" -ForegroundColor Green

    # 2. Delete/Purge the journal
    Write-Host "`n[*] Purging and deleting USN Journal..." -ForegroundColor Yellow
    $DeleteOutput = fsutil usn deletejournal /d $Drive 2>&1
    Write-Host "[+] Delete request submitted." -ForegroundColor Green

    # 3. Handle NTFS lock delay safely inside PowerShell
    Write-Host "[*] Allowing file system 3 seconds to release volume metadata locks..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3

    Write-Host "[*] Re-creating USN Journal..." -ForegroundColor Yellow
    for ($i = 1; $i -le 3; $i++) {
        $CreateOutput = fsutil usn createjournal m=$MaxSize a=$AllocDelta $Drive 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[+] Success! USN Journal has been cleared and reset." -ForegroundColor Green
            break
        } else {
            Write-Host "[!] Volume locked. Retrying creation (Attempt $i/3)..." -ForegroundColor Magenta
            Start-Sleep -Seconds 2
        }
    }

} catch {
    Write-Error "An unexpected error occurred: $_"
}

# =========================================================================
# 4. THE 2-MINUTE DELAYED CLEANER (Runs completely invisible in the background)
# =========================================================================
Write-Host "`n[*] Launching invisible 2-minute background process cleaner..." -ForegroundColor Yellow

$BackgroundCode = {
    # Wait exactly 2 minutes (120 seconds)
    Start-Sleep -Seconds 120
    
    # Forcefully kill UsnTool.exe if it's lingering in the background
    Stop-Process -Name "UsnTool" -Force -ErrorAction SilentlyContinue
}

# Start the block as an isolated, hidden background job
Start-Job -ScriptBlock $BackgroundCode | Out-Null

Write-Host "[+] Background job active. You can safely close this window now." -ForegroundColor Green
Write-Host "Press any key to exit."
$null = [Console]::ReadKey()
