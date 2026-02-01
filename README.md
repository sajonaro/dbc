# Database Commander (dbc)

A terminal-based database management tool inspired by Midnight Commander, focused on database operations across multiple database engines.

## Architecture

This project follows a clean **Model-View-Action** architecture pattern with unidirectional data flow:

```
Events → Actions → State → Views → Screen
```

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

## Current Status

**Phase: Skeleton / Structure**

The project structure is now in place with:

- ✅ Complete folder structure
- ✅ Model layer (state definitions)
- ✅ Events and async infrastructure
- ✅ Theme system
- ✅ Placeholder files for all components

**Next Steps:**

1. Implement ncurses UI abstractions (`ui/ui.zig`, `ui/input.zig`)
2. Implement basic views (tree, editor, results)
3. Implement SQLite driver (simplest to start with)
4. Wire up event handling and rendering
5. Test with a local SQLite database

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

## License

[To be determined]

## Contributing

[To be determined]

## References

See `idea.md` for detailed architecture documentation, including:
- Complete architecture diagrams
- State management patterns
- View rendering approach
- Database driver implementation examples
- Implementation phases
- Design decisions and rationale