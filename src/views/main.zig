const std = @import("std");
const view = @import("view.zig");
const ui = @import("../ui/ui.zig");
const tree_view = @import("tree.zig");
const editor_view = @import("editor.zig");
const results_view = @import("results.zig");
const status_view = @import("status.zig");
const modal_view = @import("modal.zig");

pub const RenderContext = view.RenderContext;

pub fn render(ctx: RenderContext, screen: *ui.Screen) void {
    const size = screen.getSize();

    // Calculate layout
    // Layout: [Tree | Editor/Results] with Status bar at bottom
    // Tree: 25% width, full height minus status
    // Editor: 75% width, 50% height (top half)
    // Results: 75% width, 50% height (bottom half)
    // Status: full width, 1 line at bottom

    const tree_width = size.width * 25 / 100;
    const main_width = size.width - tree_width;
    const status_height = 1;
    const content_height = if (size.height > status_height) size.height - status_height else 0;
    const editor_height = content_height / 2;
    const results_height = content_height - editor_height;

    // Create windows for each panel
    var tree_win = ui.Window.init(screen, ui.Rect{
        .x = 0,
        .y = 0,
        .w = tree_width,
        .h = content_height,
    }) catch return;
    defer tree_win.deinit();

    var editor_win = ui.Window.init(screen, ui.Rect{
        .x = tree_width,
        .y = 0,
        .w = main_width,
        .h = editor_height,
    }) catch return;
    defer editor_win.deinit();

    var results_win = ui.Window.init(screen, ui.Rect{
        .x = tree_width,
        .y = editor_height,
        .w = main_width,
        .h = results_height,
    }) catch return;
    defer results_win.deinit();

    var status_win = ui.Window.init(screen, ui.Rect{
        .x = 0,
        .y = content_height,
        .w = size.width,
        .h = status_height,
    }) catch return;
    defer status_win.deinit();

    // Render each panel
    const tree_focused = ctx.state.focus == .tree;
    const editor_focused = ctx.state.focus == .editor;
    const results_focused = ctx.state.focus == .results;

    tree_view.render(ctx, &tree_win, tree_focused);
    editor_view.render(ctx, &editor_win, editor_focused);
    results_view.render(ctx, &results_win, results_focused);
    status_view.render(ctx, &status_win);

    // Use proper double buffering: noutrefresh() stages changes, doupdate() commits all at once
    // This prevents flicker by updating the physical screen in a single operation
    tree_win.noutrefresh();
    editor_win.noutrefresh();
    results_win.noutrefresh();
    status_win.noutrefresh();

    // Render modal if present (on top of everything)
    if (ctx.state.modal != .none) {
        var modal_win = ui.Window.init(screen, ui.Rect{
            .x = 0,
            .y = 0,
            .w = size.width,
            .h = size.height,
        }) catch return;
        defer modal_win.deinit();

        modal_view.render(ctx, &modal_win);
        modal_win.noutrefresh();
    }

    // Commit all changes to physical screen at once (eliminates flicker!)
    screen.doupdate();
}

pub fn handleResize(ctx: RenderContext, screen: *ui.Screen) void {
    _ = ctx;
    _ = screen;
    // Terminal resize is handled automatically by ncurses
    // We just need to re-render with the new size
}
