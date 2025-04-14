# STEAMCMD Auto Mod Updater for Game Servers

This script helps you automatically update mods for your STEAMCMD-based game server by downloading mods from the Steam Workshop. It checks the latest versions of mods, updates them, and ensures only the latest versions are present on your server.

# Prerequisites

Before using this script, ensure you have the following:

- STEAMCMD: STEAMCMD must be installed and available on your server.
- Game ID: Replace the placeholder <GAME_ID> in the script with your game's Steam App ID. You can find the Steam App ID on the Steam Database (https://steamdb.info/).
- Server Setup: The script assumes your server has a structure where mods are stored in a specific directory. Ensure the MODS_DIR variable is set correctly to where you want to store mods.

# Setup

## 1. Download the Script Files

Download the appropriate script for your system:

### Linux:

Download update_mods.sh

### Windows:

Download update_mods.bat

Once you've downloaded the correct script for your operating system, proceed to the setup instructions below.

## 2. Edit the Script

Open the script file (mod_updater.sh) and update the following variables:

- GAME_ID: Replace <GAME_ID> with the correct Steam App ID for your game. You can find this ID on the Steam Database (https://steamdb.info/).
- MODS_DIR: Ensure this is set to the directory where you want the mods to be installed on your server.
- MODLIST_FILE: Make sure this file contains a list of mod IDs you wish to download. Each mod ID should be on a separate line.


# How to Get Steam Workshop Mod IDs for modlist.txt

The `modlist.txt` file is where you list the Steam Workshop IDs of the mods you want your server to automatically download and update.

##  From the Steam Workshop URL

1. Visit your game's Steam Workshop page.
   Example: https://steamcommunity.com/app/480/workshop/ (replace 480 with your game’s App ID)

2. Click on a mod you want to use.

3. Look at the URL in your browser’s address bar.
   It will look like this:
   https://steamcommunity.com/sharedfiles/filedetails/?id=1234567890

4. Copy the number after `id=`. For example: 1234567890

5. Paste that number into your `modlist.txt` file (one ID per line).

### Example modlist.txt

1234567890

9876543210

5556667778

### Tips

- You can include as many mod IDs as you want — just add one per line.
- The script will automatically handle downloading and updating for you.
- When you remove a Mod ID from the list. The script will automatically remove the mod files from the server upon next restart/execution

## 3. Make the Script Executable (Linux Only)

### !!! IF USING PTERODACTYL PANEL SEE THIS FILE: ([Pterodactyl Panel Setup](https://github.com/Hadgebury/SteamCMD-Game-Server-Auto-Mod-Updater/blob/main/Pterodactyl_Panel_Instructions.md)) AND IGNORE THIS SECTION'S INSTRUCTIONS !!!

On Linux, ensure the script has execute permissions by running:

chmod +x mod_updater.sh

## 4. Run the Script

### !!! IF USING PTERODACTYL PANEL SEE THIS FILE: ([Pterodactyl Panel Setup](https://github.com/Hadgebury/SteamCMD-Game-Server-Auto-Mod-Updater/blob/main/Pterodactyl_Panel_Instructions.md)) AND IGNORE THIS SECTION'S INSTRUCTIONS !!!

Once the script is configured, you can run it using:

### Linux:

./mod_updater.sh

### Windows:

On Windows, you can run the script using Git Bash or any terminal that supports bash commands:

bash mod_updater.sh

## 5. Automate the Script

### !!! IF USING PTERODACTYL PANEL SEE THIS FILE: ([Pterodactyl Panel Setup](https://github.com/Hadgebury/SteamCMD-Game-Server-Auto-Mod-Updater/blob/main/Pterodactyl_Panel_Instructions.md)) AND IGNORE THIS SECTION'S INSTRUCTIONS !!!

To keep your mods updated automatically, consider adding the script to a cron job or your server's startup process.

### Linux (Cron Job Example):

For example, to run the script every day at 2:00 AM, add a cron job by running:

crontab -e

And add this line:

0 2 * * * /path/to/mod_updater.sh

### Windows (Task Scheduler Example):

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

# Configuration Variables / File Paths

Below are the key configuration variables you can modify in the script and their usual file paths:

## STEAMCMD
Path to your SteamCMD installation.

### Linux:

/home/container/steamcmd/steamcmd.sh

### Windows:

Adjust the path as necessary (e.g., C:\path\to\steamcmd\steamcmd.exe).

## GAME_ID
Replace <GAME_ID> with your Steam App ID for the game you want to update.

## MODS_DIR
The directory where the mods will be installed on your server.

### Linux:

/home/container/Mods

### Windows:

Adjust the path as necessary (e.g., C:\path\to\Mods).

## MODLIST_FILE
The path to the file that contains the list of mod IDs you want to install or update.

### Linux:

/home/container/modlist.txt

### Windows:

Adjust the path as necessary (e.g., C:\path\to\modlist.txt).

## HASH_FILE
The file where mod hashes are stored to check for updates.

### Linux:

/home/container/modhashes.txt

### Windows:

Adjust the path as necessary (e.g., C:\path\to\modhashes.txt).

## FOLDER_MAP_FILE
The file where mod folder mappings are stored.

### Linux:

/home/container/modfolders.txt

### Windows:

Adjust the path as necessary (e.g., C:\path\to\modfolders.txt).
