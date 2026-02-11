const std = @import("std");
const model = @import("model.zig");
const events = @import("events.zig");
const tree_actions = @import("actions/tree.zig");
const editor_actions = @import("actions/editor.zig");
const results_actions = @import("actions/results.zig");
const modal_actions = @import("actions/modal.zig");

pub fn processEvent(state: *model.State, event: events.Event) void {
    switch (event) {
        .key => |key_event| processKeyEvent(state, key_event),
        .mouse => |mouse_event| processMouseEvent(state, mouse_event),
        .resize => |size| processResize(state, size),
        .query_complete => |result| processQueryComplete(state, result),
        .query_error => |err| processQueryError(state, err),
        .connect_complete => |result| processConnectComplete(state, result),
        .metadata_loaded => |result| processMetadataLoaded(state, result),
        .tick => processTick(state),
    }
}

fn processKeyEvent(state: *model.State, key_event: events.KeyEvent) void {
    // If modal is open, route to modal handler first
    if (state.modal != .none) {
        modal_actions.handleKey(state, key_event);
        return;
    }

    // Global hotkeys (always active)
    if (handleGlobalHotkeys(state, key_event)) {
        return;
    }

    // Route to focused component
    switch (state.focus) {
        .tree => tree_actions.handleKey(state, key_event),
        .editor => editor_actions.handleKey(state, key_event),
        .results => results_actions.handleKey(state, key_event),
    }
}

fn handleGlobalHotkeys(state: *model.State, key_event: events.KeyEvent) bool {
    // Check for Ctrl+Q (quit)
    if (key_event.modifiers.ctrl and key_event.key == .char and key_event.key.char == 'q') {
        state.running = false;
        return true;
    }

    // Ctrl+S - save file
    if (key_event.modifiers.ctrl and key_event.key == .char and key_event.key.char == 's') {
        handleSave(state);
        return true;
    }

    // Tab or Ctrl+I - cycle focus (Ctrl+I works better in WSL/some terminals)
    const is_tab = key_event.key == .tab;
    const is_ctrl_i = key_event.modifiers.ctrl and key_event.key == .char and key_event.key.char == 'i';

    if (is_tab or is_ctrl_i) {
        state.focus = switch (state.focus) {
            .tree => .editor,
            .editor => .results,
            .results => .tree,
        };
        return true;
    }

    // F1 or ? - help
    const is_f1 = key_event.key == .F1;
    const is_help = key_event.key == .char and key_event.key.char == '?';

    if (is_f1 or is_help) {
        state.status = .{ .idle = "Help: Tab=Switch, F5/Ctrl+E=Run, Ctrl+S=Save, ?=Help, Ctrl+Q=Quit" };
        return true;
    }

    // F5 - execute query
    if (key_event.key == .F5) {
        executeQuery(state);
        return true;
    }

    // Escape - close modal or clear status
    if (key_event.key == .escape) {
        if (state.modal != .none) {
            state.modal = .none;
        } else {
            state.status = .{ .idle = "Ready" };
        }
        return true;
    }

    return false;
}

fn processMouseEvent(state: *model.State, mouse_event: events.MouseEvent) void {
    // TODO: Implement mouse event handling
    _ = state;
    _ = mouse_event;
}

fn processResize(state: *model.State, size: events.Size) void {
    // Terminal resize is handled automatically by ncurses
    // We just update our internal state if needed
    _ = state;
    _ = size;
}

fn processQueryComplete(state: *model.State, result: events.QueryCompleteEvent) void {
    state.editor.executing = false;

    // Free old results before allocating new ones
    const allocator = state.editor.allocator;

    // Free old columns (including their owned strings)
    if (state.results.columns.len > 0) {
        for (state.results.columns) |col| {
            allocator.free(col.name);
            allocator.free(col.data_type);
        }
        allocator.free(state.results.columns);
    }

    // Free old rows and their cells
    for (state.results.rows) |row| {
        for (row) |cell_opt| {
            if (cell_opt) |cell| {
                if (!cell.is_null) {
                    allocator.free(cell.value);
                }
            }
        }
        allocator.free(row);
    }
    if (state.results.rows.len > 0) {
        allocator.free(state.results.rows);
    }

    // Convert db columns to ColumnDisplay
    // Note: ColumnDisplay.fromDbColumn just copies pointers, so we transfer ownership
    // of the column name and data_type strings to the display columns
    var display_columns = allocator.alloc(model.results.ColumnDisplay, result.columns.len) catch {
        state.status = .{ .err = .{
            .message = "Failed to allocate memory for results",
            .details = null,
            .source = .internal,
        } };
        return;
    };

    for (result.columns, 0..) |col, i| {
        display_columns[i] = model.results.ColumnDisplay.fromDbColumn(col);
    }

    // Memory leak fix: Free the columns array itself (but not the strings inside,
    // as they're now owned by ColumnDisplay)
    if (result.columns.len > 0) {
        allocator.free(result.columns);
    }

    // Update results view (transfer ownership of rows and column strings to state)
    state.results.columns = display_columns;
    state.results.rows = result.rows;
    state.results.row_count = result.rows.len;
    state.results.execution_time_ms = result.time_ms;
    state.results.affected_rows = result.affected;
    state.results.selected_row = 0;
    state.results.selected_col = 0;
    state.results.scroll_row = 0;
    state.results.scroll_col = 0;

    // Memory leak fix: Use a static buffer for status message to avoid allocation
    // This prevents the need to track and free dynamically allocated status messages
    if (result.affected) |affected| {
        var buf: [256]u8 = undefined;
        const status_msg = std.fmt.bufPrint(&buf, "Query executed: {d} rows affected ({d}ms)", .{ affected, result.time_ms }) catch "Query executed";
        // Since bufPrint returns a slice into our stack buffer, we need to keep it simple
        // Just use a static message that doesn't need allocation
        _ = status_msg;
        state.status = .{ .idle = "Query executed successfully" };
    } else {
        var buf: [256]u8 = undefined;
        const status_msg = std.fmt.bufPrint(&buf, "Query executed: {d} rows returned ({d}ms)", .{ result.rows.len, result.time_ms }) catch "Query executed";
        _ = status_msg;
        state.status = .{ .idle = "Query executed successfully" };
    }
}

