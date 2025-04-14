# STEAMCMD Mod Updater on Pterodactyl Panel (Linux)

The STEAMCMD Mod Updater script allows you to automatically update mods from the Steam Workshop on a server hosted via Pterodactyl. Here’s how to get it set up and running:

## 1. Upload the Script Files

### 1. Download the following files from the GitHub repository to your local machine:
   
   - update_mods.sh

### 2. Go to your server’s File Manager in the Pterodactyl panel.

### 3. Upload the update_mods.sh into your server’s /home/container directory (or the root directory visible in File Manager).

## 2. Execute the script on Game Server Start/Restart

1. Go to the Startup tab in the Pterodactyl panel.

2. Modify the Startup Command to prepend the updater. For example:

   /home/container/update_mods.sh && ./HarshDoorstop/Binaries/Linux/HarshDoorstopServer-Linux-Shipping

### Insert /home/container/update_mods.sh && Infront of your existing start command or Replace ./HarshDoorstop/Binaries/Linux/HarshDoorstopServer-Linux-Shipping with your actual game launch command.
