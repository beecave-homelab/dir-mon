#!/bin/bash
set -euo pipefail

# Script Title: File Manager with Limit
# Description: Ensures only a specified number of large files remain in a directory.
# Author: elvee
# Version: 0.1.0
# License: MIT
# Creation Date: 26-11-2024
# Last Modified: 26-11-2024
# Usage: ./dir-mon.sh [OPTIONS]

# Constants
DEFAULT_INTERVAL=600                 # Default interval in seconds (10 minutes)
DEFAULT_FILE_SIZE_GB=2               # Default file size threshold in GB
DEFAULT_FILE_SIZE_MB=0               # Default file size threshold in MB
DEFAULT_FILE_COUNT=1                 # Default number of files allowed to exceed the limit

# Function: Print ASCII Art
print_ascii_art() {
  echo "

    ██████╗ ██╗██████╗       ███╗   ███╗ ██████╗ ███╗   ██╗
    ██╔══██╗██║██╔══██╗      ████╗ ████║██╔═══██╗████╗  ██║
    ██║  ██║██║██████╔╝█████╗██╔████╔██║██║   ██║██╔██╗ ██║
    ██║  ██║██║██╔══██╗╚════╝██║╚██╔╝██║██║   ██║██║╚██╗██║
    ██████╔╝██║██║  ██║      ██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
    ╚═════╝ ╚═╝╚═╝  ╚═╝      ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
                                                       
  "
}

# Function: Show Help
show_help() {
  echo "
Usage: $0 [OPTIONS]

Options:
  -d, --directory DIR                   Target directory to monitor. (required)
  -s, --size-in-mb SIZE_MB              File size threshold in MB. (optional)
  -S, --size-in-gb SIZE_GB              File size threshold in GB. (optional)
  -f, --file-count FILE_COUNT           Maximum number of files to keep exceeding size limit. (optional, default: $DEFAULT_FILE_COUNT)
  -t, --time MINUTES                    Monitor duration in minutes. (optional)
  -h, --help                            Show this help message and exit.

Examples:
  $0 -d /path/to/dir -S 1 -f 2 -t 30
  $0 -d /path/to/dir -s 500 -f 3
"
}

# Function: Error Handling
error_exit() {
  echo "Error: $1" >&2
  exit 1
}

# Function: Clean Large Files
clean_large_files() {
  local dir="$1"
  local min_size="$2"
  local max_files="$3"

  # Find files larger than the specified size and sort by modification time
  local files=($(find "$dir" -type f -size +"${min_size}"c -printf "%T@ %p\n" | sort -nr | awk '{print $2}'))

  # Keep only the specified number of most recent files
  if (( ${#files[@]} > max_files )); then
    for ((i = max_files; i < ${#files[@]}; i++)); do
      echo "Deleting: ${files[$i]}"
      rm -f "${files[$i]}"
    done
  else
    echo "No action required. Number of large files (${#files[@]}) is within the limit ($max_files)."
  fi
}

# Function: Main Logic
main_logic() {
  local target_dir=""
  local size_mb=$DEFAULT_FILE_SIZE_MB
  local size_gb=$DEFAULT_FILE_SIZE_GB
  local max_files=$DEFAULT_FILE_COUNT
  local monitor_duration=0

  # Parse command-line options
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -d|--directory)
        target_dir="$2"
        shift 2
        ;;
      -s|--size-in-mb)
        size_mb="$2"
        shift 2
        ;;
      -S|--size-in-gb)
        size_gb="$2"
        shift 2
        ;;
      -f|--file-count)
        max_files="$2"
        shift 2
        ;;
      -t|--time)
        monitor_duration="$2"
        shift 2
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        error_exit "Invalid option: $1"
        ;;
    esac
  done

  # Validate inputs
  if [[ -z "$target_dir" ]]; then
    error_exit "Target directory is required."
  fi
  if [[ ! -d "$target_dir" ]]; then
    error_exit "Directory does not exist: $target_dir"
  fi
  if (( max_files < 1 )); then
    error_exit "File count must be at least 1."
  fi

  # Calculate size threshold in bytes
  local min_size_bytes=$((size_gb * 1024 * 1024 * 1024))
  if (( size_mb > 0 )); then
    local size_mb_bytes=$((size_mb * 1024 * 1024))
    if (( size_mb_bytes > min_size_bytes )); then
      min_size_bytes=$size_mb_bytes
    fi
  fi

  echo "Monitoring directory: $target_dir"
  echo "File size threshold: $min_size_bytes bytes"
  echo "Maximum files to keep: $max_files"

  # Set monitoring duration
  local start_time=$(date +%s)
  local end_time=$((start_time + monitor_duration * 60))

  # Monitor loop
  while true; do
    clean_large_files "$target_dir" "$min_size_bytes" "$max_files"
    if (( monitor_duration > 0 )) && (( $(date +%s) >= end_time )); then
      echo "Monitoring duration ended."
      break
    fi
    sleep $DEFAULT_INTERVAL
  done
}

# Main Function
main() {
  print_ascii_art
  main_logic "$@"
}

# Run Script
main "$@"