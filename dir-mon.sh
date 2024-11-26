#!/bin/bash
set -euo pipefail

# Script Title: File Manager with Limit and Logging
# Description: Ensures only a specified number of large files remain in a directory, with logging and dry run functionality.
# Author: elvee
# Version: 0.2.1
# License: MIT
# Creation Date: 26-11-2024
# Last Modified: 27-04-2024
# Usage: ./dir-mon.sh [OPTIONS]

# Constants
DEFAULT_INTERVAL=600                 # Default interval in seconds (10 minutes)
DEFAULT_FILE_SIZE_GB=2               # Default file size threshold in GB
DEFAULT_FILE_SIZE_MB=0               # Default file size threshold in MB
DEFAULT_FILE_COUNT=1                 # Default number of files allowed to exceed the limit
DEFAULT_LOG_DIR="${PWD}"             # Default directory for saving logs

# Global Variables
LOG_FILE=""

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
  -n, --dry-run                         Perform a dry run (only show actions without making changes). (optional)
  -t, --time MINUTES                    Monitor duration in minutes. (optional)
  -h, --help                            Show this help message and exit.

Examples:
  $0 -d /path/to/dir -S 1 -f 2 -t 30 -n
  $0 -d /path/to/dir -s 500 -f 3
"
}

# Function: Error Handling
error_exit() {
  echo "Error: $1" >&2
  if [[ -n "$LOG_FILE" ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR: $1" >> "$LOG_FILE"
  fi
  exit 1
}

# Function: Initialize Logging
initialize_logging() {
  mkdir -p "$DEFAULT_LOG_DIR" || error_exit "Failed to create log directory: $DEFAULT_LOG_DIR"
  
  if [[ ! -w "$DEFAULT_LOG_DIR" ]]; then
    error_exit "Log directory is not writable: $DEFAULT_LOG_DIR"
  fi

  LOG_FILE="$DEFAULT_LOG_DIR/dir-mon-$(date '+%Y%m%d-%H%M%S').log"
  echo "Log file initialized: $LOG_FILE"
  echo "$(date '+%Y-%m-%d %H:%M:%S') Script started." > "$LOG_FILE"
}

# Function: Clean Large Files
clean_large_files() {
  local dir="$1"
  local min_size="$2"
  local max_files="$3"
  local dry_run="$4"

  # Find files larger than the specified size and sort by modification time
  readarray -t files < <(find "$dir" -type f -size +"${min_size}"c -printf "%T@ %p\n" | sort -nr | awk '{print substr($0, index($0,$2))}')

  # Keep only the specified number of most recent files
  if (( ${#files[@]} > max_files )); then
    for ((i = max_files; i < ${#files[@]}; i++)); do
      if [[ "$dry_run" == "true" ]]; then
        echo "Dry run: Would delete ${files[$i]}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') Dry run: Would delete ${files[$i]}" >> "$LOG_FILE"
      else
        echo "Deleting: ${files[$i]}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') Deleting: ${files[$i]}" >> "$LOG_FILE"
        rm -f "${files[$i]}"
      fi
    done
  else
    echo "No action required. Number of large files (${#files[@]}) is within the limit ($max_files)."
    echo "$(date '+%Y-%m-%d %H:%M:%S') No action required. Files within limit." >> "$LOG_FILE"
  fi
}

# Function: Main Logic
main_logic() {
  local target_dir=""
  local size_mb=$DEFAULT_FILE_SIZE_MB
  local size_gb=$DEFAULT_FILE_SIZE_GB
  local max_files=$DEFAULT_FILE_COUNT
  local monitor_duration=0
  local dry_run="false"

  # Parse command-line options
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -d|--directory)
        if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
          target_dir="$2"
          shift 2
        else
          error_exit "Option '$1' requires a directory argument."
        fi
        ;;
      -s|--size-in-mb)
        if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
          size_mb="$2"
          shift 2
        else
          error_exit "Option '$1' requires a numeric size in MB."
        fi
        ;;
      -S|--size-in-gb)
        if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
          size_gb="$2"
          shift 2
        else
          error_exit "Option '$1' requires a numeric size in GB."
        fi
        ;;
      -f|--file-count)
        if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
          max_files="$2"
          shift 2
        else
          error_exit "Option '$1' requires a numeric file count."
        fi
        ;;
      -n|--dry-run)
        dry_run="true"
        shift 1
        ;;
      -t|--time)
        if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
          monitor_duration="$2"
          shift 2
        else
          error_exit "Option '$1' requires a numeric time in minutes."
        fi
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

  # Validate required arguments
  if [[ -z "$target_dir" ]]; then
    error_exit "Target directory is required. Use -d or --directory to specify."
  fi
  if [[ ! -d "$target_dir" ]]; then
    error_exit "Directory does not exist: $target_dir"
  fi

  # Validate numerical inputs
  if (( max_files < 1 )); then
    error_exit "File count must be at least 1."
  fi

  if (( size_mb < 0 )); then
    error_exit "Size in MB cannot be negative."
  fi

  if (( size_gb < 0 )); then
    error_exit "Size in GB cannot be negative."
  fi

  if (( monitor_duration < 0 )); then
    error_exit "Monitor duration cannot be negative."
  fi

  # Enforce mutual exclusivity of size options
  if (( size_mb > 0 && size_gb > 0 )); then
    error_exit "Please specify only one of --size-in-mb or --size-in-gb."
  fi

  # Calculate size threshold in bytes
  local min_size_bytes=0
  if (( size_gb > 0 )); then
    min_size_bytes=$((size_gb * 1024 * 1024 * 1024))
  fi
  if (( size_mb > 0 )); then
    min_size_bytes=$((size_mb * 1024 * 1024))
  fi

  echo "Monitoring directory: $target_dir"
  echo "File size threshold: $min_size_bytes bytes"
  echo "Maximum files to keep: $max_files"
  echo "$(date '+%Y-%m-%d %H:%M:%S') Monitoring directory: $target_dir, File size threshold: $min_size_bytes bytes, Max files: $max_files" >> "$LOG_FILE"

  # Set monitoring duration
  local start_time
  local end_time
  start_time=$(date +%s)
  end_time=$((start_time + monitor_duration * 60))

  # Monitor loop
  while true; do
    clean_large_files "$target_dir" "$min_size_bytes" "$max_files" "$dry_run"
    if (( monitor_duration > 0 )) && (( $(date +%s) >= end_time )); then
      echo "Monitoring duration ended."
      echo "$(date '+%Y-%m-%d %H:%M:%S') Monitoring duration ended." >> "$LOG_FILE"
      break
    fi
    sleep "$DEFAULT_INTERVAL"
  done
}

# Main Function
main() {
  print_ascii_art
  initialize_logging
  main_logic "$@"
  echo "$(date '+%Y-%m-%d %H:%M:%S') Script finished." >> "$LOG_FILE"
}

# Run Script
main "$@"