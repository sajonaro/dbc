# Database Commander (dbc) - TODO

This file tracks implementation tasks for the Database Commander project.

## Current Status: Skeleton Phase Complete ✅

The project structure is fully set up with clean Model-View-Action architecture.

---

## Phase 1: Foundation (UI Infrastructure)

### ncurses Wrapper
- [ ] Implement `src/ui/ui.zig`
  - [ ] Screen initialization/cleanup
  - [ ] Window abstraction
  - [ ] Color pair management
  - [ ] Border drawing utilities
  - [ ] Text rendering functions
  - [ ] Cursor management
- [ ] Implement `src/ui/input.zig`
  - [ ] Keyboard input polling with timeout
  - [ ] Key event parsing (special keys, modifiers)
  - [ ] Mouse event support (optional)

### Theme System
- [x] Base theme definitions (dark, light)
- [ ] Apply color pairs to ncurses
- [ ] Theme switching logic

---

## Phase 2: Basic Views

### Tree View (`src/views/tree.zig`)
- [ ] Render tree nodes with indentation
- [ ] Render expand/collapse indicators
- [ ] Render icons for node types
- [ ] Render selection highlight
- [ ] Render scrollbar
- [ ] Render border and title

### Editor View (`src/views/editor.zig`)
- [ ] Render line numbers
- [ ] Render text content with scrolling
- [ ] Render cursor (when focused)
- [ ] Render selection highlight
- [ ] Render modified indicator
- [ ] Render executing indicator

### Results View (`src/views/results.zig`)
- [ ] Render column headers
- [ ] Render data rows
- [ ] Render cell selection
- [ ] Render NULL values (styled differently)
- [ ] Render scrollbars
- [ ] Render row count and execution time

### Status View (`src/views/status.zig`)
- [ ] Render status message
- [ ] Render connection info
- [ ] Render keybinding hints

### Modal View (`src/views/modal.zig`)
- [ ] Render overlay dim effect
- [ ] Render confirm modal
- [ ] Render error modal
- [ ] Render input modal
- [ ] Render connect modal

### Main View (`src/views/main.zig`)
- [ ] Implement layout calculation
- [ ] Compose all panels
- [ ] Handle terminal resize

---

## Phase 3: Actions (Event Handling)

### Main Event Router (`src/actions.zig`)
- [ ] Implement global hotkey handling
  - [ ] Ctrl+Q (quit)
  - [ ] Tab (cycle focus)
  - [ ] F1 (help)
  - [ ] F5 (execute query)
  - [ ] Escape (close modal/cancel)
- [ ] Route events to focused component
- [ ] Handle async event completions
- [ ] Handle modal event capture

### Tree Actions (`src/actions/tree.zig`)
- [ ] Up/Down navigation
- [ ] Expand/collapse nodes
- [ ] Enter to activate node
- [ ] Home/End shortcuts
- [ ] Lazy load children on expand
- [ ] Generate SELECT * for tables

### Editor Actions (`src/actions/editor.zig`)
- [ ] Character insertion
- [ ] Cursor movement (arrows, home, end)
- [ ] Backspace/Delete
- [ ] Enter (newline)
- [ ] Undo/Redo (Ctrl+Z, Ctrl+Y)
- [ ] Select all (Ctrl+A)
- [ ] Copy/Paste (Ctrl+C, Ctrl+V)
- [ ] SQL formatting (Ctrl+L)
- [ ] Ensure visible (scroll to cursor)

### Results Actions (`src/actions/results.zig`)
- [ ] Cell navigation (arrows)
- [ ] Page Up/Down
- [ ] Home/End (column)
- [ ] Ctrl+Home/End (row)
- [ ] Copy cell (Ctrl+C)
- [ ] View cell in modal (Enter)
- [ ] Export results (Ctrl+E)

### Modal Actions (`src/actions/modal.zig`)
- [ ] Confirm modal (OK/Cancel)
- [ ] Error modal (dismiss)
- [ ] Input modal (text entry, submit)
- [ ] Connect modal (field navigation, submit)

---

## Phase 4: Database Layer

