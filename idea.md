# Database Commander (dbc)

A terminal-based database management tool inspired by Midnight Commander, focused on database operations across multiple database engines.

## Vision

A lightweight, keyboard-driven TUI for database exploration and management. Think SSMS but in your terminal, supporting PostgreSQL, MSSQL, SQLite, and MariaDB.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         main.zig                                 │
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

---

## Layer 1: Model (State)

Pure data structures. No methods. No behavior. Just the shape of the application.

```zig
// model.zig
const std = @import("std");

pub const State = struct {
    // Connections
    connections: std.ArrayList(Connection),
    active_connection: ?usize,
    
    // Component states
    tree: TreeState,
    editor: EditorState,
    results: ResultsState,
    
    // UI state
    focus: Focus,
    modal: Modal,
    status: Status,
    
    // App state
    running: bool,
    theme: *const Theme,
    
    // Async
    async_queue: *AsyncQueue,
};

pub const Connection = struct {
    id: u32,
    name: []const u8,
    driver: DbDriver,
    host: []const u8,
    port: u16,
    database: []const u8,
    user: []const u8,
    connected: bool,
    handle: ?*anyopaque,
};

pub const DbDriver = enum {
    postgresql,
    mssql,
    sqlite,
    mariadb,
};

pub const Focus = enum {
    tree,
    editor,
    results,
    
    pub fn next(self: Focus) Focus {
        return switch (self) {
            .tree => .editor,
            .editor => .results,
            .results => .tree,
        };
    }
    
    pub fn prev(self: Focus) Focus {
        return switch (self) {
            .tree => .results,
            .editor => .tree,
            .results => .editor,
        };
    }
};

pub const Status = union(enum) {
    idle: []const u8,
    loading: []const u8,
    err: AppError,
};

pub const AppError = struct {
    message: []const u8,
    details: ?[]const u8,
    source: ErrorSource,
};

pub const ErrorSource = enum {
    database,
    filesystem,
    network,
    internal,
};
```

### Tree State

```zig
// model/tree.zig
pub const TreeState = struct {
    nodes: std.ArrayList(Node),
    selected: usize,
    scroll: usize,
    expanded: std.StringHashMap(bool),
};

pub const Node = struct {
    id: []const u8,
    label: []const u8,
    kind: NodeKind,
    depth: usize,
    parent_id: ?[]const u8,
    
    // For lazy loading
    children_loaded: bool,
};

pub const NodeKind = enum {
    connection,
    database,
    schema,
    table_folder,
    table,
    view,
    column,
    index,
    function,
    
    pub fn icon(self: NodeKind) []const u8 {
        return switch (self) {
            .connection => "⊡",
            .database => "⊟",
            .schema => "◫",
            .table_folder => "▤",
            .table => "▦",
            .view => "◱",
            .column => "│",
            .index => "⇅",
            .function => "ƒ",
        };
    }
};
```

### Editor State

```zig
// model/editor.zig
pub const EditorState = struct {
    buffer: std.ArrayList(u8),
    cursor: Position,
    scroll: Position,
    selection: ?Selection,
    
    // State flags
    modified: bool,
    executing: bool,
    
    // Undo/redo
    undo_stack: std.ArrayList(Snapshot),
    redo_stack: std.ArrayList(Snapshot),
};

pub const Position = struct {
    row: usize,
    col: usize,
};

pub const Selection = struct {
    start: Position,
    end: Position,
};

pub const Snapshot = struct {
    buffer: []const u8,
    cursor: Position,
};
```

### Results State

```zig
// model/results.zig
pub const ResultsState = struct {
    columns: []Column,
    rows: [][]?Cell,
    
    // Navigation
    selected_row: usize,
    selected_col: usize,
    scroll_row: usize,
    scroll_col: usize,
    
    // Metadata
    row_count: usize,
    execution_time_ms: u64,
    affected_rows: ?u64,
};

pub const Column = struct {
    name: []const u8,
    data_type: []const u8,
    nullable: bool,
    width: usize,
};

pub const Cell = struct {
    value: []const u8,
    is_null: bool,
};
```

### Modal State

```zig
// model/modal.zig
pub const Modal = union(enum) {
    none,
    confirm: ConfirmModal,
    input: InputModal,
    err: ErrorModal,
    connect: ConnectModal,
};

pub const ConfirmModal = struct {
    title: []const u8,
    message: []const u8,
    confirm_label: []const u8 = "OK",
    cancel_label: []const u8 = "Cancel",
    on_confirm: *const fn(*State) void,
    on_cancel: ?*const fn(*State) void = null,
};

pub const InputModal = struct {
    title: []const u8,
    prompt: []const u8,
    buffer: std.ArrayList(u8),
    cursor: usize,
    on_submit: *const fn(*State, []const u8) void,
};

pub const ErrorModal = struct {
    title: []const u8,
    message: []const u8,
    details: ?[]const u8,
};

pub const ConnectModal = struct {
    driver: DbDriver,
    host: std.ArrayList(u8),
    port: std.ArrayList(u8),
    database: std.ArrayList(u8),
    user: std.ArrayList(u8),
    password: std.ArrayList(u8),
    focused_field: ConnectField,
};

pub const ConnectField = enum {
    driver,
    host,
    port,
    database,
    user,
    password,
};
```

---

## Layer 2: Views (Rendering)

Pure functions that take state and produce output. Views never modify state.

### View Contract

```zig
// views/view.zig

/// Context passed to all views
pub const RenderContext = struct {
    state: *const State,
    theme: *const Theme,
};

/// All views follow this pattern:
/// fn render(ctx: RenderContext, win: *ui.Window) void
```

### Main View (Composition Root)

