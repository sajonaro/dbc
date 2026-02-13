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

const version = "0.1.2.1";

const usage =
    \\Database Commander (dbc) - Terminal-based database management tool
    \\
    \\Usage:
    \\  dbc [OPTIONS] [FILE]
    \\
    \\Options:
    \\  -h, --help, ?       Show this help message and exit
    \\  -v, --version       Show version information and exit
    \\
    \\Arguments:
    \\  FILE                Optional SQL file to load into the editor
    \\
    \\Examples:
    \\  dbc                 Start dbc with empty editor
    \\  dbc query.sql       Start dbc and load query.sql into the editor
    \\  dbc --help          Show this help message
    \\  dbc --version       Show version information
    \\
;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command-line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Handle help and version flags
    if (args.len > 1) {
        const arg = args[1];
        if (std.mem.eql(u8, arg, "--help") or
            std.mem.eql(u8, arg, "-h") or
            std.mem.eql(u8, arg, "?"))
        {
            std.debug.print("{s}\n", .{usage});
            return;
        }
        if (std.mem.eql(u8, arg, "--version") or
            std.mem.eql(u8, arg, "-v"))
        {
            std.debug.print("dbc version {s}\n", .{version});
            return;
        }
    }

    // Check if a file path was provided
    var initial_query: ?[]const u8 = null;
    defer if (initial_query) |query| allocator.free(query);

    var opened_file_path: ?[]const u8 = null;

    if (args.len > 1) {
        const file_path = args[1];
        // Try to read the file
        const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
            std.debug.print("Error opening file '{s}': {}\n", .{ file_path, err });
            return err;
        };
        defer file.close();

        const file_size = try file.getEndPos();
        const buffer = try allocator.alloc(u8, file_size);
        _ = try file.readAll(buffer);
        initial_query = buffer;

        // Store the file path for the editor
        opened_file_path = try allocator.dupe(u8, file_path);
    }

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
            .current_file = opened_file_path,
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
        .needs_redraw = true,
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

    // Free current file path if allocated
    defer if (state.editor.current_file) |file_path| {
        allocator.free(file_path);
    };

    // Load initial query file content into editor buffer if provided
    if (initial_query) |query| {
        try state.editor.buffer.appendSlice(allocator, query);
    }

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
    // Note: We don't free error messages because they may be string literals
    // from catch expressions, and trying to free them causes crashes.
    // This is a known limitation that could be improved by using a separate
    // allocator for status messages or tracking which messages are allocated.

    // Initialize UI (ncurses)
    var screen = ui.Screen.init() catch |err| {
        std.debug.print("Failed to initialize ncurses: {}\n", .{err});
        return err;
    };
    defer screen.deinit();

    // Force initial refresh to ensure ncurses is ready
    screen.refresh();

    // Main event loop
    while (state.running) {
        // 1. Render current state only if needed
        if (state.needs_redraw) {
            const ctx = main_view.RenderContext{
                .state = &state,
                .theme = state.theme,
            };
            main_view.render(ctx, &screen);
            state.needs_redraw = false;
        }

        // 2. Poll for input (with timeout for async)
        if (input.poll(333)) |event| {
            actions.processEvent(&state, event);
            state.needs_redraw = true;
        }

        // 3. Check for terminal resize
        if (input.checkResize()) |resize_event| {
            actions.processEvent(&state, resize_event);
            state.needs_redraw = true;
        }

        // 4. Process async results
        const async_events = async_queue.drain();
        defer allocator.free(async_events);
        if (async_events.len > 0) {
            for (async_events) |event| {
                actions.processEvent(&state, event);
            }
            state.needs_redraw = true;
        }
    }
}