fn processQueryError(state: *model.State, err: events.QueryErrorEvent) void {
    state.editor.executing = false;
    state.status = .{ .err = .{
        .message = err.message,
        .details = null,
        .source = .database,
    } };
}

fn processConnectComplete(state: *model.State, result: events.ConnectCompleteEvent) void {
    if (result.success) {
        state.status = .{ .idle = "Connected successfully" };
    } else {
        state.status = .{ .err = .{
            .message = result.error_message orelse "Connection failed",
            .details = null,
            .source = .database,
        } };
    }
}

fn processMetadataLoaded(state: *model.State, result: events.MetadataLoadedEvent) void {
    // TODO: Update tree view with metadata based on result.kind
    _ = state;
    _ = result;
}

fn processTick(state: *model.State) void {
    // TODO: Handle periodic tasks (animations, timeouts, etc.)
    _ = state;
}

fn handleSave(state: *model.State) void {
    if (state.editor.current_file) |file_path| {
        // File already has a path, save directly
        saveFile(state, file_path);
    } else {
        // New file, show save-as modal
        showSaveAsModal(state);
    }
}

fn saveFile(state: *model.State, file_path: []const u8) void {
    const allocator = state.editor.allocator;

    // Write buffer to file
    const file = std.fs.cwd().createFile(file_path, .{}) catch |err| {
        const err_msg = std.fmt.allocPrint(allocator, "Failed to save file: {}", .{err}) catch "Failed to save file";
        state.status = .{ .err = .{
            .message = err_msg,
            .details = null,
            .source = .filesystem,
        } };
        return;
    };
    defer file.close();

    file.writeAll(state.editor.buffer.items) catch |err| {
        const err_msg = std.fmt.allocPrint(allocator, "Failed to write file: {}", .{err}) catch "Failed to write file";
        state.status = .{ .err = .{
            .message = err_msg,
            .details = null,
            .source = .filesystem,
        } };
        return;
    };

    // Update editor state
    state.editor.modified = false;

    // If this was a new file, store the path
    if (state.editor.current_file == null) {
        state.editor.current_file = allocator.dupe(u8, file_path) catch null;
    }

    state.status = .{ .idle = "File saved successfully" };
}

fn showSaveAsModal(state: *model.State) void {
    const allocator = state.editor.allocator;

    // Generate default filename with timestamp
    const timestamp = std.time.timestamp();
    const default_name = std.fmt.allocPrint(allocator, "query_{d}.sql", .{timestamp}) catch "query.sql";
    defer {
        // Only free if it was allocated (not the fallback string literal)
        if (!std.mem.eql(u8, default_name, "query.sql")) {
            allocator.free(default_name);
        }
    }

    var buffer: std.ArrayList(u8) = .empty;
    buffer.appendSlice(allocator, default_name) catch {};

    state.modal = .{ .input = .{
        .title = "Save As",
        .prompt = "Filename:",
        .buffer = buffer,
        .cursor = buffer.items.len,
        .on_submit = onSaveAsSubmit,
    } };
}

fn onSaveAsSubmit(state: *model.State, filename: []const u8) void {
    const allocator = state.editor.allocator;

    if (filename.len == 0) {
        state.status = .{ .err = .{
            .message = "Filename cannot be empty",
            .details = null,
            .source = .filesystem,
        } };
        return;
    }

    saveFile(state, filename);

    // Clean up modal buffer
    if (state.modal == .input) {
        state.modal.input.buffer.deinit(allocator);
    }
    state.modal = .none;
}

fn executeQuery(state: *model.State) void {
    if (state.db_connection == null) {
        state.status = .{ .err = .{
            .message = "No active connection",
            .details = null,
            .source = .internal,
        } };
        return;
    }

    const sql = state.editor.buffer.items;
    if (sql.len == 0) {
        state.status = .{ .err = .{
            .message = "No query to execute",
            .details = null,
            .source = .internal,
        } };
        return;
    }

    state.editor.executing = true;
    state.status = .{ .loading = "Executing query..." };

    // Execute query asynchronously
    const db_api = @import("db/db.zig");
    db_api.executeAsync(state.db_connection.?, sql, state.async_queue) catch |err| {
        state.editor.executing = false;
        const err_msg = std.fmt.allocPrint(state.editor.allocator, "Failed to execute query: {}", .{err}) catch "Failed to execute query";
        state.status = .{ .err = .{
            .message = err_msg,
            .details = null,
            .source = .database,
        } };
    };
}
