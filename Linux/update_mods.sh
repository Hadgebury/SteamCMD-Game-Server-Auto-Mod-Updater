#!/bin/bash

# --- Configuration ---
STEAMCMD="${STEAMCMD:-/home/container/steamcmd/steamcmd.sh}"  # Path to steamcmd (can be overridden by environment variable)
GAME_ID="${GAME_ID}"  # Game ID (must be set for the specific game)
MODS_DIR="${MODS_DIR}"  # Directory for mods (must be set)
MODLIST_FILE="${MODLIST_FILE:-/home/container/modlist.txt}"  # List of mod IDs to download
HASH_FILE="${HASH_FILE:-/home/container/modhashes.txt}"  # File to store mod hashes
FOLDER_MAP_FILE="${FOLDER_MAP_FILE:-/home/container/modfolders.txt}"  # File to store mod folder names
MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}"  # Max attempts to download a mod
RETRY_DELAY="${RETRY_DELAY:-5}"  # Delay between retry attempts in seconds

# --- Spinner ---
spin() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\\'
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "      \b\b\b\b\b\b"
}

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

# --- Read modlist into array ---
mapfile -t MOD_IDS < "$MODLIST_FILE"
MOD_IDS=("${MOD_IDS[@]//[$'\r']}")  # Remove carriage returns

# --- Batch download mods ---
download_mods() {
    local -n mods=$1
    local attempt=0
    local remaining=("${mods[@]}")

    while (( attempt++ < MAX_ATTEMPTS )) && (( ${#remaining[@]} > 0 )); do
        echo "⬇️ Downloading ${#remaining[@]} mods (Attempt $attempt/$MAX_ATTEMPTS)..."
        
        # Build SteamCMD command
        cmd=("$STEAMCMD" "+login" "anonymous")
        for mod_id in "${remaining[@]}"; do
            cmd+=("+workshop_download_item" "$GAME_ID" "$mod_id")
        done
        cmd+=("+quit")
        
        # Execute SteamCMD
        "${cmd[@]}" & 
        spin
        wait $!

        # Verify downloaded mods
        local new_remaining=()
        for idx in "${!remaining[@]}"; do
            local mod_id="${remaining[$idx]}"
            WORKSHOP_PATH="/home/container/Steam/steamapps/workshop/content/$GAME_ID/$mod_id"
            if [ -d "$WORKSHOP_PATH" ]; then
                echo "✅ Successfully downloaded: $mod_id"
            else
                new_remaining+=("$mod_id")
                echo "⚠️ Failed to download: $mod_id"
            fi
        done

        remaining=("${new_remaining[@]}")

        # Delay between attempts if needed
        if (( ${#remaining[@]} > 0 && attempt < MAX_ATTEMPTS )); then
            echo "⏳ Retrying in $RETRY_DELAY seconds..."
            sleep $RETRY_DELAY
        fi
    done

    # Report failed downloads
    if (( ${#remaining[@]} > 0 )); then
        echo "❌ Failed to download after $MAX_ATTEMPTS attempts:"
        printf '• %s\n' "${remaining[@]}"
        return 1
    fi
    return 0
}

# --- Perform batch download ---
echo "🚀 Starting batch download of ${#MOD_IDS[@]} mods..."
if ! download_mods MOD_IDS; then
    echo "⚠️ Proceeding with partially downloaded mods"
fi

# --- Process downloaded mods ---
declare -A CURRENT_MODS
while IFS= read -r MOD_ID || [[ -n "$MOD_ID" ]]; do
    CURRENT_MODS["$MOD_ID"]=1
done < "$MODLIST_FILE"

for MOD_ID in "${MOD_IDS[@]}"; do
    echo "🔄 Processing Mod ID: $MOD_ID"
    WORKSHOP_PATH="/home/container/Steam/steamapps/workshop/content/$GAME_ID/$MOD_ID"

    if [ ! -d "$WORKSHOP_PATH" ]; then
        echo "❌ Mod $MOD_ID not downloaded, skipping processing"
        continue
    fi

    # Identify mod folder inside workshop path
    MOD_FOLDER=$(find "$WORKSHOP_PATH" -mindepth 1 -maxdepth 1 -type d | head -n 1)
    if [ -z "$MOD_FOLDER" ]; then
        echo "⚠️ No folder found inside $WORKSHOP_PATH"
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

    echo "⬆️ New version found. Updating $MOD_ID..."

    # Remove old mod version
    OLD_FOLDER="${MOD_FOLDERS[$MOD_ID]}"
    if [ -n "$OLD_FOLDER" ] && [ -d "$MODS_DIR/$OLD_FOLDER" ]; then
        echo "🗑️ Removing old version: $MODS_DIR/$OLD_FOLDER"
        rm -rf "$MODS_DIR/$OLD_FOLDER"
    fi

    # Remove destination if it exists
    if [ -d "$DEST_PATH" ]; then
        echo "⚠️ Destination folder exists: $DEST_PATH – removing to apply update"
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
done

# --- Remove mods no longer in modlist.txt ---
echo "🧹 Checking for removed mods..."
for MOD_ID in "${!MOD_HASHES[@]}"; do
    if [ -z "${CURRENT_MODS[$MOD_ID]}" ]; then
        echo "❌ Mod ID $MOD_ID no longer listed. Removing..."

        FOLDER_NAME="${MOD_FOLDERS[$MOD_ID]}"
        if [ -n "$FOLDER_NAME" ] && [ -d "$MODS_DIR/$FOLDER_NAME" ]; then
            echo "🗑️ Removing folder: $MODS_DIR/$FOLDER_NAME"
            rm -rf "$MODS_DIR/$FOLDER_NAME"
        fi

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
