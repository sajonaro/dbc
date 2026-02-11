# Database Commander (dbc)

A terminal-based database management tool inspired by Midnight Commander, focused on database operations across multiple database engines.

## Vision

A lightweight, keyboard-driven TUI for database exploration and management. Think SSMS but in your terminal, supporting PostgreSQL, MSSQL, SQLite, and MariaDB.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         main.zig                                │
│   Event Loop: render → poll → process → drain async → repeat    │
└───────────────────────────────┬─────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        ▼                       ▼                       ▼
┌───────────────┐      ┌───────────────┐      ┌───────────────┐
│    Views      │      │    State      │      │   Actions     │
│  (render fns) │◄─────│   (model.zig) │◄─────│  (mutations)  │
│   read-only   │      │ single source │      │ write state   │
└───────────────┘      └───────────────┘      └───────────────┘
                                │
                                ▼
                       ┌───────────────┐
                       │   DB Layer    │
                       │  (async ops)  │
                       └───────────────┘
```

### Core Principles

1. **State** is the single source of truth
2. **Views** are pure functions: `(State, Window) → pixels`
3. **Actions** are the only way to modify state
4. **Events** flow through one main handler
5. **Async** results arrive via queue, processed as events
6. **Cross-cutting** logic lives in orchestration layer, not in components

### What We Avoid

- Observer pattern (implicit, hard to trace)
- Component instances with lifecycle (unnecessary complexity)
- Virtual DOM / diffing (overkill for TUI)
- Bidirectional data flow (unpredictable)
- Global mutable singletons (untestable)




## Key Bindings Reference

### Global

| Key | Action |
|-----|--------|
| `Ctrl+Q` | Quit |
| `Tab` | Next panel |
| `Shift+Tab` | Previous panel |
| `F1` | Help |
| `F5` | Execute query |
| `Escape` | Close modal / Cancel query |

### Tree Panel

| Key | Action |
|-----|--------|
| `↑/↓` | Navigate |
| `←` | Collapse / Go to parent |
| `→` | Expand / Go to child |
| `Enter` | Activate (SELECT * for tables) |
| `Home/End` | First / Last |

### Editor Panel

| Key | Action |
|-----|--------|
| `↑/↓/←/→` | Move cursor |
| `Home/End` | Line start / end |
| `Ctrl+Z` | Undo |
| `Ctrl+Y` | Redo |
| `Ctrl+A` | Select all |
| `Ctrl+C` | Copy |
| `Ctrl+V` | Paste |
| `Ctrl+L` | Format SQL |

### Results Panel

| Key | Action |
|-----|--------|
| `↑/↓/←/→` | Navigate cells |
| `Home/End` | First / Last column |
| `Ctrl+Home/End` | First / Last row |
| `PgUp/PgDn` | Page up / down |
| `Enter` | View cell |
| `Ctrl+C` | Copy cell |
| `Ctrl+E` | Export |



## Summary

This architecture separates concerns cleanly:

| Layer | Responsibility | Knows About |
|-------|---------------|-------------|
| **Model** | Data structures | Nothing |
| **Views** | Rendering | Model (read-only), UI abstraction |
| **Actions** | State mutations | Model (read/write), DB |
| **Events** | Input/async definitions | Nothing |
| **UI** | ncurses wrapper | Nothing |
| **DB** | Database operations | Driver specifics |

Data flows one way:

```
Events → Actions → State → Views → Screen
```

No callbacks between components. No observer pattern. No hidden state. Just functions transforming data.