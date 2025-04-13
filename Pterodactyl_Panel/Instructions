# STEAMCMD Mod Updater on Pterodactyl Panel (Linux)

The STEAMCMD Mod Updater script allows you to automatically update mods from the Steam Workshop on a server hosted via Pterodactyl. Here’s how to get it set up and running:

## 1. Upload the Script Files

### 1. Download the following files from the GitHub repository to your local machine:
   - update_mods.sh
   - modlist.txt (and optionally modhashes.txt, modfolders.txt if you have them already)

### 2. Go to your server’s File Manager in the Pterodactyl panel.

### 3. Upload the update_mods.sh and required files into your server’s /home/container directory (or the root directory visible in File Manager).

## 2. Configure the Script

### 1. In the File Manager, edit the update_mods.sh file and update the following variables at the top of the script:

   STEAMCMD="/home/container/steamcmd/steamcmd.sh"
   GAME_ID="736590"                     # Replace with your game’s App ID
   MODS_DIR="/home/container/Mods"
   MODLIST_FILE="/home/container/modlist.txt"
   HASH_FILE="/home/container/modhashes.txt"
   FOLDER_MAP_FILE="/home/container/modfolders.txt"

### 2. Ensure paths match your server structure. If modhashes.txt or modfolders.txt do not exist, the script will auto-create them.

### 3. Save the file.

### 3. Make the Script Executable

Open the Console tab of your server and run:

   chmod +x update_mods.sh

### 4. Run the Script

From the Console, execute the script manually using:

   ./update_mods.sh

This will:
- Read mod IDs from modlist.txt
- Use SteamCMD to download/update them
- Compare hash values to detect changes
- Move updated mods into the Mods directory
- Clean up removed mods

## 5. Automate

This can be done using the game server schedules tab and sending a server restart power action
