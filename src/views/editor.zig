const std = @import("std");
const view = @import("view.zig");
const ui = @import("../ui/ui.zig");
const editor_model = @import("../model/editor.zig");

pub fn render(ctx: view.RenderContext, win: *ui.Window, focused: bool) void {
    const editor = &ctx.state.editor;
    const th = ctx.theme;

    // Draw border
    const border_style = if (focused) th.border_focused else th.border;
    var title_buf: [64]u8 = undefined;
    const title = std.fmt.bufPrint(&title_buf, "SQL Editor{s}{s}", .{
        if (editor.modified) " [*]" else "",
        if (editor.executing) " [Running...]" else "",
    }) catch "SQL Editor";
    win.drawBorder(border_style, title, focused) catch return;

    // Calculate visible area (exclude border)
    const content_height = if (win.rect.h > 2) win.rect.h - 2 else 0;
    const content_width = if (win.rect.w > 2) win.rect.w - 2 else 0;

    if (content_height == 0 or content_width == 0) return;

    // Calculate line number width (at least 3 chars for " 1 ")
    const line_count = countLines(editor.buffer.items);
    const line_num_width = @max(3, digitCount(line_count) + 2);

    // Calculate text area (excluding line numbers)
    const text_area_width = if (content_width > line_num_width)
        content_width - line_num_width
    else
        0;

    if (text_area_width == 0) return;

    // Split buffer into lines
    var lines = std.ArrayList([]const u8).initCapacity(ctx.state.editor.allocator, 0) catch return;
    defer lines.deinit(ctx.state.editor.allocator);

    var line_iter = std.mem.splitSequence(u8, editor.buffer.items, "\n");
    while (line_iter.next()) |line| {
        lines.append(ctx.state.editor.allocator, line) catch break;
    }

    // Ensure scroll is within bounds
    const max_scroll_row = if (lines.items.len > content_height)
        lines.items.len - content_height
    else
        0;
    const scroll_row = @min(editor.scroll.row, max_scroll_row);

    // Render visible lines
    var screen_y: usize = 0;
    var line_idx = scroll_row;

    while (line_idx < lines.items.len and screen_y < content_height) : (line_idx += 1) {
        const y = screen_y + 1; // +1 for border
        const line = lines.items[line_idx];

        // Draw line number
        var line_num_buf: [16]u8 = undefined;
        const line_num_str = std.fmt.bufPrint(&line_num_buf, "{d}", .{line_idx + 1}) catch "";
        const line_num_x = line_num_width - line_num_str.len - 1;
        win.drawText(y, line_num_x, line_num_str, th.line_number) catch {};
        win.drawText(y, line_num_width - 1, " ", th.normal) catch {};

        // Handle horizontal scrolling
        const scroll_col = editor.scroll.col;
        const visible_start = @min(scroll_col, line.len);
        const visible_end = @min(visible_start + text_area_width, line.len);
        const visible_text = if (visible_start < visible_end)
            line[visible_start..visible_end]
        else
            "";

        // Check if cursor is on this line
        const cursor_on_line = (line_idx == editor.cursor.row);

        // Draw the text
        if (visible_text.len > 0) {
            // TODO: Apply syntax highlighting here in future
            win.drawText(y, line_num_width, visible_text, th.normal) catch {};
        }

        // Draw cursor if focused and on this line
        if (focused and cursor_on_line) {
            const cursor_col = editor.cursor.col;
            if (cursor_col >= scroll_col and cursor_col < scroll_col + text_area_width) {
                const cursor_screen_x = line_num_width + (cursor_col - scroll_col);
                const cursor_char = if (cursor_col < line.len) line[cursor_col] else ' ';
                win.drawChar(y, cursor_screen_x, cursor_char, th.selection) catch {};
            }
        }

        screen_y += 1;
    }

    // Fill remaining lines if any
    while (screen_y < content_height) : (screen_y += 1) {
        const y = screen_y + 1;
        win.drawText(y, 1, "~", th.muted) catch {};
    }

    // Draw scrollbar if needed
    if (lines.items.len > content_height) {
        const scrollbar_x = win.rect.w - 1;
        win.drawScrollbar(
            scrollbar_x,
            lines.items.len,
            content_height,
            scroll_row,
            th.scrollbar,
        ) catch {};
    }

    // Show cursor
    if (focused) {
        win.setCursor(true);
    }
}

fn countLines(buffer: []const u8) usize {
    if (buffer.len == 0) return 1;
    var count: usize = 1;
    for (buffer) |ch| {
        if (ch == '\n') count += 1;
    }
    return count;
}

fn digitCount(n: usize) usize {
    if (n == 0) return 1;
    var count: usize = 0;
    var num = n;
    while (num > 0) {
        count += 1;
        num /= 10;
    }
    return count;
}