```zig
// views/main.zig
const std = @import("std");
const model = @import("../model.zig");
const ui = @import("../ui.zig");
const tree_view = @import("tree.zig");
const editor_view = @import("editor.zig");
const results_view = @import("results.zig");
const status_view = @import("status.zig");
const modal_view = @import("modal.zig");

pub fn render(ctx: RenderContext, screen: *ui.Screen) void {
    screen.clear();
    
    // Calculate layout
    const layout = calculateLayout(screen.width, screen.height);
    
    // Render main panels
    var tree_win = screen.region(layout.tree);
    tree_view.render(ctx, &tree_win, ctx.state.focus == .tree);
    
    var editor_win = screen.region(layout.editor);
    editor_view.render(ctx, &editor_win, ctx.state.focus == .editor);
    
    var results_win = screen.region(layout.results);
    results_view.render(ctx, &results_win, ctx.state.focus == .results);
    
    var status_win = screen.region(layout.status);
    status_view.render(ctx, &status_win);
    
    // Modal overlay (renders on top)
    if (ctx.state.modal != .none) {
        modal_view.render(ctx, screen);
    }
    
    screen.refresh();
}

const Layout = struct {
    tree: ui.Rect,
    editor: ui.Rect,
    results: ui.Rect,
    status: ui.Rect,
};

fn calculateLayout(width: usize, height: usize) Layout {
    const tree_width = 30;
    const status_height = 1;
    const content_height = height - status_height;
    const right_width = width - tree_width;
    const editor_height = content_height / 2;
    const results_height = content_height - editor_height;
    
    return Layout{
        .tree = .{ .x = 0, .y = 0, .w = tree_width, .h = content_height },
        .editor = .{ .x = tree_width, .y = 0, .w = right_width, .h = editor_height },
        .results = .{ .x = tree_width, .y = editor_height, .w = right_width, .h = results_height },
        .status = .{ .x = 0, .y = content_height, .w = width, .h = status_height },
    };
}
```

### Tree View

```zig
// views/tree.zig
const model = @import("../model.zig");
const ui = @import("../ui.zig");

pub fn render(ctx: RenderContext, win: *ui.Window, focused: bool) void {
    const tree = &ctx.state.tree;
    const theme = ctx.theme;
    
    // Border and title
    const border_style = if (focused) theme.border_focused else theme.border;
    win.border(border_style);
    win.title("Objects", border_style);
    
    // Calculate visible range
    const visible_height = win.height -| 2; // Account for border
    const visible_start = tree.scroll;
    const visible_end = @min(tree.scroll + visible_height, tree.nodes.items.len);
    
    // Render visible nodes
    var y: usize = 1;
    for (tree.nodes.items[visible_start..visible_end], visible_start..) |node, idx| {
        const is_selected = idx == tree.selected;
        const style = if (is_selected) theme.selection else theme.normal;
        
        // Indentation
        const indent = node.depth * 2;
        
        // Expand/collapse indicator
        const indicator = if (tree.expanded.get(node.id) orelse false) "▼ " else "▶ ";
        
        // Icon
        const icon = node.kind.icon();
        
        // Compose line
        win.moveTo(y, 1);
        win.printSpaces(indent, style);
        win.print(indicator, style);
        win.print(icon, style);
        win.print(" ", style);
        win.print(node.label, style);
        
        // Fill rest of line if selected
        if (is_selected) {
            win.fillToEnd(style);
        }
        
        y += 1;
    }
    
    // Scrollbar
    if (tree.nodes.items.len > visible_height) {
        renderScrollbar(win, tree.scroll, tree.nodes.items.len, visible_height, theme);
    }
}

fn renderScrollbar(win: *ui.Window, scroll: usize, total: usize, visible: usize, theme: *const Theme) void {
    const track_height = win.height -| 2;
    const thumb_height = @max(1, (visible * track_height) / total);
    const thumb_pos = (scroll * track_height) / total;
    
    var y: usize = 1;
    while (y <= track_height) : (y += 1) {
        const char = if (y >= thumb_pos and y < thumb_pos + thumb_height) "█" else "░";
        win.putChar(y, win.width - 1, char, theme.scrollbar);
    }
}
```

### Editor View

```zig
// views/editor.zig
const std = @import("std");
const model = @import("../model.zig");
const ui = @import("../ui.zig");
const syntax = @import("../sql/syntax.zig");

pub fn render(ctx: RenderContext, win: *ui.Window, focused: bool) void {
    const editor = &ctx.state.editor;
    const theme = ctx.theme;
    
    // Border
    const border_style = if (focused) theme.border_focused else theme.border;
    win.border(border_style);
    
    // Title with modified indicator
    const title = if (editor.modified) "Query *" else "Query";
    win.title(title, border_style);
    
    // Render content
    const content_width = win.width -| 7; // Border + line numbers
    const content_height = win.height -| 2;
    
    var lines = std.mem.split(u8, editor.buffer.items, "\n");
    var line_num: usize = 0;
    var y: usize = 1;
    
    while (lines.next()) |line| {
        if (line_num >= editor.scroll.row and y <= content_height) {
            // Line number
            win.print(y, 1, "{d:4} │", .{line_num + 1}, theme.line_number);
            
            // Line content with syntax highlighting
            renderLineWithSyntax(win, y, 7, line, editor.scroll.col, content_width, theme);
            
            y += 1;
        }
        line_num += 1;
    }
    
    // Cursor (only if focused)
    if (focused) {
        const cursor_y = editor.cursor.row - editor.scroll.row + 1;
        const cursor_x = editor.cursor.col - editor.scroll.col + 7;
        
        if (cursor_y > 0 and cursor_y <= content_height) {
            win.setCursor(cursor_y, cursor_x);
        }
    }
    
    // Executing indicator
    if (editor.executing) {
        win.print(0, win.width - 12, " Running... ", theme.status_loading);
    }
}

fn renderLineWithSyntax(
    win: *ui.Window,
    y: usize,
    x_start: usize,
    line: []const u8,
    scroll_col: usize,
    max_width: usize,
    theme: *const Theme,
) void {
    const tokens = syntax.tokenize(line);
    
    var x = x_start;
    var col: usize = 0;
    
    for (tokens) |token| {
        if (col + token.len <= scroll_col) {
            col += token.len;
            continue;
        }
        
        const style = switch (token.kind) {
            .keyword => theme.syntax_keyword,
            .string => theme.syntax_string,
            .number => theme.syntax_number,
            .comment => theme.syntax_comment,
            .operator => theme.syntax_operator,
            else => theme.normal,
        };
        
        const visible_start = if (col < scroll_col) scroll_col - col else 0;
        const visible_text = token.text[visible_start..];
        const chars_to_render = @min(visible_text.len, max_width - (x - x_start));
        
        if (chars_to_render > 0) {
            win.print(y, x, visible_text[0..chars_to_render], style);
            x += chars_to_render;
        }
        
        col += token.len;
        
        if (x - x_start >= max_width) break;
    }
}
```

