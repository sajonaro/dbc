# Database Commander (dbc)

A terminal-based database management tool, focused on database operations across multiple database engines.

## Architecture

This project follows a clean **Model-View-Action** architecture pattern with unidirectional data flow:

```
Events → Actions → State → Views → Screen
```

See [`idea.md`](idea.md) for detailed architecture documentation

### Core Principles

1. **State** is the single source of truth (in `model.zig`)
2. **Views** are pure functions: `(State, Window) → pixels`
3. **Actions** are the only way to modify state
4. **Events** flow through one main handler
5. **Async** results arrive via queue, processed as events
6. No observer pattern, no component lifecycle, no virtual DOM

## Project Structure

```
dbc/
├── build.zig                    # Zig build configuration
├── build.zig.zon                # Zig package manifest
├── idea.md                      # Detailed architecture documentation
├── README.md                    # This file
│
├── src/
│   ├── main.zig                 # Entry point and main loop
│   │
│   ├── model.zig                # Root state definition
│   ├── model/
│   │   ├── tree.zig             # Tree panel state
│   │   ├── editor.zig           # Query editor state
│   │   ├── results.zig          # Results grid state
│   │   └── modal.zig            # Modal dialog state
│   │
│   ├── views/
│   │   ├── view.zig             # RenderContext and base types
│   │   ├── main.zig             # Main view composition (layout)
│   │   ├── tree.zig             # Tree panel view
│   │   ├── editor.zig           # Query editor view
│   │   ├── results.zig          # Results grid view
│   │   ├── status.zig           # Status bar view
│   │   └── modal.zig            # Modal overlay views
│   │
│   ├── actions.zig              # Main event router
│   ├── actions/
│   │   ├── tree.zig             # Tree panel actions
│   │   ├── editor.zig           # Editor actions (insert, delete, undo)
│   │   ├── results.zig          # Results navigation actions
│   │   └── modal.zig            # Modal interaction actions
│   │
│   ├── events.zig               # Event type definitions
│   ├── async.zig                # Async queue for background operations
│   ├── theme.zig                # Color themes (dark, light)
│   │
│   ├── ui/
│   │   ├── ui.zig               # Screen and Window abstractions
│   │   └── input.zig            # Input polling (ncurses)
│   │
│   ├── db/
│   │   ├── db.zig               # Unified database API
│   │   ├── types.zig            # Common database types
│   │   └── drivers/
│   │       ├── postgresql.zig   # PostgreSQL driver (libpq)
│   │       ├── sqlite.zig       # SQLite driver
│   │       ├── mssql.zig        # MSSQL driver (ODBC)
│   │       └── mariadb.zig      # MariaDB driver
│   │
│   └── sql/
│       ├── syntax.zig           # SQL tokenizer for syntax highlighting
│       ├── formatter.zig        # SQL pretty-printing
│       └── completer.zig        # Autocomplete logic
│
└── tests/
    ├── model_tests.zig
    ├── action_tests.zig
    └── view_tests.zig
```

## Key Bindings (Planned)

### Global
- `Ctrl+Q` - Quit
- `Tab` - Next panel
- `Shift+Tab` - Previous panel
- `F1` - Help
- `F5` - Execute query
- `Escape` - Close modal / Cancel query

### Tree Panel
- `↑/↓` - Navigate
- `←` - Collapse / Go to parent
- `→` - Expand / Go to child
- `Enter` - Activate (SELECT * for tables)

### Editor Panel
- `↑/↓/←/→` - Move cursor
- `Ctrl+Z` - Undo
- `Ctrl+Y` - Redo
- `Ctrl+L` - Format SQL

### Results Panel
- `↑/↓/←/→` - Navigate cells
- `PgUp/PgDn` - Page through rows
- `Ctrl+C` - Copy cell
- `Ctrl+E` - Export results

## Installation

### Prerequisites

Before installing dbc, ensure you have the following dependencies installed:

**Required:**
- Zig 0.15.2 or later
- ncursesw (wide character support)
- panel library
- libpq (PostgreSQL client library)

**On Ubuntu/Debian:**
```bash
sudo apt install libncursesw5-dev libpq-dev
```

**On macOS:**
```bash
brew install ncurses postgresql
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

## Building

```bash
zig build
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


