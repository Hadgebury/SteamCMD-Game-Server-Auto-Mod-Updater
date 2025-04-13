#!/bin/bash

# --- Configuration ---
STEAMCMD="/home/container/steamcmd/steamcmd.sh"
GAME_ID="<GAME_ID>"  # Replace <GAME_ID> with the Steam App ID for your game
MODS_DIR="/home/container/Mods"  # Directory to store downloaded mods
MODLIST_FILE="/home/container/modlist.txt"
HASH_FILE="/home/container/modhashes.txt"
FOLDER_MAP_FILE="/home/container/modfolders.txt"

# --- Ensure required files exist ---
touch "$MODLIST_FILE"
touch "$HASH_FILE"
touch "$FOLDER_MAP_FILE"

# --- Load current hash and folder maps ---
declare -A MOD_HASHES
declare -A MOD_FOLDERS

while IFS='=' read -r id hash; do
    MOD_HASHES["$id"]="$hash"
done < "$HASH_FILE"

while IFS='=' read -r id folder; do
    MOD_FOLDERS["$id"]="$folder"
done < "$FOLDER_MAP_FILE"

# --- Build list of current mods ---
declare -A CURRENT_MODS
while IFS= read -r MOD_ID || [[ -n "$MOD_ID" ]]; do
    CURRENT_MODS["$MOD_ID"]=1
done < "$MODLIST_FILE"

# --- Process each mod ---
while IFS= read -r MOD_ID || [[ -n "$MOD_ID" ]]; do
    echo "🔄 Processing Mod ID: $MOD_ID"

    # Download via SteamCMD
    $STEAMCMD +login anonymous +workshop_download_item $GAME_ID $MOD_ID +quit

    WORKSHOP_PATH="/home/container/Steam/steamapps/workshop/content/$GAME_ID/$MOD_ID"
    if [ ! -d "$WORKSHOP_PATH" ]; then
        echo "⚠️  Workshop download failed or path not found: $WORKSHOP_PATH"
        continue
    fi

    # Identify mod folder inside workshop path
    MOD_FOLDER=$(find "$WORKSHOP_PATH" -mindepth 1 -maxdepth 1 -type d | head -n 1)
    if [ -z "$MOD_FOLDER" ]; then
        echo "⚠️  No folder found inside $WORKSHOP_PATH"
        rm -rf "$WORKSHOP_PATH"
        continue
    fi

    # Compute hash of mod folder
    NEW_HASH=$(find "$MOD_FOLDER" -type f -exec md5sum {} + | sort -k 2 | md5sum | awk '{print $1}')
    OLD_HASH="${MOD_HASHES[$MOD_ID]}"

    MOD_NAME=$(basename "$MOD_FOLDER")
    DEST_PATH="$MODS_DIR/$MOD_NAME"

    if [ "$NEW_HASH" == "$OLD_HASH" ]; then
        echo "✅ Mod ID $MOD_ID is up to date. No action taken."
        rm -rf "$WORKSHOP_PATH"
        continue
    fi

    echo "⬆️  New version found. Updating $MOD_ID..."

    # Remove old mod version (if known and folder exists)
    OLD_FOLDER="${MOD_FOLDERS[$MOD_ID]}"
    if [ -n "$OLD_FOLDER" ] && [ -d "$MODS_DIR/$OLD_FOLDER" ]; then
        echo "🗑️  Removing old version: $MODS_DIR/$OLD_FOLDER"
        rm -rf "$MODS_DIR/$OLD_FOLDER"
    fi

    # Remove destination if it already exists before moving
    if [ -d "$DEST_PATH" ]; then
        echo "⚠️  Destination folder exists: $DEST_PATH – removing to apply update"
        rm -rf "$DEST_PATH"
    fi

    # Move new version
    mv "$MOD_FOLDER" "$MODS_DIR/"
    echo "✅ Updated mod moved to $MODS_DIR/$MOD_NAME"

    # Update hash and folder maps
    MOD_HASHES["$MOD_ID"]="$NEW_HASH"
    MOD_FOLDERS["$MOD_ID"]="$MOD_NAME"

    # Cleanup workshop cache
    rm -rf "$WORKSHOP_PATH"

done < "$MODLIST_FILE"

# --- Remove mods no longer in modlist.txt ---
echo "🧹 Checking for removed mods..."

for MOD_ID in "${!MOD_HASHES[@]}"; do
    if [ -z "${CURRENT_MODS[$MOD_ID]}" ]; then
        echo "❌ Mod ID $MOD_ID no longer listed. Removing..."

        # Remove mod folder
        FOLDER_NAME="${MOD_FOLDERS[$MOD_ID]}"
        if [ -n "$FOLDER_NAME" ] && [ -d "$MODS_DIR/$FOLDER_NAME" ]; then
            echo "🗑️  Removing folder: $MODS_DIR/$FOLDER_NAME"
            rm -rf "$MODS_DIR/$FOLDER_NAME"
        fi

        # Unset from hash and folder maps
        unset MOD_HASHES["$MOD_ID"]
        unset MOD_FOLDERS["$MOD_ID"]
    fi
done

# --- Write updated hash and folder files ---
: > "$HASH_FILE"
for MOD_ID in "${!MOD_HASHES[@]}"; do
    echo "$MOD_ID=${MOD_HASHES[$MOD_ID]}" >> "$HASH_FILE"
done

: > "$FOLDER_MAP_FILE"
for MOD_ID in "${!MOD_FOLDERS[@]}"; do
    echo "$MOD_ID=${MOD_FOLDERS[$MOD_ID]}" >> "$FOLDER_MAP_FILE"
done

echo "✅ Mod update check complete."
