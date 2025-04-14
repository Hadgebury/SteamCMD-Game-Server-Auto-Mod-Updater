# --- Configuration ---
$STEAMCMD = "C:\Path\To\steamcmd.exe" # Change Directory to store steamcmd
$GAME_ID = "<GAME_ID>" # Replace <GAME_ID> with the Steam App ID for your game
$MODS_DIR = "C:\Path\To\Mods" # Change Directory to store downloaded mods
$MODLIST_FILE = "C:\Path\To\modlist.txt" # Change Directory to store modlist.txt
$HASH_FILE = "C:\Path\To\modhashes.txt" # Change Directory to store modhashes.txt
$FOLDER_MAP_FILE = "C:\Path\To\modfolders.txt" # Change Directory to store modfolders.txt
$WORKSHOP_BASE = "C:\Path\To\Steam\steamapps\workshop\content\$GAME_ID" # Change Directory to store steamcmd content

# --- Ensure required files exist ---
foreach ($file in @($MODLIST_FILE, $HASH_FILE, $FOLDER_MAP_FILE)) {
    if (!(Test-Path $file)) { New-Item -Path $file -ItemType File | Out-Null }
}

# --- Load current hashes and folder mappings ---
$MOD_HASHES = @{}
if (Test-Path $HASH_FILE) {
    Get-Content $HASH_FILE | ForEach-Object {
        $parts = $_ -split '=', 2
        if ($parts.Length -eq 2) { $MOD_HASHES[$parts[0]] = $parts[1] }
    }
}

$MOD_FOLDERS = @{}
if (Test-Path $FOLDER_MAP_FILE) {
    Get-Content $FOLDER_MAP_FILE | ForEach-Object {
        $parts = $_ -split '=', 2
        if ($parts.Length -eq 2) { $MOD_FOLDERS[$parts[0]] = $parts[1] }
    }
}

# --- Read mod list ---
$CURRENT_MODS = @{}
$MOD_IDS = Get-Content $MODLIST_FILE | Where-Object { $_.Trim() -ne "" }
foreach ($id in $MOD_IDS) { $CURRENT_MODS[$id] = $true }

# --- Process each mod ---
foreach ($MOD_ID in $MOD_IDS) {
    Write-Host "🔄 Processing Mod ID: $MOD_ID"

    Start-Process -FilePath $STEAMCMD -ArgumentList "+login anonymous +workshop_download_item $GAME_ID $MOD_ID +quit" -NoNewWindow -Wait

    $WORKSHOP_PATH = Join-Path $WORKSHOP_BASE $MOD_ID
    if (!(Test-Path $WORKSHOP_PATH)) {
        Write-Host "⚠️  Workshop download failed or path not found: $WORKSHOP_PATH"
        continue
    }

    $MOD_FOLDER = Get-ChildItem $WORKSHOP_PATH -Directory | Select-Object -First 1
    if (-not $MOD_FOLDER) {
        Write-Host "⚠️  No folder found inside $WORKSHOP_PATH"
        Remove-Item $WORKSHOP_PATH -Recurse -Force
        continue
    }

    $FILES = Get-ChildItem $MOD_FOLDER.FullName -Recurse -File
    $hashInput = $FILES | Sort-Object FullName | ForEach-Object {
        Get-FileHash -Path $_.FullName -Algorithm MD5 | Select-Object -ExpandProperty Hash
    } | Out-String
    $NEW_HASH = [System.BitConverter]::ToString((New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hashInput.Trim()))).Replace("-", "").ToLower()

    $OLD_HASH = $MOD_HASHES[$MOD_ID]
    $MOD_NAME = $MOD_FOLDER.Name
    $DEST_PATH = Join-Path $MODS_DIR $MOD_NAME

    if ($NEW_HASH -eq $OLD_HASH) {
        Write-Host "✅ Mod ID $MOD_ID is up to date. No action taken."
        Remove-Item $WORKSHOP_PATH -Recurse -Force
        continue
    }

    Write-Host "⬆️  New version found. Updating $MOD_ID..."

    # Remove old version
    if ($MOD_FOLDERS.ContainsKey($MOD_ID)) {
        $OLD_FOLDER = $MOD_FOLDERS[$MOD_ID]
        $OLD_PATH = Join-Path $MODS_DIR $OLD_FOLDER
        if (Test-Path $OLD_PATH) {
            Write-Host "🗑️  Removing old version: $OLD_PATH"
            Remove-Item $OLD_PATH -Recurse -Force
        }
    }

    # Remove existing destination folder
    if (Test-Path $DEST_PATH) {
        Write-Host "⚠️  Destination folder exists: $DEST_PATH – removing to apply update"
        Remove-Item $DEST_PATH -Recurse -Force
    }

    # Move new version
    Move-Item $MOD_FOLDER.FullName $DEST_PATH
    Write-Host "✅ Updated mod moved to $DEST_PATH"

    # Update mappings
    $MOD_HASHES[$MOD_ID] = $NEW_HASH
    $MOD_FOLDERS[$MOD_ID] = $MOD_NAME

    # Clean up workshop cache
    Remove-Item $WORKSHOP_PATH -Recurse -Force
}

# --- Cleanup removed mods ---
Write-Host "🧹 Checking for removed mods..."
foreach ($MOD_ID in @($MOD_HASHES.Keys)) {
    if (-not $CURRENT_MODS.ContainsKey($MOD_ID)) {
        Write-Host "❌ Mod ID $MOD_ID no longer listed. Removing..."
        if ($MOD_FOLDERS.ContainsKey($MOD_ID)) {
            $FOLDER_NAME = $MOD_FOLDERS[$MOD_ID]
            $MOD_PATH = Join-Path $MODS_DIR $FOLDER_NAME
            if (Test-Path $MOD_PATH) {
                Write-Host "🗑️  Removing folder: $MOD_PATH"
                Remove-Item $MOD_PATH -Recurse -Force
            }
        }
        $MOD_HASHES.Remove($MOD_ID)
        $MOD_FOLDERS.Remove($MOD_ID)
    }
}

# --- Save updated hash and folder map ---
Set-Content $HASH_FILE ($MOD_HASHES.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" })
Set-Content $FOLDER_MAP_FILE ($MOD_FOLDERS.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" })

Write-Host "✅ Mod update check complete."
