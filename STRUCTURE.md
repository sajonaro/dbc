# Project Structure

```
dbc/
├── build.zig                    # Zig build configuration
├── build.zig.zon                # Zig package manifest
├── ARCHITECTURE.md              # Detailed architecture documentation
├── STRUCTURE.md                 # This file - project structure overview
├── README.md                    # Main documentation
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

## Architecture

This project follows a clean **Model-View-Action** architecture pattern with unidirectional data flow:

```
Events → Actions → State → Views → Screen
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed architecture documentation and key bindings.