### Results View

```zig
// views/results.zig
const std = @import("std");
const model = @import("../model.zig");
const ui = @import("../ui.zig");

pub fn render(ctx: RenderContext, win: *ui.Window, focused: bool) void {
    const results = &ctx.state.results;
    const theme = ctx.theme;
    
    // Border
    const border_style = if (focused) theme.border_focused else theme.border;
    win.border(border_style);
    
    // Title with row count
    var title_buf: [64]u8 = undefined;
    const title = std.fmt.bufPrint(&title_buf, "Results ({d} rows, {d}ms)", .{
        results.row_count,
        results.execution_time_ms,
    }) catch "Results";
    win.title(title, border_style);
    
    if (results.columns.len == 0) {
        win.print(win.height / 2, win.width / 2 - 8, "No results", theme.muted);
        return;
    }
    
    // Header row
    renderHeader(win, results, theme);
    
    // Data rows
    const data_height = win.height -| 4; // Border + header + separator
    const visible_end = @min(results.scroll_row + data_height, results.rows.len);
    
    var y: usize = 3;
    for (results.rows[results.scroll_row..visible_end], results.scroll_row..) |row, row_idx| {
        const is_selected = row_idx == results.selected_row;
        renderRow(win, y, row, results, is_selected, theme);
        y += 1;
    }
}

fn renderHeader(win: *ui.Window, results: *const model.ResultsState, theme: *const Theme) void {
    var x: usize = 1;
    
    for (results.columns[results.scroll_col..], results.scroll_col..) |col, col_idx| {
        if (x >= win.width - 1) break;
        
        const width = @min(col.width, win.width - x - 1);
        const is_selected = col_idx == results.selected_col;
        const style = if (is_selected) theme.header_selected else theme.header;
        
        win.printPadded(1, x, col.name, width, style);
        x += width + 1;
    }
    
    // Separator
    win.horizontalLine(2, 1, win.width - 2, theme.border);
}

fn renderRow(
    win: *ui.Window,
    y: usize,
    row: []?model.Cell,
    results: *const model.ResultsState,
    is_selected: bool,
    theme: *const Theme,
) void {
    var x: usize = 1;
    
    for (row[results.scroll_col..], results.scroll_col..) |maybe_cell, col_idx| {
        if (x >= win.width - 1) break;
        
        const col = results.columns[col_idx];
        const width = @min(col.width, win.width - x - 1);
        const is_cell_selected = is_selected and col_idx == results.selected_col;
        
        const style = blk: {
            if (is_cell_selected) break :blk theme.cell_selected;
            if (is_selected) break :blk theme.row_selected;
            break :blk theme.normal;
        };
        
        if (maybe_cell) |cell| {
            if (cell.is_null) {
                win.printPadded(y, x, "NULL", width, theme.null_value);
            } else {
                win.printPadded(y, x, cell.value, width, style);
            }
        } else {
            win.printPadded(y, x, "", width, style);
        }
        
        x += width + 1;
    }
}
```

### Status View

```zig
// views/status.zig
const model = @import("../model.zig");
const ui = @import("../ui.zig");

pub fn render(ctx: RenderContext, win: *ui.Window) void {
    const state = ctx.state;
    const theme = ctx.theme;
    
    win.fill(theme.status_bar);
    
    // Left: status message
    switch (state.status) {
        .idle => |msg| win.print(0, 1, msg, theme.status_bar),
        .loading => |msg| win.print(0, 1, "⏳ {s}", .{msg}, theme.status_loading),
        .err => |e| win.print(0, 1, "❌ {s}", .{e.message}, theme.status_error),
    }
    
    // Right: connection info
    if (state.active_connection) |idx| {
        const conn = state.connections.items[idx];
        const conn_info = std.fmt.bufPrint(&buf, "{s}@{s}", .{ conn.user, conn.host }) catch "Connected";
        win.printRight(0, conn_info, theme.status_bar);
    } else {
        win.printRight(0, "Not connected", theme.status_muted);
    }
    
    // Center: keybindings hint
    const hints = "F1 Help │ F5 Execute │ Tab Switch │ ^Q Quit";
    const center_x = (win.width - hints.len) / 2;
    win.print(0, center_x, hints, theme.status_muted);
}
```

### Modal View

```zig
// views/modal.zig
const model = @import("../model.zig");
const ui = @import("../ui.zig");

pub fn render(ctx: RenderContext, screen: *ui.Screen) void {
    const theme = ctx.theme;
    
    // Dim background
    screen.dim(theme.modal_overlay);
    
    switch (ctx.state.modal) {
        .none => {},
        .confirm => |m| renderConfirm(screen, m, theme),
        .input => |m| renderInput(screen, m, theme),
        .err => |m| renderError(screen, m, theme),
        .connect => |m| renderConnect(screen, m, theme),
    }
}

fn renderConfirm(screen: *ui.Screen, modal: model.ConfirmModal, theme: *const Theme) void {
    const width = 50;
    const height = 7;
    var win = screen.centered(width, height);
    
    win.fill(theme.modal_bg);
    win.border(theme.modal_border);
    win.title(modal.title, theme.modal_border);
    
    // Message
    win.printCentered(2, modal.message, theme.normal);
    
    // Buttons
    const buttons_y = height - 2;
    const ok_x = width / 2 - modal.confirm_label.len - 3;
    const cancel_x = width / 2 + 3;
    
    win.print(buttons_y, ok_x, "[ {s} ]", .{modal.confirm_label}, theme.button_primary);
    win.print(buttons_y, cancel_x, "[ {s} ]", .{modal.cancel_label}, theme.button);
}

fn renderError(screen: *ui.Screen, modal: model.ErrorModal, theme: *const Theme) void {
    const width = 60;
    const height = if (modal.details != null) 10 else 7;
    var win = screen.centered(width, height);
    
    win.fill(theme.modal_bg);
    win.border(theme.error_border);
    win.title(modal.title, theme.error_border);
    
    win.print(2, 2, "❌ {s}", .{modal.message}, theme.error_text);
    
    if (modal.details) |details| {
        win.print(4, 2, details, theme.muted);
    }
    
    win.printCentered(height - 2, "[ OK ]", theme.button_primary);
}
```

