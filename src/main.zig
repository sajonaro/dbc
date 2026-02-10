const std = @import("std");
const model = @import("model.zig");
const events = @import("events.zig");
const actions = @import("actions.zig");
const main_view = @import("views/main.zig");
const ui = @import("ui/ui.zig");
const input = @import("ui/input.zig");
const async_mod = @import("async.zig");
const theme = @import("theme.zig");
const db = @import("db/db.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize async queue
    var async_queue = async_mod.AsyncQueue.init(allocator);
    defer async_queue.deinit();

    // Initialize tree nodes with "New Connection" option
    var tree_nodes = try std.ArrayList(model.Node).initCapacity(allocator, 1);
    tree_nodes.appendAssumeCapacity(.{
        .id = "new_connection",
        .label = "+ New Connection",
        .kind = .connection,
        .depth = 0,
        .parent_id = null,
        .children_loaded = true,
    });

    // Initialize state
    var state = model.State{
        .connections = .empty,
        .active_connection = null,
        .db_connection = null,
        .tree = .{
            .nodes = tree_nodes,
            .selected = 0,
            .scroll = 0,
            .expanded = std.StringHashMap(bool).init(allocator),
        },
        .editor = .{
            .allocator = allocator,
            .buffer = .empty,
            .cursor = .{ .row = 0, .col = 0 },
            .scroll = .{ .row = 0, .col = 0 },
            .selection = null,
            .modified = false,
            .executing = false,
            .undo_stack = .empty,
            .redo_stack = .empty,
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
        .status = .{ .idle = "Welcome to Database Commander - Press F1 for help" },
        .running = true,
        .theme = &theme.dark,
        .async_queue = &async_queue,
    };
    defer state.connections.deinit(allocator);
    defer {
        // Free all allocated node IDs and labels before deinit
        for (state.tree.nodes.items) |node| {
            // Free node ID if it was allocated (not a string literal like "new_connection")
            if (!std.mem.eql(u8, node.id, "new_connection")) {
                allocator.free(node.id);
            }
            // Free node label if it was allocated (not a string literal)
            // Check if label looks like an allocated string (contains dynamic content)
            if (node.kind == .connection or node.kind == .schema or node.kind == .table) {
                if (!std.mem.eql(u8, node.label, "+ New Connection") and
                    !std.mem.eql(u8, node.label, "Tables") and
                    !std.mem.eql(u8, node.label, "Views") and
                    !std.mem.eql(u8, node.label, "Functions") and
                    !std.mem.eql(u8, node.label, "Stored Procedures"))
                {
                    allocator.free(node.label);
                }
            }
        }
        state.tree.nodes.deinit(allocator);
    }
    defer state.tree.expanded.deinit();
    defer state.editor.buffer.deinit(allocator);
    defer state.editor.undo_stack.deinit(allocator);
    defer state.editor.redo_stack.deinit(allocator);

    // Free query results on exit
    defer {
        // Free result columns (including their owned strings)
        if (state.results.columns.len > 0) {
            for (state.results.columns) |col| {
                allocator.free(col.name);
                allocator.free(col.data_type);
            }
            allocator.free(state.results.columns);
        }

        // Free result rows and cells
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
    }

    // Free database connection on exit
    defer {
        if (state.db_connection) |conn| {
            conn.disconnect();
            allocator.destroy(conn);
        }
    }

    // Free status error messages on exit
    defer {
        if (state.status == .err) {
            const err_msg = state.status.err.message;
            // Only free if it's not a string literal
            if (!std.mem.eql(u8, err_msg, "Failed to build connection string") and
                !std.mem.eql(u8, err_msg, "Failed to allocate connection") and
                !std.mem.eql(u8, err_msg, "Failed to load database metadata") and
                !std.mem.eql(u8, err_msg, "Failed to load items"))
            {
                allocator.free(err_msg);
            }
            if (state.status.err.details) |details| {
                allocator.free(details);
            }
        }
    }

    // Initialize UI (ncurses)
    var screen = ui.Screen.init() catch |err| {
        std.debug.print("Failed to initialize ncurses: {}\n", .{err});
        return err;
    };
    defer screen.deinit();

    // Main event loop
    while (state.running) {
        // 1. Render current state (without clearing - windows will overwrite)
        const ctx = main_view.RenderContext{
            .state = &state,
            .theme = state.theme,
        };
        main_view.render(ctx, &screen);

        // 2. Poll for input (with timeout for async)
        if (input.poll(333)) |event| {
            actions.processEvent(&state, event);
        }

        // 3. Check for terminal resize
        if (input.checkResize()) |resize_event| {
            actions.processEvent(&state, resize_event);
        }

        // 4. Process async results
        const async_events = async_queue.drain();
        defer allocator.free(async_events);
        for (async_events) |event| {
            actions.processEvent(&state, event);
        }
    }
}
