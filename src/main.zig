const std = @import("std");
const model = @import("model.zig");
const events = @import("events.zig");
const actions = @import("actions.zig");
const main_view = @import("views/main.zig");
const ui = @import("ui/ui.zig");
const input = @import("ui/input.zig");
const async_mod = @import("async.zig");
const theme = @import("theme.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize async queue
    var async_queue = async_mod.AsyncQueue.init(allocator);
    defer async_queue.deinit();

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
            .allocator = allocator,
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
    defer state.connections.deinit();
    defer state.tree.nodes.deinit();
    defer state.tree.expanded.deinit();
    defer state.editor.buffer.deinit();
    defer state.editor.undo_stack.deinit();
    defer state.editor.redo_stack.deinit();

    // TODO: Initialize UI (ncurses)
    // var screen = try ui.Screen.init();
    // defer screen.deinit();

    std.debug.print("Database Commander - Skeleton Initialized\n", .{});
    std.debug.print("TODO: Implement ncurses UI and main loop\n", .{});
    std.debug.print("Architecture: Model-View-Action pattern\n", .{});

    // Main loop (placeholder)
    // while (state.running) {
    //     // 1. Render
    //     const ctx = main_view.RenderContext{
    //         .state = &state,
    //         .theme = state.theme,
    //     };
    //     main_view.render(ctx, &screen);
    //
    //     // 2. Poll for input (with timeout for async)
    //     if (input.poll(50)) |event| {
    //         actions.processEvent(&state, event);
    //     }
    //
    //     // 3. Process async results
    //     const async_events = async_queue.drain();
    //     defer allocator.free(async_events);
    //     for (async_events) |event| {
    //         actions.processEvent(&state, event);
    //     }
    // }
}