---

## Layer 3: Actions (State Mutations)

Actions are the only way to modify state. They receive state and events, perform mutations, and handle side effects.

### Event Definition

```zig
// events.zig
const model = @import("model.zig");
const db = @import("db.zig");

pub const Event = union(enum) {
    // User input
    key: KeyEvent,
    mouse: MouseEvent,
    resize: Size,
    
    // Async completions
    query_complete: db.QueryResult,
    connect_complete: db.ConnectResult,
    metadata_loaded: db.MetadataResult,
    
    // Timers
    tick,
};

pub const KeyEvent = struct {
    key: Key,
    modifiers: Modifiers,
    
    pub const Modifiers = packed struct {
        ctrl: bool = false,
        alt: bool = false,
        shift: bool = false,
    };
};

pub const Key = union(enum) {
    char: u8,
    F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12,
    up, down, left, right,
    home, end, page_up, page_down,
    enter, tab, escape, backspace, delete,
};

pub const MouseEvent = struct {
    x: usize,
    y: usize,
    button: MouseButton,
    kind: MouseKind,
};
```

### Main Event Router

```zig
// actions.zig
const model = @import("model.zig");
const events = @import("events.zig");
const tree_actions = @import("actions/tree.zig");
const editor_actions = @import("actions/editor.zig");
const results_actions = @import("actions/results.zig");
const modal_actions = @import("actions/modal.zig");
const db = @import("db.zig");

pub fn processEvent(state: *model.State, event: events.Event) void {
    switch (event) {
        .key => |k| routeKeyEvent(state, k),
        .mouse => |m| routeMouseEvent(state, m),
        .resize => |s| handleResize(state, s),
        .query_complete => |r| handleQueryComplete(state, r),
        .connect_complete => |r| handleConnectComplete(state, r),
        .metadata_loaded => |r| handleMetadataLoaded(state, r),
        .tick => {},
    }
}

fn routeKeyEvent(state: *model.State, key: events.KeyEvent) void {
    // 1. Global hotkeys (always handled first)
    if (handleGlobalKey(state, key)) return;
    
    // 2. Modal captures all input when open
    if (state.modal != .none) {
        modal_actions.handleKey(state, key);
        return;
    }
    
    // 3. Route to focused component
    switch (state.focus) {
        .tree => tree_actions.handleKey(state, key),
        .editor => editor_actions.handleKey(state, key),
        .results => results_actions.handleKey(state, key),
    }
}

fn handleGlobalKey(state: *model.State, key: events.KeyEvent) bool {
    // Ctrl+Q: Quit
    if (key.modifiers.ctrl and key.key == .char and key.key.char == 'q') {
        state.running = false;
        return true;
    }
    
    // Tab: Cycle focus
    if (key.key == .tab and state.modal == .none) {
        state.focus = if (key.modifiers.shift) state.focus.prev() else state.focus.next();
        return true;
    }
    
    // F1: Help
    if (key.key == .F1) {
        showHelp(state);
        return true;
    }
    
    // F5: Execute query
    if (key.key == .F5) {
        executeQuery(state);
        return true;
    }
    
    // Escape: Close modal or cancel
    if (key.key == .escape) {
        if (state.modal != .none) {
            state.modal = .none;
            return true;
        }
        if (state.editor.executing) {
            cancelQuery(state);
            return true;
        }
    }
    
    return false;
}

// ─────────────────────────────────────────────────────────────
// Cross-cutting actions (orchestration)
// ─────────────────────────────────────────────────────────────

fn executeQuery(state: *model.State) void {
    if (state.active_connection == null) {
        state.status = .{ .err = .{
            .message = "No active connection",
            .details = null,
            .source = .database,
        }};
        return;
    }
    
    const sql = state.editor.buffer.items;
    if (sql.len == 0) {
        state.status = .{ .idle = "Nothing to execute" };
        return;
    }
    
    state.editor.executing = true;
    state.status = .{ .loading = "Executing query..." };
    
    const conn = &state.connections.items[state.active_connection.?];
    db.executeAsync(conn.handle.?, sql, state.async_queue);
}

fn cancelQuery(state: *model.State) void {
    if (state.active_connection) |idx| {
        const conn = &state.connections.items[idx];
        db.cancel(conn.handle.?);
    }
    state.editor.executing = false;
    state.status = .{ .idle = "Query cancelled" };
}

fn handleQueryComplete(state: *model.State, result: db.QueryResult) void {
    state.editor.executing = false;
    
    switch (result) {
        .success => |data| {
            state.results = .{
                .columns = data.columns,
                .rows = data.rows,
                .selected_row = 0,
                .selected_col = 0,
                .scroll_row = 0,
                .scroll_col = 0,
                .row_count = data.rows.len,
                .execution_time_ms = data.time_ms,
                .affected_rows = data.affected,
            };
            
            var buf: [64]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "{d} rows returned", .{data.rows.len}) catch "Query complete";
            state.status = .{ .idle = msg };
            
            // Auto-focus results
            state.focus = .results;
        },
        .failure => |err| {
            state.status = .{ .err = .{
                .message = err.message,
                .details = err.details,
                .source = .database,
            }};
        },
    }
}

fn handleConnectComplete(state: *model.State, result: db.ConnectResult) void {
    switch (result) {
        .success => |handle| {
            var conn = &state.connections.items[state.connections.items.len - 1];
            conn.handle = handle;
            conn.connected = true;
            state.active_connection = state.connections.items.len - 1;
            state.modal = .none;
            state.status = .{ .idle = "Connected" };
            
            // Load initial tree
            loadDatabases(state);
        },
        .failure => |err| {
            state.status = .{ .err = .{
                .message = err.message,
                .details = null,
                .source = .network,
            }};
        },
    }
}

fn handleMetadataLoaded(state: *model.State, result: db.MetadataResult) void {
    switch (result) {
        .databases => |dbs| tree_actions.populateDatabases(state, dbs),
        .schemas => |schemas| tree_actions.populateSchemas(state, schemas),
        .tables => |tables| tree_actions.populateTables(state, tables),
        .columns => |cols| tree_actions.populateColumns(state, cols),
    }
}

fn loadDatabases(state: *model.State) void {
    if (state.active_connection) |idx| {
        const conn = &state.connections.items[idx];
        db.loadDatabasesAsync(conn.handle.?, state.async_queue);
        state.status = .{ .loading = "Loading databases..." };
    }
}
```

