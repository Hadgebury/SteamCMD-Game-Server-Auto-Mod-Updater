
# STEAMCMD Mod Updater for Game Servers

This script helps you automatically update mods for your STEAMCMD-based game server by downloading mods from the Steam Workshop. It checks the latest versions of mods, updates them, and ensures only the latest versions are present on your server.

# Prerequisites

Before using this script, ensure you have the following:

- STEAMCMD: STEAMCMD must be installed and available on your server.
- Game ID: Replace the placeholder <GAME_ID> in the script with your game's Steam App ID. You can find the Steam App ID on the Steam Database (https://steamdb.info/).
- Server Setup: The script assumes your server has a structure where mods are stored in a specific directory. Ensure the MODS_DIR variable is set correctly to where you want to store mods.

# Setup

## 1. Download the Script Files

Download the appropriate script for your system:

### Linux: Download update_mods.sh

### Windows: Download update_mods.bat

Once you've downloaded the correct script for your operating system, proceed to the setup instructions below.

## 2. Edit the Script

Open the script file (mod_updater.sh) and update the following variables:

- GAME_ID: Replace <GAME_ID> with the correct Steam App ID for your game. You can find this ID on the Steam Database (https://steamdb.info/).
- MODS_DIR: Ensure this is set to the directory where you want the mods to be installed on your server.
- MODLIST_FILE: Make sure this file contains a list of mod IDs you wish to download. Each mod ID should be on a separate line.

## 3. Make the Script Executable (Linux Only)

On Linux, ensure the script has execute permissions by running:

chmod +x mod_updater.sh

## 4. Run the Script

Once the script is configured, you can run it using:

### Linux:

./mod_updater.sh

### Windows:

On Windows, you can run the script using Git Bash or any terminal that supports bash commands:

bash mod_updater.sh

## 5. Automate the Script

To keep your mods updated automatically, consider adding the script to a cron job or your server's startup process.

Linux/MacOS (Cron Job Example):

For example, to run the script every day at 2:00 AM, add a cron job by running:

crontab -e

And add this line:

0 2 * * * /path/to/mod_updater.sh

Windows (Task Scheduler Example):

For Windows, you can use Task Scheduler to run the script automatically at a set time. Here's a basic guide:

1. Open Task Scheduler from the Start Menu.
2. Click on Create Basic Task.
3. Set a trigger (e.g., every day at 2:00 AM).
4. In the "Action" section, select "Start a Program" and choose bash.exe from the Git Bash installation directory.
5. Set the arguments to run your script (e.g., mod_updater.sh), and set the "Start In" field to the folder where the script is located.

# How It Works

1. Mod List: You provide a list of mod IDs in modlist.txt. These are the mods that the script will check and update.
2. SteamCMD: The script uses SteamCMD to download the latest versions of mods from the Steam Workshop based on the mod IDs.
3. Version Control: The script computes a hash of the downloaded mod and compares it with the stored hash from the previous run. If a new version is found, it will replace the old version.
4. Cleanup: Old or missing mods that are no longer in modlist.txt are automatically removed from the server to avoid unnecessary files taking up space.

# Configuration

Here’s a list of the important configuration variables that you can modify:

STEAMCMD: Path to your SteamCMD installation (/home/container/steamcmd/steamcmd.sh by default on Linux; adjust the path for Windows).
GAME_ID: Replace <GAME_ID> with your Steam App ID.
MODS_DIR: The directory where the mods will be installed on your server. The default is /home/container/Mods on Linux; adjust the path for Windows.
MODLIST_FILE: The path to the file that contains the list of mod IDs you want to install/update (/home/container/modlist.txt by default on Linux; adjust for Windows).
HASH_FILE: The file where mod hashes are stored to check for updates (/home/container/modhashes.txt by default on Linux; adjust for Windows).
FOLDER_MAP_FILE: The file where mod folder mappings are stored (/home/container/modfolders.txt by default on Linux; adjust for Windows).
