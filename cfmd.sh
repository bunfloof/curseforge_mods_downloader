#!/bin/bash
# shellcheck disable=SC2155
#
# CurseForge mods downloader script

# Configurable options below
manifest_path='manifest.json'
download_directory='mods'
api_key=''
max_parallel=100

# Do not modify below

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $1"; }

total_mods=0
status_dir=$(mktemp -d)

setup_download_directory() {
    if [ -z "$download_directory" ]; then
        download_directory="$script_dir"
        log_info "No download directory specified. Using script directory: $download_directory"
    else
        download_directory=$(realpath "$download_directory")
        if [ ! -d "$download_directory" ]; then
            log_info "Creating download directory: $download_directory"
            mkdir -p "$download_directory" || {
                log_error "Failed to create download directory"
                exit 1
            }
        fi
    fi
    log_info "Using download directory: $download_directory"
    cd "$download_directory" || {
        log_error "Failed to change to download directory"
        exit 1
    }
}

download_file() {
    local url="$1"
    local mod_index="$2"
    local project_id="$3"
    local file_id="$4"
    local file_name=$(basename "$url" | sed 's/%20/ /g')
    log_info "[DOWNLOAD] Starting download of $file_name"
    if curl -s -L -o "$download_directory/$file_name" "$url"; then
        log_success "[DOWNLOAD] Finished downloading $file_name"
        echo "success" >"${status_dir}/${mod_index}"
    else
        log_error "[DOWNLOAD] Failed to download $file_name"
        echo "failed:$project_id:$file_id:$file_name" >"${status_dir}/${mod_index}"
    fi
}

process_mod() {
    local project_id="$1"
    local file_id="$2"
    local mod_index="$3"

    local url="https://api.curseforge.com/v1/mods/$project_id/files/$file_id/download-url"
    log_info "[API] Requesting download URL for Project ID: $project_id, File ID: $file_id"
    local response=$(curl -s -H "Accept: application/json" -H "X-Api-Key: $api_key" "$url")

    local download_url=$(echo "$response" | grep -o '"data":"[^"]*"' | sed 's/"data":"//;s/"$//')

    if [[ -n "$download_url" ]]; then
        download_url=$(echo "$download_url" | sed 's/ /%20/g')
        download_file "$download_url" "$mod_index" "$project_id" "$file_id"
    else
        log_error "[API] Failed to get download URL for Project ID: $project_id, File ID: $file_id"
        echo "failed:$project_id:$file_id:Unknown" >"${status_dir}/${mod_index}"
    fi
}

log_info "Starting CurseForge mod downloader script"

if [ -z "$api_key" ]; then
    log_info "API key not supplied. Attempting to fetch from the web..."
    api_key=$(curl https://arch.b4k.dev/vg/thread/388569358 | grep -Poim1 'and put \K([a-z0-9]|\$){60}')
    if [ -z "$api_key" ]; then
        log_error "Failed to fetch API key. Please provide it manually."
        exit 1
    else
        log_success "API key fetched successfully."
    fi
else
    log_info "Using provided API key."
fi

log_info "Reading manifest file: $manifest_path"
if [ ! -f "$manifest_path" ]; then
    log_error "Manifest file not found: $manifest_path"
    exit 1
fi

mods_to_download=()

while IFS= read -r line; do
    if [[ $line == *'"files":'* ]]; then
        in_files_section=true
        continue
    fi

    if $in_files_section; then
        if [[ $line == *"}"* ]]; then
            project_id=$(echo "$current_entry" | grep -o '"projectID": [0-9]*' | awk '{print $2}')
            file_id=$(echo "$current_entry" | grep -o '"fileID": [0-9]*' | awk '{print $2}')

            if [[ -n "$project_id" && -n "$file_id" ]]; then
                mods_to_download+=("$project_id $file_id")
            fi
            current_entry=""
        else
            current_entry+="$line"
        fi
    fi

    if [[ $line == *"]"* && $in_files_section == true ]]; then
        break
    fi
done <"$manifest_path"

total_mods=${#mods_to_download[@]}
log_info "Found $total_mods mods to download"

setup_download_directory
cd "$download_directory" || {
    log_error "Failed to change to download directory"
    exit 1
}

current_jobs=0
mod_index=0
for mod in "${mods_to_download[@]}"; do
    read -r project_id file_id <<<"$mod"

    process_mod "$project_id" "$file_id" "$mod_index" &

    ((current_jobs++))
    ((mod_index++))
    if [ $current_jobs -ge $max_parallel ]; then
        wait -n
        ((current_jobs--))
    fi
done

wait

downloaded=0
failed=0
failed_mods=""
for i in $(seq 0 $((total_mods - 1))); do
    if [ -f "${status_dir}/${i}" ]; then
        status=$(cat "${status_dir}/${i}")
        if [[ $status == success* ]]; then
            ((downloaded++))
        else
            ((failed++))
            IFS=':' read -r _ project_id file_id file_name <<<"$status"
            failed_mods+="{Project ID: $project_id, File ID: $file_id ($file_name)}, "
        fi
    else
        ((failed++))
        failed_mods+="Unknown mod (index $i), "
    fi
done

failed_mods=${failed_mods%, } # removed trailing comma and space

log_info "Download process completed"
log_success "Successfully downloaded: $downloaded out of $total_mods mods"
log_warning "Failed to download: $failed mods"

if [ $failed -gt 0 ]; then
    log_error "Mods that failed to download: $failed_mods"
fi

rm -rf "$status_dir"
log_info "CurseForge mods downloader script completed"