### Tree Actions

```zig
// actions/tree.zig
const model = @import("../model.zig");
const events = @import("../events.zig");
const db = @import("../db.zig");

pub fn handleKey(state: *model.State, key: events.KeyEvent) void {
    var tree = &state.tree;
    
    switch (key.key) {
        .up => moveUp(tree),
        .down => moveDown(tree),
        .left => collapse(state, tree),
        .right => expand(state, tree),
        .enter => activate(state, tree),
        .home => tree.selected = 0,
        .end => tree.selected = tree.nodes.items.len -| 1,
        else => {},
    }
    
    ensureVisible(tree);
}

fn moveUp(tree: *model.TreeState) void {
    if (tree.selected > 0) {
        tree.selected -= 1;
    }
}

fn moveDown(tree: *model.TreeState) void {
    if (tree.selected < tree.nodes.items.len -| 1) {
        tree.selected += 1;
    }
}

fn expand(state: *model.State, tree: *model.TreeState) void {
    if (tree.nodes.items.len == 0) return;
    
    const node = &tree.nodes.items[tree.selected];
    
    if (tree.expanded.get(node.id) orelse false) {
        // Already expanded, move to first child
        moveDown(tree);
    } else {
        // Expand
        tree.expanded.put(node.id, true) catch {};
        
        // Load children if needed
        if (!node.children_loaded) {
            loadChildren(state, node);
        }
    }
}

fn collapse(state: *model.State, tree: *model.TreeState) void {
    if (tree.nodes.items.len == 0) return;
    
    const node = &tree.nodes.items[tree.selected];
    
    if (tree.expanded.get(node.id) orelse false) {
        // Collapse this node
        tree.expanded.put(node.id, false) catch {};
    } else if (node.parent_id) |parent_id| {
        // Move to parent
        for (tree.nodes.items, 0..) |n, i| {
            if (std.mem.eql(u8, n.id, parent_id)) {
                tree.selected = i;
                break;
            }
        }
    }
}

fn activate(state: *model.State, tree: *model.TreeState) void {
    if (tree.nodes.items.len == 0) return;
    
    const node = &tree.nodes.items[tree.selected];
    
    switch (node.kind) {
        .table, .view => {
            // Generate SELECT * and execute
            const sql = std.fmt.allocPrint(
                state.allocator,
                "SELECT * FROM {s} LIMIT 100",
                .{node.label},
            ) catch return;
            
            state.editor.buffer.clearRetainingCapacity();
            state.editor.buffer.appendSlice(sql) catch {};
            state.editor.cursor = .{ .row = 0, .col = 0 };
            state.editor.modified = true;
            
            // Execute immediately
            executeQuery(state);
        },
        else => {
            // Toggle expand
            const expanded = tree.expanded.get(node.id) orelse false;
            tree.expanded.put(node.id, !expanded) catch {};
            
            if (!expanded and !node.children_loaded) {
                loadChildren(state, node);
            }
        },
    }
}

fn loadChildren(state: *model.State, node: *model.Node) void {
    if (state.active_connection == null) return;
    
    const conn = &state.connections.items[state.active_connection.?];
    
    switch (node.kind) {
        .connection, .database => {
            db.loadSchemasAsync(conn.handle.?, node.label, state.async_queue);
        },
        .schema => {
            db.loadTablesAsync(conn.handle.?, node.label, state.async_queue);
        },
        .table => {
            db.loadColumnsAsync(conn.handle.?, node.label, state.async_queue);
        },
        else => {},
    }
    
    node.children_loaded = true;
    state.status = .{ .loading = "Loading..." };
}

fn ensureVisible(tree: *model.TreeState) void {
    const visible_height = 20; // Will be passed from view in real impl
    
    if (tree.selected < tree.scroll) {
        tree.scroll = tree.selected;
    } else if (tree.selected >= tree.scroll + visible_height) {
        tree.scroll = tree.selected - visible_height + 1;
    }
}

// Called from main actions when metadata loads
pub fn populateDatabases(state: *model.State, databases: []db.Database) void {
    // Add database nodes to tree
    for (databases) |database| {
        state.tree.nodes.append(.{
            .id = database.name,
            .label = database.name,
            .kind = .database,
            .depth = 1,
            .parent_id = null,
            .children_loaded = false,
        }) catch {};
    }
    state.status = .{ .idle = "Ready" };
}

pub fn populateSchemas(state: *model.State, schemas: []db.Schema) void {
    // Similar implementation
}

pub fn populateTables(state: *model.State, tables: []db.Table) void {
    // Similar implementation
}

pub fn populateColumns(state: *model.State, columns: []db.Column) void {
    // Similar implementation
}
```

### Editor Actions

