@echo off
setlocal enabledelayedexpansion

:: Load .env variables
for /f "usebackq tokens=1,2 delims==" %%A in ("mod_updater.env") do (
    set "%%A=%%B"
)

:: Ensure required files exist
if not exist "%MODLIST_FILE%" type nul > "%MODLIST_FILE%"
if not exist "%HASH_FILE%" type nul > "%HASH_FILE%"
if not exist "%FOLDER_MAP_FILE%" type nul > "%FOLDER_MAP_FILE%"

:: Call PowerShell for the heavy lifting
powershell -NoProfile -ExecutionPolicy Bypass -Command "& {
$env:STEAMCMD = '%STEAMCMD%'
$env:GAME_ID = '%GAME_ID%'
$env:MODS_DIR = '%MODS_DIR%'
$env:MODLIST_FILE = '%MODLIST_FILE%'
$env:HASH_FILE = '%HASH_FILE%'
$env:FOLDER_MAP_FILE = '%FOLDER_MAP_FILE%'

function Get-Hash {
    param($Path)
    Get-ChildItem -Recurse -File -Path $Path |
        Get-FileHash -Algorithm MD5 |
        Sort-Object -Property Path |
        ForEach-Object { $_.Hash } |
        Out-String | Get-FileHash -AsByteStream -Algorithm MD5 |
        Select-Object -ExpandProperty Hash
}

$modHashes = @{}
$folderMap = @{}
$currentMods = @{}

# Load saved hashes
if (Test-Path $env:HASH_FILE) {
    Get-Content $env:HASH_FILE | ForEach-Object {
        if ($_ -match '^(\d+)\s*=\s*(.+)$') {
            $modHashes[$matches[1]] = $matches[2]
        }
    }
}

# Load saved folder map
if (Test-Path $env:FOLDER_MAP_FILE) {
    Get-Content $env:FOLDER_MAP_FILE | ForEach-Object {
        if ($_ -match '^(\d+)\s*=\s*(.+)$') {
            $folderMap[$matches[1]] = $matches[2]
        }
    }
}

# Load mod list
$modList = Get-Content $env:MODLIST_FILE | Where-Object { $_.Trim() -ne '' }
foreach ($modID in $modList) {
    $currentMods[$modID] = $true
}

# Process each mod
foreach ($modID in $modList) {
    Write-Host "🔄 Processing Mod ID: $modID"

    & "$env:STEAMCMD" +login anonymous +workshop_download_item $env:GAME_ID $modID +quit

    $workshopPath = "$HOME\Steam\steamapps\workshop\content\$($env:GAME_ID)\$modID"
    if (-not (Test-Path $workshopPath)) {
        Write-Host "⚠️  Workshop path not found: $workshopPath"
        continue
    }

    $modFolder = Get-ChildItem -Path $workshopPath -Directory | Select-Object -First 1
    if (-not $modFolder) {
        Write-Host "⚠️  No folder found inside $workshopPath"
        Remove-Item -Recurse -Force $workshopPath
        continue
    }

    $modName = $modFolder.Name
    $modPath = $modFolder.FullName
    $destPath = Join-Path $env:MODS_DIR $modName

    $newHash = Get-Hash $modPath
    $oldHash = $modHashes[$modID]

    if ($newHash -eq $oldHash) {
        Write-Host "✅ Mod ID $modID is up to date."
        Remove-Item -Recurse -Force $workshopPath
        continue
    }

    Write-Host "⬆️  Updating Mod ID $modID..."

    # Remove old folder
    if ($folderMap.ContainsKey($modID)) {
        $oldFolder = Join-Path $env:MODS_DIR $folderMap[$modID]
        if (Test-Path $oldFolder) {
            Write-Host "🗑️  Removing old folder: $oldFolder"
            Remove-Item -Recurse -Force $oldFolder
        }
    }

    # Remove existing destination if needed
    if (Test-Path $destPath) {
        Write-Host "⚠️  Destination exists, removing: $destPath"
        Remove-Item -Recurse -Force $destPath
    }

    # Move updated mod
    Move-Item -Path $modPath -Destination $env:MODS_DIR
    Write-Host "✅ Updated mod moved to $env:MODS_DIR\$modName"

    $modHashes[$modID] = $newHash
    $folderMap[$modID] = $modName

    Remove-Item -Recurse -Force $workshopPath
}

# Clean up removed mods
Write-Host "🧹 Checking for removed mods..."
foreach ($modID in $modHashes.Keys) {
    if (-not $currentMods.ContainsKey($modID)) {
        Write-Host "❌ Mod ID $modID is no longer listed."

        if ($folderMap.ContainsKey($modID)) {
            $folderToRemove = Join-Path $env:MODS_DIR $folderMap[$modID]
            if (Test-Path $folderToRemove) {
                Write-Host "🗑️  Removing: $folderToRemove"
                Remove-Item -Recurse -Force $folderToRemove
            }
        }

        $modHashes.Remove($modID)
        $folderMap.Remove($modID)
    }
}

# Write hashes
$modHashes.GetEnumerator() | ForEach-Object {
    "$($_.Key)=$($_.Value)"
} | Set-Content -Path $env:HASH_FILE

# Write folder map
$folderMap.GetEnumerator() | ForEach-Object {
    "$($_.Key)=$($_.Value)"
} | Set-Content -Path $env:FOLDER_MAP_FILE

Write-Host "✅ Mod update check complete."
}"
