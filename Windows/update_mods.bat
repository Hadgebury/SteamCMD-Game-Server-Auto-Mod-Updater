@echo off
setlocal EnableDelayedExpansion

REM --- Set path to mod_updater.env ---
set ENV_FILE=%~dp0mod_updater.env

REM --- Load variables from .env file if it exists ---
if exist "%ENV_FILE%" (
    echo 📄 Loading config from %ENV_FILE%
    for /f "usebackq tokens=1,* delims==" %%A in (`findstr /V "^#" "%ENV_FILE%"`) do (
        set "%%A=%%B"
    )
) else (
    echo ⚠️ Config file not found: %ENV_FILE% – assuming variables are already set manually.
)

REM --- Validate required variables ---
set REQUIRED_VARS=STEAMCMD GAME_ID MODS_DIR MODLIST_FILE HASH_FILE FOLDER_MAP_FILE
for %%V in (%REQUIRED_VARS%) do (
    if not defined %%V (
        echo ❌ Required variable %%V is not set. Aborting.
        exit /b 1
    )
)

REM --- Create required files if missing ---
if not exist "%MODLIST_FILE%" type nul > "%MODLIST_FILE%"
if not exist "%HASH_FILE%" type nul > "%HASH_FILE%"
if not exist "%FOLDER_MAP_FILE%" type nul > "%FOLDER_MAP_FILE%"

REM --- Import hash and folder maps into PowerShell ---
powershell -Command ^
    "$modHashes = @{}; $modFolders = @{}; $currentMods = @{}; " ^
    "if (Test-Path '%HASH_FILE%') { Get-Content '%HASH_FILE%' | ForEach-Object { if ($_ -match '^(.*?)=(.*)$') { $modHashes[$matches[1]] = $matches[2] } } };" ^
    "if (Test-Path '%FOLDER_MAP_FILE%') { Get-Content '%FOLDER_MAP_FILE%' | ForEach-Object { if ($_ -match '^(.*?)=(.*)$') { $modFolders[$matches[1]] = $matches[2] } } };" ^
    "Get-Content '%MODLIST_FILE%' | ForEach-Object { if ($_ -ne '') { $currentMods[$_] = 1 } };" ^

    "Get-Content '%MODLIST_FILE%' | ForEach-Object { $modID = $_; if ($modID -eq '') { return }; Write-Host '🔄 Processing Mod ID:' $modID;" ^
    "& '%STEAMCMD%' +login anonymous +workshop_download_item %GAME_ID% $modID +quit | Out-Null;" ^
    "$workshopPath = Join-Path $env:USERPROFILE 'Steam\\steamapps\\workshop\\content\\%GAME_ID%\\' + $modID;" ^
    "if (!(Test-Path $workshopPath)) { Write-Host '⚠️  Download failed:' $workshopPath; return };" ^
    "$modFolder = Get-ChildItem -Path $workshopPath -Directory | Select-Object -First 1;" ^
    "if (!$modFolder) { Write-Host '⚠️  No folder found in' $workshopPath; Remove-Item -Recurse -Force $workshopPath; return };" ^
    "$hash = Get-ChildItem -Recurse -File $modFolder.FullName | Get-FileHash -Algorithm MD5 | Sort-Object Path | ForEach-Object Hash | Out-String | Get-FileHash -AsByteStream -Algorithm MD5 | Select-Object -ExpandProperty Hash;" ^
    "$oldHash = $modHashes[$modID];" ^
    "$modName = Split-Path $modFolder.FullName -Leaf;" ^
    "$destPath = Join-Path '%MODS_DIR%' $modName;" ^
    "if ($hash -eq $oldHash) { Write-Host '✅ Mod is up to date.'; Remove-Item -Recurse -Force $workshopPath; return };" ^
    "Write-Host '⬆️  New version found for' $modID;" ^
    "$oldFolder = $modFolders[$modID];" ^
    "if ($oldFolder -and (Test-Path (Join-Path '%MODS_DIR%' $oldFolder))) { Write-Host '🗑️  Removing old version:' $oldFolder; Remove-Item -Recurse -Force (Join-Path '%MODS_DIR%' $oldFolder) };" ^
    "if (Test-Path $destPath) { Write-Host '⚠️  Destination exists. Removing:' $destPath; Remove-Item -Recurse -Force $destPath };" ^
    "Move-Item $modFolder.FullName '%MODS_DIR%'; Write-Host '✅ Updated mod moved to' '%MODS_DIR%\'+$modName;" ^
    "$modHashes[$modID] = $hash; $modFolders[$modID] = $modName;" ^
    "Remove-Item -Recurse -Force $workshopPath;" ^
    "} " ^

    "# --- Remove missing mods ---" ^
    "foreach ($modID in $modHashes.Keys) { if (-not $currentMods.ContainsKey($modID)) { Write-Host '❌ Removing unlisted mod:' $modID;" ^
    "$folder = $modFolders[$modID];" ^
    "if ($folder -and (Test-Path (Join-Path '%MODS_DIR%' $folder))) { Remove-Item -Recurse -Force (Join-Path '%MODS_DIR%' $folder) };" ^
    "$modHashes.Remove($modID); $modFolders.Remove($modID) } };" ^

    "# --- Save updated maps ---" ^
    "$modHashes.GetEnumerator() | ForEach-Object { $_.Key + '=' + $_.Value } | Set-Content '%HASH_FILE%';" ^
    "$modFolders.GetEnumerator() | ForEach-Object { $_.Key + '=' + $_.Value } | Set-Content '%FOLDER_MAP_FILE%';" ^
    "Write-Host '✅ Mod update check complete.'"
