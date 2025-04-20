@echo off
REM --- Configuration ---
set STEAMCMD="C:\Path\To\steamcmd.exe" REM Change Directory to store steamcmd
set GAME_ID=<GAME_ID> REM Replace <GAME_ID> with the Steam App ID for your game
set MODS_DIR="C:\Path\To\Mods" REM Change Directory to store downloaded mods
set MODLIST_FILE="C:\Path\To\modlist.txt" REM Change Directory to store modlist.txt
set HASH_FILE="C:\Path\To\modhashes.txt" REM Change Directory to store modhashes.txt
set FOLDER_MAP_FILE="C:\Path\To\modfolders.txt" REM Change Directory to store modfolders.txt

REM --- Derived Paths ---
set WORKSHOP_BASE="C:\Path\To\Steam\steamapps\workshop\content\%GAME_ID%" REM Change Directory to store steamcmd content

REM --- Ensure required files exist ---
if not exist "%MODLIST_FILE%" type nul > "%MODLIST_FILE%"
if not exist "%HASH_FILE%" type nul > "%HASH_FILE%"
if not exist "%FOLDER_MAP_FILE%" type nul > "%FOLDER_MAP_FILE%"

REM --- Load current hashes and folder mappings ---
for /f "tokens=1,2 delims==" %%a in (%HASH_FILE%) do (
    set "MOD_HASHES[%%a]=%%b"
)

for /f "tokens=1,2 delims==" %%a in (%FOLDER_MAP_FILE%) do (
    set "MOD_FOLDERS[%%a]=%%b"
)

REM --- Read mod list ---
for /f "delims=" %%i in (%MODLIST_FILE%) do (
    set "MOD_IDS[%%i]=1"
)

REM --- Process each mod ---
for %%i in (%MODLIST_FILE%) do (
    echo 🔄 Processing Mod ID: %%i

    REM Execute SteamCMD to download the mod
    "%STEAMCMD%" +login anonymous +workshop_download_item %GAME_ID% %%i +quit

    set WORKSHOP_PATH="%WORKSHOP_BASE%\%%i"
    if not exist "%WORKSHOP_PATH%" (
        echo ⚠️  Workshop download failed or path not found: %WORKSHOP_PATH%
        continue
    )

    REM Get folder name from workshop path
    for /f "delims=" %%a in ('dir /b /ad "%WORKSHOP_PATH%"') do set MOD_FOLDER=%%a

    REM Compute hash of mod folder
    set "NEW_HASH="
    for /f "delims=" %%b in ('dir /b /s /a:-d "%WORKSHOP_PATH%\%MOD_FOLDER%\*" ^| findstr /i .') do (
        certutil -hashfile "%%b" MD5
    ) > NUL

    set "OLD_HASH=%MOD_HASHES[%%i]%"
    set "MOD_NAME=%MOD_FOLDER%"
    set DEST_PATH="%MODS_DIR%\%MOD_NAME%"

    REM If new hash is the same as the old hash, skip update
    if "%NEW_HASH%" == "%OLD_HASH%" (
        echo ✅ Mod ID %%i is up to date. No action taken.
        rmdir /s /q "%WORKSHOP_PATH%"
        continue
    )

    REM Remove old version if it exists
    if defined MOD_FOLDERS[%%i] (
        set OLD_FOLDER=%MOD_FOLDERS[%%i]%
        if exist "%MODS_DIR%\%OLD_FOLDER%" (
            echo 🗑️  Removing old version: %MODS_DIR%\%OLD_FOLDER%
            rmdir /s /q "%MODS_DIR%\%OLD_FOLDER%"
        )
    )

    REM Remove destination if it exists
    if exist "%DEST_PATH%" (
        echo ⚠️  Destination folder exists: %DEST_PATH% – removing to apply update
        rmdir /s /q "%DEST_PATH%"
    )

    REM Move new version
    move /y "%WORKSHOP_PATH%\%MOD_FOLDER%" "%MODS_DIR%\%MOD_NAME%"
    echo ✅ Updated mod moved to %MODS_DIR%\%MOD_NAME%

    REM Update mappings
    set "MOD_HASHES[%%i]=%NEW_HASH%"
    set "MOD_FOLDERS[%%i]=%MOD_NAME%"

    REM Clean up workshop cache
    rmdir /s /q "%WORKSHOP_PATH%"
)

REM --- Cleanup removed mods ---
echo 🧹 Checking for removed mods...
for %%i in (%MOD_HASHES%) do (
    if not defined MOD_IDS[%%i] (
        echo ❌ Mod ID %%i no longer listed. Removing...
        if defined MOD_FOLDERS[%%i] (
            set FOLDER_NAME=%MOD_FOLDERS[%%i]%
            if exist "%MODS_DIR%\%FOLDER_NAME%" (
                echo 🗑️  Removing folder: %MODS_DIR%\%FOLDER_NAME%
                rmdir /s /q "%MODS_DIR%\%FOLDER_NAME%"
            )
        )
        REM Remove hash and folder mapping for removed mod
        set MOD_HASHES[%%i]=
        set MOD_FOLDERS[%%i]=
    )
)

REM --- Save updated hash and folder map ---
echo %MOD_HASHES% > "%HASH_FILE%"
echo %MOD_FOLDERS% > "%FOLDER_MAP_FILE%"

echo ✅ Mod update check complete.