```zig
// actions/editor.zig
const std = @import("std");
const model = @import("../model.zig");
const events = @import("../events.zig");

pub fn handleKey(state: *model.State, key: events.KeyEvent) void {
    var editor = &state.editor;
    
    // Ctrl shortcuts
    if (key.modifiers.ctrl) {
        switch (key.key) {
            .char => |c| switch (c) {
                'z' => undo(editor),
                'y' => redo(editor),
                'a' => selectAll(editor),
                'c' => copy(editor),
                'v' => paste(state, editor),
                'l' => formatSql(editor),
                else => {},
            },
            else => {},
        }
        return;
    }
    
    switch (key.key) {
        .char => |c| insertChar(editor, c),
        .enter => insertChar(editor, '\n'),
        .backspace => deleteBackward(editor),
        .delete => deleteForward(editor),
        .up => moveCursor(editor, .up),
        .down => moveCursor(editor, .down),
        .left => moveCursor(editor, .left),
        .right => moveCursor(editor, .right),
        .home => editor.cursor.col = 0,
        .end => moveToLineEnd(editor),
        else => {},
    }
}

fn insertChar(editor: *model.EditorState, char: u8) void {
    saveSnapshot(editor);
    
    const pos = cursorToIndex(editor);
    editor.buffer.insert(pos, char) catch return;
    
    if (char == '\n') {
        editor.cursor.row += 1;
        editor.cursor.col = 0;
    } else {
        editor.cursor.col += 1;
    }
    
    editor.modified = true;
}

fn deleteBackward(editor: *model.EditorState) void {
    if (editor.cursor.col == 0 and editor.cursor.row == 0) return;
    
    saveSnapshot(editor);
    
    if (editor.cursor.col > 0) {
        editor.cursor.col -= 1;
    } else {
        editor.cursor.row -= 1;
        editor.cursor.col = getLineLength(editor, editor.cursor.row);
    }
    
    const pos = cursorToIndex(editor);
    _ = editor.buffer.orderedRemove(pos);
    
    editor.modified = true;
}

fn moveCursor(editor: *model.EditorState, direction: enum { up, down, left, right }) void {
    switch (direction) {
        .up => {
            if (editor.cursor.row > 0) {
                editor.cursor.row -= 1;
                editor.cursor.col = @min(editor.cursor.col, getLineLength(editor, editor.cursor.row));
            }
        },
        .down => {
            const line_count = countLines(editor);
            if (editor.cursor.row < line_count -| 1) {
                editor.cursor.row += 1;
                editor.cursor.col = @min(editor.cursor.col, getLineLength(editor, editor.cursor.row));
            }
        },
        .left => {
            if (editor.cursor.col > 0) {
                editor.cursor.col -= 1;
            } else if (editor.cursor.row > 0) {
                editor.cursor.row -= 1;
                editor.cursor.col = getLineLength(editor, editor.cursor.row);
            }
        },
        .right => {
            const line_len = getLineLength(editor, editor.cursor.row);
            if (editor.cursor.col < line_len) {
                editor.cursor.col += 1;
            } else if (editor.cursor.row < countLines(editor) -| 1) {
                editor.cursor.row += 1;
                editor.cursor.col = 0;
            }
        },
    }
    
    ensureVisible(editor);
}

fn saveSnapshot(editor: *model.EditorState) void {
    // Clear redo stack on new edit
    editor.redo_stack.clearRetainingCapacity();
    
    // Save current state
    editor.undo_stack.append(.{
        .buffer = editor.allocator.dupe(u8, editor.buffer.items) catch return,
        .cursor = editor.cursor,
    }) catch {};
    
    // Limit undo history
    if (editor.undo_stack.items.len > 100) {
        const old = editor.undo_stack.orderedRemove(0);
        editor.allocator.free(old.buffer);
    }
}

fn undo(editor: *model.EditorState) void {
    if (editor.undo_stack.items.len == 0) return;
    
    // Save current to redo
    editor.redo_stack.append(.{
        .buffer = editor.allocator.dupe(u8, editor.buffer.items) catch return,
        .cursor = editor.cursor,
    }) catch {};
    
    // Restore previous
    const snapshot = editor.undo_stack.pop();
    editor.buffer.clearRetainingCapacity();
    editor.buffer.appendSlice(snapshot.buffer) catch {};
    editor.cursor = snapshot.cursor;
    editor.allocator.free(snapshot.buffer);
    
    editor.modified = true;
}

fn redo(editor: *model.EditorState) void {
    if (editor.redo_stack.items.len == 0) return;
    
    // Save current to undo
    editor.undo_stack.append(.{
        .buffer = editor.allocator.dupe(u8, editor.buffer.items) catch return,
        .cursor = editor.cursor,
    }) catch {};
    
    // Restore redo
    const snapshot = editor.redo_stack.pop();
    editor.buffer.clearRetainingCapacity();
    editor.buffer.appendSlice(snapshot.buffer) catch {};
    editor.cursor = snapshot.cursor;
    editor.allocator.free(snapshot.buffer);
    
    editor.modified = true;
}

// Helper functions
fn cursorToIndex(editor: *model.EditorState) usize {
    var idx: usize = 0;
    var row: usize = 0;
    
    for (editor.buffer.items) |char| {
        if (row == editor.cursor.row) break;
        if (char == '\n') row += 1;
        idx += 1;
    }
    
    return idx + editor.cursor.col;
}

fn getLineLength(editor: *model.EditorState, row: usize) usize {
    var current_row: usize = 0;
    var len: usize = 0;
    
    for (editor.buffer.items) |char| {
        if (current_row == row) {
            if (char == '\n') break;
            len += 1;
        } else if (char == '\n') {
            current_row += 1;
        }
    }
    
    return len;
}

fn countLines(editor: *model.EditorState) usize {
    var count: usize = 1;
    for (editor.buffer.items) |char| {
        if (char == '\n') count += 1;
    }
    return count;
}

fn ensureVisible(editor: *model.EditorState) void {
    const visible_height = 15; // Will be dynamic
    const visible_width = 60;
    
    if (editor.cursor.row < editor.scroll.row) {
        editor.scroll.row = editor.cursor.row;
    } else if (editor.cursor.row >= editor.scroll.row + visible_height) {
        editor.scroll.row = editor.cursor.row - visible_height + 1;
    }
    
    if (editor.cursor.col < editor.scroll.col) {
        editor.scroll.col = editor.cursor.col;
    } else if (editor.cursor.col >= editor.scroll.col + visible_width) {
        editor.scroll.col = editor.cursor.col - visible_width + 1;
    }
}
```

### Results Actions

