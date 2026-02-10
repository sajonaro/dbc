const std = @import("std");
const view = @import("view.zig");
const ui = @import("../ui/ui.zig");
const model = @import("../model.zig");

pub fn render(ctx: view.RenderContext, win: *ui.Window) void {
    const state = ctx.state;
    const th = ctx.theme;

    // Status bar is always at the bottom, no border
    if (win.rect.h == 0) return;

    // Determine status style and message based on current state
    const status_style = switch (state.status) {
        .idle => th.status_bar,
        .loading => th.status_loading,
        .err => th.status_error,
    };

    const status_msg = switch (state.status) {
        .idle => |msg| msg,
        .loading => |msg| msg,
        .err => |e| e.message,
    };

    // Fill the entire status bar
    win.fillLine(0, ' ', status_style) catch return;

    // Draw status message on the left
    win.drawText(0, 1, status_msg, status_style) catch {};

    // Draw connection info in the middle
    if (state.active_connection) |conn_idx| {
        if (conn_idx < state.connections.items.len) {
            const conn = state.connections.items[conn_idx];
            var conn_buf: [64]u8 = undefined;
            const conn_info = std.fmt.bufPrint(&conn_buf, " [{s}] ", .{conn.name}) catch "";

            const conn_x = if (win.rect.w > conn_info.len + status_msg.len + 4)
                (win.rect.w - conn_info.len) / 2
            else
                status_msg.len + 2;

            win.drawText(0, conn_x, conn_info, status_style) catch {};
        }
    }

    // Draw keybinding hints on the right
    const hints = " F1:Help F5:Run Tab:Switch Ctrl+Q:Quit ";
    const hints_x = if (win.rect.w > hints.len)
        win.rect.w - hints.len
    else
        0;

    if (hints_x > 0) {
        win.drawText(0, hints_x, hints, th.status_muted) catch {};
    }
}