### SQLite Driver (`src/db/drivers/sqlite.zig`)
- [ ] Connect/disconnect
- [ ] Execute query
- [ ] List databases (attached)
- [ ] List tables
- [ ] List columns
- [ ] Get table DDL
- [ ] Handle errors
- [ ] Async query execution (using threads)

### Database API (`src/db/db.zig`)
- [ ] Implement async query execution
- [ ] Implement query cancellation
- [ ] Implement connection pooling (optional)
- [ ] Implement metadata loading
- [ ] Result set building

### PostgreSQL Driver (`src/db/drivers/postgresql.zig`)
- [ ] Connect using libpq
- [ ] Execute query
- [ ] List databases
- [ ] List schemas
- [ ] List tables
- [ ] List columns
- [ ] Get table DDL

### MSSQL Driver (`src/db/drivers/mssql.zig`)
- [ ] Connect using ODBC
- [ ] Execute query
- [ ] List databases
- [ ] List schemas
- [ ] List tables
- [ ] List columns

### MariaDB Driver (`src/db/drivers/mariadb.zig`)
- [ ] Connect using MariaDB client
- [ ] Execute query
- [ ] List databases
- [ ] List tables
- [ ] List columns

---

## Phase 5: SQL Features

### Syntax Highlighting (`src/sql/syntax.zig`)
- [ ] Tokenize SQL
- [ ] Identify keywords
- [ ] Identify strings
- [ ] Identify numbers
- [ ] Identify comments
- [ ] Identify operators

### SQL Formatter (`src/sql/formatter.zig`)
- [ ] Parse SQL
- [ ] Apply formatting rules
- [ ] Handle indentation
- [ ] Handle line breaks

### Autocomplete (`src/sql/completer.zig`)
- [ ] Suggest SQL keywords
- [ ] Suggest table names
- [ ] Suggest column names
- [ ] Suggest functions
- [ ] Context-aware suggestions

---

## Phase 6: Integration & Testing

### Integration
- [ ] Wire up database connection flow
- [ ] Wire up query execution flow
- [ ] Wire up metadata loading
- [ ] Wire up tree population
- [ ] Handle errors gracefully
- [ ] Add loading states

### Testing
- [ ] Model state tests
- [ ] Action tests (event routing)
- [ ] View rendering tests (mock)
- [ ] Database driver tests
- [ ] SQL tokenizer tests
- [ ] Integration tests

---

## Phase 7: Polish & Features

### User Experience
- [ ] Connection management
  - [ ] Save connections to config file
  - [ ] Password storage (keyring)
  - [ ] Quick connect dialog
- [ ] Query management
  - [ ] Save/load queries
  - [ ] Query history
  - [ ] Multiple query tabs
- [ ] Results
  - [ ] Export to CSV
  - [ ] Export to JSON
  - [ ] Copy as INSERT statement
- [ ] Help screen
  - [ ] Keybindings reference
  - [ ] Getting started guide

### Configuration
- [ ] Config file support (~/.config/dbc/config.toml)
- [ ] Custom keybindings
- [ ] Theme customization
- [ ] Editor preferences

### Documentation
- [ ] User manual
- [ ] Architecture documentation (expand idea.md)
- [ ] Contributing guide
- [ ] API documentation

---

## Phase 8: Advanced Features (Future)

- [ ] Multi-cursor editing
- [ ] Visual query builder
- [ ] Schema diff
- [ ] Data migration tools
- [ ] Stored procedure debugging
- [ ] Performance profiling
- [ ] Plugin system
- [ ] Custom themes via config

---

## Bug Tracking

### Known Issues
- None yet (skeleton phase)

### To Investigate
- [ ] Memory leaks in async queue
- [ ] ncurses color pair limits
- [ ] Large result set handling

---

## Build & Release

- [ ] CI/CD setup
- [ ] Cross-platform builds (Linux, macOS, Windows)
- [ ] Package for distributions
- [ ] Release process
- [ ] Version numbering

---

## Notes

- Focus on SQLite driver first (simplest, no external server needed)
- Keep architecture clean - no shortcuts that break MVA pattern
- All file operations should be async
- Test with large result sets early
- Consider accessibility (screen readers, high contrast)

---

**Last Updated**: 2026-02-01
**Current Phase**: Phase 1 (Foundation)