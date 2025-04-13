@echo off
setlocal EnableDelayedExpansion

REM --- Load config from .env ---
set ENV_FILE=%~dp0mod_updater.env
if exist "%ENV_FILE%" (
    for /f "usebackq tokens=1,* delims==" %%A in (`findstr /V "^#" "%ENV_FILE%"`) do (
        set "%%A=%%B"
    )
) else (
    echo ⚠️ No .env found. Using environment variables.
)

REM --- Check required variables ---
set REQUIRED_VARS=STEAMCMD GAME_ID MODS_DIR MODLIST_FILE HASH_FILE FOLDER_MAP_FILE
for %%V in (%REQUIRED_VARS%) do (
    if not defined %%V (
        echo ❌ Required variable %%V is not set.
        exit /b 1
    )
)

REM --- Create missing files ---
if not exist "%MODLIST_FILE%" type nul > "%MODLIST_FILE%"
if not exist "%HASH_FILE%" type nul > "%HASH_FILE%"
if not exist "%FOLDER_MAP_FILE%" type nul > "%FOLDER_MAP_FILE%"

powershell -Command ^
"$modHashes=@{}; $modFolders=@{}; $currentMods=@{};" ^
"if (Test-Path '%HASH_FILE%') { Get-Content '%HASH_FILE%' | ForEach-Object { if ($_ -match '^(.*?)=(.*)$') { $modHashes[$matches[1]] = $matches[2] } } };" ^
"if (Test-Path '%FOLDER_MAP_FILE%') { Get-Content '%FOLDER_MAP_FILE%' | ForEach-Object { if ($_ -match '^(.*?)=(.*)$') { $modFolders[$matches[1]] = $matches[2] } } };" ^
"Get-Content '%MODLIST_FILE%' | ForEach-Object { if ($_ -ne '') { $currentMods[$_] = 1 } };" ^
"Get-Content '%MODLIST_FILE%' | ForEach-Object { $modID=$_; if ($modID -eq '') { return }; Write-Host '🔄 Processing' $modID;" ^
"& '%STEAMCMD%' +login anonymous +workshop_download_item %GAME_ID% $modID +quit | Out-Null;" ^
"$path=\"$env:USERPROFILE\\Steam\\steamapps\\workshop\\content\\%GAME_ID%\\$modID\";" ^
"if (!(Test-Path $path)) { Write-Host '⚠️  No workshop folder found.'; return };" ^
"$folder = Get-ChildItem -Path $path -Directory | Select-Object -First 1;" ^
"if (!$folder) { Write-Host '⚠️  No subfolder in workshop mod'; Remove-Item -Recurse -Force $path; return };" ^
"$hash = Get-ChildItem -Recurse -File $folder.FullName | Get-FileHash -Algorithm MD5 | Sort-Object Path | ForEach-Object Hash | Out-String | Get-FileHash -AsByteStream -Algorithm MD5 | Select-Object -ExpandProperty Hash;" ^
"$oldHash = $modHashes[$modID]; $modName = Split-Path $folder.FullName -Leaf;" ^
"$dest = Join-Path '%MODS_DIR%' $modName;" ^
"if ($hash -eq $oldHash) { Write-Host '✅ Up to date'; Remove-Item -Recurse -Force $path; return };" ^
"if ($modFolders[$modID] -and (Test-Path (Join-Path '%MODS_DIR%' $modFolders[$modID]))) { Remove-Item -Recurse -Force (Join-Path '%MODS_DIR%' $modFolders[$modID]) };" ^
"if (Test-Path $dest) { Remove-Item -Recurse -Force $dest };" ^
"Move-Item $folder.FullName '%MODS_DIR%';" ^
"$modHashes[$modID]=$hash; $modFolders[$modID]=$modName;" ^
"Remove-Item -Recurse -Force $path;" ^
"}" ^
"foreach ($id in $modHashes.Keys) { if (-not $currentMods.ContainsKey($id)) { Remove-Item -Recurse -Force (Join-Path '%MODS_DIR%' $modFolders[$id]) -ErrorAction SilentlyContinue; $modHashes.Remove($id); $modFolders.Remove($id) } };" ^
"$modHashes.GetEnumerator() | ForEach-Object { $_.Key + '=' + $_.Value } | Set-Content '%HASH_FILE%';" ^
"$modFolders.GetEnumerator() | ForEach-Object { $_.Key + '=' + $_.Value } | Set-Content '%FOLDER_MAP_FILE%';" ^
"Write-Host '✅ Done updating mods.'"