```zig
// actions/results.zig
const model = @import("../model.zig");
const events = @import("../events.zig");

pub fn handleKey(state: *model.State, key: events.KeyEvent) void {
    var results = &state.results;
    
    if (results.rows.len == 0) return;
    
    switch (key.key) {
        .up => moveUp(results),
        .down => moveDown(results),
        .left => moveLeft(results),
        .right => moveRight(results),
        .home => {
            if (key.modifiers.ctrl) {
                results.selected_row = 0;
            }
            results.selected_col = 0;
        },
        .end => {
            if (key.modifiers.ctrl) {
                results.selected_row = results.rows.len -| 1;
            }
            results.selected_col = results.columns.len -| 1;
        },
        .page_up => pageUp(results),
        .page_down => pageDown(results),
        .enter => viewCell(state, results),
        .char => |c| {
            if (key.modifiers.ctrl) {
                switch (c) {
                    'c' => copyCell(state, results),
                    'e' => exportResults(state, results),
                    else => {},
                }
            }
        },
        else => {},
    }
    
    ensureVisible(results);
}

fn moveUp(results: *model.ResultsState) void {
    if (results.selected_row > 0) {
        results.selected_row -= 1;
    }
}

fn moveDown(results: *model.ResultsState) void {
    if (results.selected_row < results.rows.len -| 1) {
        results.selected_row += 1;
    }
}

fn moveLeft(results: *model.ResultsState) void {
    if (results.selected_col > 0) {
        results.selected_col -= 1;
    }
}

fn moveRight(results: *model.ResultsState) void {
    if (results.selected_col < results.columns.len -| 1) {
        results.selected_col += 1;
    }
}

fn pageUp(results: *model.ResultsState) void {
    const page_size = 20;
    results.selected_row -|= page_size;
}

fn pageDown(results: *model.ResultsState) void {
    const page_size = 20;
    results.selected_row = @min(results.selected_row + page_size, results.rows.len -| 1);
}

fn viewCell(state: *model.State, results: *model.ResultsState) void {
    const row = results.rows[results.selected_row];
    const cell = row[results.selected_col];
    
    if (cell) |c| {
        state.modal = .{
            .err = .{  // Reusing error modal for cell view
                .title = results.columns[results.selected_col].name,
                .message = if (c.is_null) "NULL" else c.value,
                .details = null,
            },
        };
    }
}

fn copyCell(state: *model.State, results: *model.ResultsState) void {
    const row = results.rows[results.selected_row];
    const cell = row[results.selected_col];
    
    if (cell) |c| {
        // Copy to clipboard (platform-specific)
        // For now, just update status
        state.status = .{ .idle = "Copied to clipboard" };
    }
}

fn exportResults(state: *model.State, results: *model.ResultsState) void {
    state.modal = .{
        .input = .{
            .title = "Export Results",
            .prompt = "Filename:",
            .buffer = std.ArrayList(u8).init(state.allocator),
            .cursor = 0,
            .on_submit = doExport,
        },
    };
}

fn doExport(state: *model.State, filename: []const u8) void {
    // Export logic
    state.modal = .none;
    state.status = .{ .idle = "Exported to " ++ filename };
}

fn ensureVisible(results: *model.ResultsState) void {
    const visible_height = 15;
    const visible_width = 5; // columns
    
    if (results.selected_row < results.scroll_row) {
        results.scroll_row = results.selected_row;
    } else if (results.selected_row >= results.scroll_row + visible_height) {
        results.scroll_row = results.selected_row - visible_height + 1;
    }
    
    if (results.selected_col < results.scroll_col) {
        results.scroll_col = results.selected_col;
    } else if (results.selected_col >= results.scroll_col + visible_width) {
        results.scroll_col = results.selected_col - visible_width + 1;
    }
}
```

---

## Layer 4: Async Infrastructure

Handles background operations without blocking the UI.

```zig
// async.zig
const std = @import("std");
const events = @import("events.zig");

pub const AsyncQueue = struct {
    mutex: std.Thread.Mutex,
    events: std.ArrayList(events.Event),
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) AsyncQueue {
        return .{
            .mutex = .{},
            .events = std.ArrayList(events.Event).init(allocator),
            .allocator = allocator,
        };
    }
    
    pub fn push(self: *AsyncQueue, event: events.Event) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.events.append(event) catch {};
    }
    
    pub fn drain(self: *AsyncQueue) []events.Event {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        if (self.events.items.len == 0) return &.{};
        
        const items = self.events.toOwnedSlice() catch return &.{};
        return items;
    }
};
```

---

## Layer 5: Main Loop

The glue that ties everything together.

```zig
// main.zig
const std = @import("std");
const model = @import("model.zig");
const events = @import("events.zig");
const actions = @import("actions.zig");
const main_view = @import("views/main.zig");
const ui = @import("ui.zig");
const input = @import("input.zig");
const async_mod = @import("async.zig");
const theme = @import("theme.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Initialize UI
    var screen = try ui.Screen.init();
    defer screen.deinit();
    
    // Initialize async queue
    var async_queue = async_mod.AsyncQueue.init(allocator);
    
    // Initialize state
    var state = model.State{
        .connections = std.ArrayList(model.Connection).init(allocator),
        .active_connection = null,
        .tree = .{
            .nodes = std.ArrayList(model.Node).init(allocator),
            .selected = 0,
            .scroll = 0,
            .expanded = std.StringHashMap(bool).init(allocator),
        },
        .editor = .{
            .buffer = std.ArrayList(u8).init(allocator),
            .cursor = .{ .row = 0, .col = 0 },
            .scroll = .{ .row = 0, .col = 0 },
            .selection = null,
            .modified = false,
            .executing = false,
            .undo_stack = std.ArrayList(model.Snapshot).init(allocator),
            .redo_stack = std.ArrayList(model.Snapshot).init(allocator),
        },
        .results = .{
            .columns = &.{},
            .rows = &.{},
            .selected_row = 0,
            .selected_col = 0,
            .scroll_row = 0,
            .scroll_col = 0,
            .row_count = 0,
            .execution_time_ms = 0,
            .affected_rows = null,
        },
        .focus = .tree,
        .modal = .none,
        .status = .{ .idle = "Welcome to Database Commander" },
        .running = true,
        .theme = &theme.dark,
        .async_queue = &async_queue,
    };
    
    // Main loop
    while (state.running) {
        // 1. Render
        const ctx = main_view.RenderContext{
            .state = &state,
            .theme = state.theme,
        };
        main_view.render(ctx, &screen);
        
        // 2. Poll for input (with timeout for async)
        if (input.poll(50)) |event| {
            actions.processEvent(&state, event);
        }
        
        // 3. Process async results
        for (async_queue.drain()) |event| {
            actions.processEvent(&state, event);
        }
    }
}
```

---

## Theming

