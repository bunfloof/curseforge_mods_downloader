# curseforge_mods_downloader

Shell script for mass downloading CurseForge mods from a manifest file.

![demo](https://fur1.foxomy.com/consumer/5N9klqspbm.gif)

## Designed with no dependencies in mind

This script was designed for my furry [server](https://foxomy.com/discord). This script only uses `curl` requests and supports parallel downloads. Unlike other scripts that are written in Python or require dependencies, this script will run even on the most stripped down Linux server environments, such as some docker images. I hate Python.

## Usage

This is just one simple script.

1. Download `cfmd.sh`.
2. Put `manifest.json` in the same directory as the script.
3. Make the script executable and run it. For example, `chmod +x cfmd.sh && ./cfmd.sh`

All mods will be downloaded and saved to the `mods` directory.

## Configurable options (optional)

From `cfmd.sh`:
```
# Configurable options below
manifest_path='manifest.json'
download_directory='mods'
api_key=''
max_parallel=10
```

| Key                    | Default value   | Description                                                                                                                     |
|------------------------|-----------------|---------------------------------------------------------------------------------------------------------------------------------|
| **manifest_path**      | 'manifest.json' | Path to your `manifest.json` file. I suggest putting the manifest file in the same directory as the script.                     |
| **download_directory** | 'mods'          | If the path to where to download mods is not provided, then mods will be downloaded in the same directory as the script.        |
| **api_key**            | ''              | If the CurseForge API key is not provided, then the script will attempt to fetch for it from the web.                           |
| **max_parallel**       | 10              | Maximum number of simultaneous downloads at a time.                                                                             |
