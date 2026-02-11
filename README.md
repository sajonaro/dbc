# Database Commander (dbc)

A terminal-based database management tool, focused on database operations across multiple database engines.

## Installation

### Prerequisites

**Runtime dependencies (required for all users):**

The pre-built binary requires these system libraries to run:
- `libncursesw6` - Terminal UI library
- `libpq5` - PostgreSQL client library

Install on your system:

**Ubuntu/Debian:**
```bash
sudo apt install libncursesw6 libpq5
```

**Fedora/RHEL/CentOS:**
```bash
sudo dnf install ncurses-libs postgresql-libs
```

**Arch Linux:**
```bash
sudo pacman -S ncurses postgresql-libs
```

**macOS:**
```bash
brew install ncurses postgresql
```

---

**Build dependencies (only if building from source):**
- Zig 0.15.2 or later
- Development headers: `libncursesw5-dev` and `libpq-dev` (Ubuntu/Debian)

**On Ubuntu/Debian (for building):**
```bash
sudo apt install libncursesw5-dev libpq-dev
```

### Method 1: Pre-built Binary (Recommended - No Build Required)

**Direct install from GitHub (fastest):**
```bash
curl -sSL https://raw.githubusercontent.com/sajonaro/dbc/master/install-binary.sh | bash
```

**With custom installation prefix:**
```bash
curl -sSL https://raw.githubusercontent.com/sajonaro/dbc/master/install-binary.sh | PREFIX=/usr/local bash
```

**Specific version:**
```bash
curl -sSL https://raw.githubusercontent.com/sajonaro/dbc/master/install-binary.sh | VERSION=v0.1.0 bash
```

**Supported platforms:**
- Linux x86_64

### Method 2: Build from Source

**Using install script:**
```bash
curl -sSL https://raw.githubusercontent.com/sajonaro/dbc/master/install.sh | bash
```

**Or clone and build:**
```bash
git clone https://github.com/sajonaro/dbc.git && cd dbc && ./install.sh
```

### Method 3: Direct Installation with Zig

```bash
git clone https://github.com/sajonaro/dbc.git && cd dbc && zig build -Doptimize=ReleaseSafe --prefix ~/.local && echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

### Method 4: As a Zig Dependency

```bash
zig fetch --save git+https://github.com/sajonaro/dbc.git
```

## Usage

After installation, you can use `dbc` in the following ways:

```bash
# Start dbc with an empty editor
dbc

# Load a SQL file into the editor
dbc query.sql

# Display help message
dbc --help
dbc -h
dbc ?
```

### Command-Line Options

- **No arguments**: Starts dbc with an empty editor
- **FILE**: Opens the specified SQL file in the editor panel
- **--help, -h, ?**: Displays usage information and exits

### Examples

```bash
# Start dbc and begin writing queries
dbc

# Open an existing query file
dbc /path/to/my-query.sql

# Get help
dbc --help
```

## Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Architecture documentation, design principles, and key bindings
- **[STRUCTURE.md](STRUCTURE.md)** - Project structure and file organization

## Building

```bash
zig build
```

## Running

```bash
zig build run
```

## Testing

```bash
zig build test
```

## Supported Databases

- PostgreSQL (via libpq)
- SQLite (via sqlite3)
- MSSQL (via ODBC)
- MariaDB (via mariadb client library)

## Dependencies

- ncurses (for TUI)
- libpq (PostgreSQL)
- sqlite3
- ODBC drivers (for MSSQL)
- MariaDB client library