```zig
// theme.zig
pub const Theme = struct {
    // Base colors
    normal: Style,
    muted: Style,
    
    // Borders
    border: Style,
    border_focused: Style,
    
    // Selection
    selection: Style,
    
    // Status bar
    status_bar: Style,
    status_loading: Style,
    status_error: Style,
    status_muted: Style,
    
    // Results grid
    header: Style,
    header_selected: Style,
    row_selected: Style,
    cell_selected: Style,
    null_value: Style,
    
    // Syntax highlighting
    syntax_keyword: Style,
    syntax_string: Style,
    syntax_number: Style,
    syntax_comment: Style,
    syntax_operator: Style,
    
    // Modal
    modal_bg: Style,
    modal_border: Style,
    modal_overlay: Style,
    
    // Buttons
    button: Style,
    button_primary: Style,
    
    // Editor
    line_number: Style,
    
    // Scrollbar
    scrollbar: Style,
    
    // Error
    error_border: Style,
    error_text: Style,
};

pub const Style = struct {
    fg: Color,
    bg: Color,
    bold: bool = false,
    underline: bool = false,
    reverse: bool = false,
};

pub const Color = enum {
    default,
    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,
    bright_black,
    bright_red,
    bright_green,
    bright_yellow,
    bright_blue,
    bright_magenta,
    bright_cyan,
    bright_white,
};

pub const dark = Theme{
    .normal = .{ .fg = .white, .bg = .default },
    .muted = .{ .fg = .bright_black, .bg = .default },
    
    .border = .{ .fg = .bright_black, .bg = .default },
    .border_focused = .{ .fg = .cyan, .bg = .default },
    
    .selection = .{ .fg = .black, .bg = .cyan },
    
    .status_bar = .{ .fg = .black, .bg = .white },
    .status_loading = .{ .fg = .black, .bg = .yellow },
    .status_error = .{ .fg = .white, .bg = .red },
    .status_muted = .{ .fg = .bright_black, .bg = .white },
    
    .header = .{ .fg = .cyan, .bg = .default, .bold = true },
    .header_selected = .{ .fg = .black, .bg = .cyan, .bold = true },
    .row_selected = .{ .fg = .white, .bg = .bright_black },
    .cell_selected = .{ .fg = .black, .bg = .cyan },
    .null_value = .{ .fg = .bright_black, .bg = .default },
    
    .syntax_keyword = .{ .fg = .magenta, .bg = .default, .bold = true },
    .syntax_string = .{ .fg = .green, .bg = .default },
    .syntax_number = .{ .fg = .yellow, .bg = .default },
    .syntax_comment = .{ .fg = .bright_black, .bg = .default },
    .syntax_operator = .{ .fg = .cyan, .bg = .default },
    
    .modal_bg = .{ .fg = .white, .bg = .black },
    .modal_border = .{ .fg = .cyan, .bg = .black },
    .modal_overlay = .{ .fg = .default, .bg = .default },
    
    .button = .{ .fg = .white, .bg = .bright_black },
    .button_primary = .{ .fg = .black, .bg = .cyan },
    
    .line_number = .{ .fg = .bright_black, .bg = .default },
    
    .scrollbar = .{ .fg = .bright_black, .bg = .default },
    
    .error_border = .{ .fg = .red, .bg = .default },
    .error_text = .{ .fg = .red, .bg = .default },
};

pub const light = Theme{
    // Light theme variant...
};
```

---

## File Structure

```
dbc/
├── build.zig
├── build.zig.zon
├── src/
│   ├── main.zig                 # Entry point and main loop
│   │
│   ├── model.zig                # Root state definition
│   ├── model/
│   │   ├── tree.zig             # Tree state
│   │   ├── editor.zig           # Editor state
│   │   ├── results.zig          # Results state
│   │   └── modal.zig            # Modal state
│   │
│   ├── views/
│   │   ├── view.zig             # RenderContext, common types
│   │   ├── main.zig             # Main view composition
│   │   ├── tree.zig             # Tree view
│   │   ├── editor.zig           # Editor view
│   │   ├── results.zig          # Results view
│   │   ├── status.zig           # Status bar view
│   │   └── modal.zig            # Modal views
│   │
│   ├── actions.zig              # Main event router
│   ├── actions/
│   │   ├── tree.zig             # Tree actions
│   │   ├── editor.zig           # Editor actions
│   │   ├── results.zig          # Results actions
│   │   └── modal.zig            # Modal actions
│   │
│   ├── events.zig               # Event definitions
│   ├── async.zig                # Async queue
│   ├── theme.zig                # Theme definitions
│   │
│   ├── ui/
│   │   ├── ui.zig               # Screen, Window abstractions
│   │   ├── ncurses.zig          # ncurses bindings
│   │   └── input.zig            # Input handling
│   │
│   ├── db/
│   │   ├── db.zig               # Unified DB API
│   │   ├── types.zig            # DB types
│   │   └── drivers/
│   │       ├── postgresql.zig
│   │       ├── sqlite.zig
│   │       ├── mssql.zig
│   │       └── mariadb.zig
│   │
│   └── sql/
│       ├── syntax.zig           # SQL tokenizer
│       ├── formatter.zig        # SQL formatter
│       └── completer.zig        # Autocomplete
│
└── tests/
    ├── model_tests.zig
    ├── action_tests.zig
    └── view_tests.zig
```

---

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

---

## Implementation Phases

### Phase 1: Skeleton
- [ ] Main loop
- [ ] State structure
- [ ] Basic ncurses wrapper
- [ ] Render empty panels
- [ ] Keyboard input

### Phase 2: Tree
- [ ] Tree view rendering
- [ ] Tree navigation
- [ ] Expand/collapse
- [ ] Static test data

### Phase 3: Editor
- [ ] Text buffer
- [ ] Cursor movement
- [ ] Insert/delete
- [ ] Undo/redo

### Phase 4: SQLite
- [ ] SQLite driver
- [ ] Connect
- [ ] List tables
- [ ] Execute query

### Phase 5: Results
- [ ] Results grid
- [ ] Cell navigation
- [ ] Scrolling
- [ ] Copy cell

### Phase 6: Integration
- [ ] Tree loads from DB
- [ ] Query execution flow
- [ ] Status updates
- [ ] Error handling

### Phase 7: More Drivers
- [ ] PostgreSQL
- [ ] MariaDB
- [ ] MSSQL (ODBC)

### Phase 8: Polish
- [ ] Syntax highlighting
- [ ] Themes
- [ ] Config file
- [ ] Help screen

---

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