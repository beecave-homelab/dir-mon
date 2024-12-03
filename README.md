# dir-mon

A Bash script that monitors directories and manages large files by automatically maintaining a specified limit of files that exceed a certain size threshold. Perfect for managing storage in directories where large files accumulate over time.

## Versions

**Current version**: 0.2.2

## Table of Contents

- [Versions](#versions)
- [Badges](#badges)
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [License](#license)
- [Contributing](#contributing)

## Badges

![Bash](https://img.shields.io/badge/Bash-4.0%2B-green)
![Version](https://img.shields.io/badge/Version-0.2.2-blue)
![License](https://img.shields.io/badge/License-MIT-yellow)

## Features

- Monitor directories for files exceeding specified size thresholds
- Support for both MB and GB size specifications
- Configurable file retention count
- Dry-run capability to preview actions
- Detailed logging of all operations
- Timed monitoring with automatic termination
- BSD-compatible file operations

## Installation

1. Clone the repository or download the `dir-mon.sh` script
2. Make the script executable:

   ```bash
   chmod +x dir-mon.sh
   ```

3. Ensure you have bash version 4.0 or higher installed

## Usage

The script can be run with various options:

./dir-mon.sh [OPTIONS]

Options:
  -d, --directory DIR        Target directory to monitor (required)
  -s, --size-in-mb SIZE_MB  File size threshold in MB
  -S, --size-in-gb SIZE_GB  File size threshold in GB
  -f, --file-count COUNT    Maximum number of files to keep exceeding size limit
  -n, --dry-run            Perform a dry run without making changes
  -t, --time MINUTES       Monitor duration in minutes
  -h, --help              Show help message and exit

### Examples

#### Monitor directory, keep 2 files over 1GB, run for 30 minutes in dry-run mode

```bash
./dir-mon.sh -d /path/to/dir -S 1 -f 2 -t 30 -n
```

#### Monitor directory, keep 3 files over 500MB indefinitely

```bash
./dir-mon.sh -d /path/to/dir -s 500 -f 3
```

### Default Values

- Monitoring interval: 600 seconds (10 minutes)
- File size threshold: 100MB
- Maximum file count: 1
- Log directory: Current working directory

## License

This project is licensed under the MIT license. See [LICENSE](LICENSE) for more information.

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.
