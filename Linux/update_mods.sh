#!/bin/bash

# --- Load config from .env if present ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/mod_updater.env"
if [ -f "$ENV_FILE" ]; then
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    echo "⚠️ No .env file found at $ENV_FILE – using preset env vars."
fi

# --- Ensure required variables are set ---
REQUIRED_VARS=(STEAMCMD GAME_ID MODS_DIR MODLIST_FILE HASH_FILE FOLDER_MAP_FILE)
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ $var not set. Check your .env file."
        exit 1
    fi
done

# --- Ensure required files exist ---
touch "$MODLIST_FILE" "$HASH_FILE" "$FOLDER_MAP_FILE"

declare -A MOD_HASHES MOD_FOLDERS CURRENT_MODS

# Load hash + folder map
while IFS='=' read -r id hash; do MOD_HASHES["$id"]="$hash"; done < "$HASH_FILE"
while IFS='=' read -r id folder; do MOD_FOLDERS["$id"]="$folder"; done < "$FOLDER_MAP_FILE"
while IFS= read -r id || [[ -n "$id" ]]; do CURRENT_MODS["$id"]=1; done < "$MODLIST_FILE"

# Process mods
while IFS= read -r MOD_ID || [[ -n "$MOD_ID" ]]; do
    echo "🔄 Mod: $MOD_ID"
    "$STEAMCMD" +login anonymous +workshop_download_item $GAME_ID $MOD_ID +quit

    WORKSHOP_PATH="$HOME/Steam/steamapps/workshop/content/$GAME_ID/$MOD_ID"
    [ ! -d "$WORKSHOP_PATH" ] && echo "⚠️  Download failed: $WORKSHOP_PATH" && continue

    MOD_FOLDER=$(find "$WORKSHOP_PATH" -mindepth 1 -maxdepth 1 -type d | head -n 1)
    [ -z "$MOD_FOLDER" ] && echo "⚠️  No folder in $WORKSHOP_PATH" && rm -rf "$WORKSHOP_PATH" && continue

    NEW_HASH=$(find "$MOD_FOLDER" -type f -exec md5sum {} + | sort -k 2 | md5sum | awk '{print $1}')
    OLD_HASH="${MOD_HASHES[$MOD_ID]}"
    MOD_NAME=$(basename "$MOD_FOLDER")
    DEST_PATH="$MODS_DIR/$MOD_NAME"

    if [ "$NEW_HASH" == "$OLD_HASH" ]; then
        echo "✅ Up to date"
        rm -rf "$WORKSHOP_PATH"
        continue
    fi

    echo "⬆️  Updating mod..."
    [ -d "$MODS_DIR/${MOD_FOLDERS[$MOD_ID]}" ] && rm -rf "$MODS_DIR/${MOD_FOLDERS[$MOD_ID]}"
    [ -d "$DEST_PATH" ] && rm -rf "$DEST_PATH"
    mv "$MOD_FOLDER" "$MODS_DIR/"
    echo "✅ Moved to $MODS_DIR/$MOD_NAME"

    MOD_HASHES["$MOD_ID"]="$NEW_HASH"
    MOD_FOLDERS["$MOD_ID"]="$MOD_NAME"
    rm -rf "$WORKSHOP_PATH"
done < "$MODLIST_FILE"

# Clean removed mods
echo "🧹 Cleaning up..."
for MOD_ID in "${!MOD_HASHES[@]}"; do
    if [ -z "${CURRENT_MODS[$MOD_ID]}" ]; then
        echo "❌ Removing old mod $MOD_ID"
        rm -rf "$MODS_DIR/${MOD_FOLDERS[$MOD_ID]}"
        unset MOD_HASHES["$MOD_ID"]
        unset MOD_FOLDERS["$MOD_ID"]
    fi
done

# Save state
: > "$HASH_FILE"
for id in "${!MOD_HASHES[@]}"; do echo "$id=${MOD_HASHES[$id]}" >> "$HASH_FILE"; done
: > "$FOLDER_MAP_FILE"
for id in "${!MOD_FOLDERS[@]}"; do echo "$id=${MOD_FOLDERS[$id]}" >> "$FOLDER_MAP_FILE"; done

echo "✅ All done."
