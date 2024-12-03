#!/bin/bash
set -euo pipefail

# Ensure consistent locale settings
export LC_ALL=C
export LANG=C

# Script Title: File Manager with Limit and Logging
# Description: Ensures only a specified number of large files remain in a directory, with logging and dry run functionality.
# Author: elvee
# Version: 0.2.2
# License: MIT
# Creation Date: 26-11-2024
# Last Modified: 27-04-2024
# Usage: ./dir-mon.sh [OPTIONS]

# Constants
DEFAULT_INTERVAL=600                 # Default interval in seconds (10 minutes)
DEFAULT_FILE_SIZE_GB=2               # Default file size threshold in GB
DEFAULT_FILE_SIZE_MB=100              # Default file size threshold in MB
DEFAULT_FILE_COUNT=1                 # Default number of files allowed to exceed the limit
DEFAULT_LOG_DIR="${PWD}/logs"             # Default directory for saving logs

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

# Function: Check Date Compatibility
check_date_compatibility() {
  # Test if 'date +%s' works
  if ! date +%s >/dev/null 2>&1; then
    error_exit "'date +%s' is not supported on this system."
  fi

  # Test specific format
  test_date=$(date '+%Y-%m-%d %H:%M:%S') || error_exit "'date' command failed with format '+%Y-%m-%d %H:%M:%S'."
}

# Function: Clean Large Files
clean_large_files() {
  local dir="$1"
  local min_size="$2"
  local max_files="$3"
  local dry_run="$4"

  # Create a temporary file to store the file list
  local tmp_file
  tmp_file=$(mktemp)
  
  # Find files larger than the specified size and get their modification times
  # Using BSD-compatible commands
  find "$dir" -type f -size +"${min_size}"c -exec stat -f "%m %N" {} \; | sort -nr > "$tmp_file"
  
  # Count the number of files
  local file_count
  file_count=$(wc -l < "$tmp_file")
  
  # Keep only the specified number of most recent files
  if (( file_count > max_files )); then
    local i=0
    while IFS= read -r line; do
      file=$(echo "$line" | cut -d' ' -f2-)
      ((i++))
      if (( i > max_files )); then
        if [[ "$dry_run" == "true" ]]; then
          echo "Dry run: Would delete $file"
          echo "$(date '+%Y-%m-%d %H:%M:%S') Dry run: Would delete $file" >> "$LOG_FILE"
        else
          echo "Deleting: $file"
          echo "$(date '+%Y-%m-%d %H:%M:%S') Deleting: $file" >> "$LOG_FILE"
          rm -f "$file"
        fi
      fi
    done < "$tmp_file"
  else
    echo "No action required. Number of large files ($file_count) is within the limit ($max_files)."
    echo "$(date '+%Y-%m-%d %H:%M:%S') No action required. Files within limit." >> "$LOG_FILE"
  fi
  
  # Clean up temporary file
  rm -f "$tmp_file"
}

# Function: Main Logic
main_logic() {
  local target_dir=""
  local size_mb=0
  local size_gb=0
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

  # If no size is specified, use default MB
  if (( size_mb == 0 && size_gb == 0 )); then
    size_mb=$DEFAULT_FILE_SIZE_MB
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

# Function: Check Date Compatibility
check_date_compatibility() {
  # Test if 'date +%s' works
  if ! date +%s >/dev/null 2>&1; then
    error_exit "'date +%s' is not supported on this system."
  fi

  # Test specific format
  test_date=$(date '+%Y-%m-%d %H:%M:%S') || error_exit "'date' command failed with format '+%Y-%m-%d %H:%M:%S'."
}

# Main Function
main() {
  print_ascii_art
  initialize_logging
  check_date_compatibility
  main_logic "$@"
  echo "$(date '+%Y-%m-%d %H:%M:%S') Script finished." >> "$LOG_FILE"
}

# Run Script
main "$@"