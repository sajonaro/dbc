const std = @import("std");
const view = @import("view.zig");
const ui = @import("../ui/ui.zig");
const results_model = @import("../model/results.zig");

pub fn render(ctx: view.RenderContext, win: *ui.Window, focused: bool) void {
    const results = &ctx.state.results;
    const th = ctx.theme;

    // Draw border
    const border_style = if (focused) th.border_focused else th.border;
    win.drawBorder(border_style, "Query Results", focused) catch return;

    // Calculate visible area (exclude border and footer)
    const content_height = if (win.rect.h > 4) win.rect.h - 4 else 0; // -4 for border and footer
    const content_width = if (win.rect.w > 2) win.rect.w - 2 else 0;

    if (content_height == 0 or content_width == 0) return;

    // Draw footer with metadata
    const footer_y = win.rect.h - 2;
    var footer_buf: [128]u8 = undefined;
    const footer = if (results.affected_rows) |affected|
        std.fmt.bufPrint(&footer_buf, " {d} rows affected | {d}ms ", .{ affected, results.execution_time_ms }) catch ""
    else
        std.fmt.bufPrint(&footer_buf, " {d} rows | {d}ms ", .{ results.row_count, results.execution_time_ms }) catch "";

    win.fillLine(footer_y, ' ', th.status_bar) catch {};
    win.drawText(footer_y, 1, footer, th.status_bar) catch {};

    if (results.columns.len == 0) {
        // No results to display
        const empty_msg = "No results";
        const msg_x = if (win.rect.w > empty_msg.len + 2) (win.rect.w - empty_msg.len) / 2 else 1;
        const msg_y = win.rect.h / 2;
        win.drawText(msg_y, msg_x, empty_msg, th.muted) catch return;
        return;
    }

    // Calculate column positions
    var col_positions = std.ArrayList(usize).initCapacity(ctx.state.editor.allocator, 0) catch return;
    defer col_positions.deinit(ctx.state.editor.allocator);

    var x_offset: usize = 0;
    for (results.columns) |col| {
        col_positions.append(ctx.state.editor.allocator, x_offset) catch break;
        x_offset += col.width + 1; // +1 for separator
    }

    // Horizontal scrolling
    const scroll_col = results.scroll_col;

    // Draw header
    const header_y = 1;
    var col_idx: usize = 0;
    while (col_idx < results.columns.len) : (col_idx += 1) {
        const col = results.columns[col_idx];
        const col_x = col_positions.items[col_idx];

        if (col_x < scroll_col) continue;
        const screen_x = col_x - scroll_col + 1;
        if (screen_x >= content_width) break;

        const is_selected_col = (col_idx == results.selected_col);
        const header_style = if (is_selected_col) th.header_selected else th.header;

        // Truncate column name if needed
        const available_width = @min(col.width, content_width - screen_x);
        const col_name = if (col.name.len > available_width)
            col.name[0..available_width]
        else
            col.name;

        win.drawText(header_y, screen_x, col_name, header_style) catch {};

        // Fill remaining width with spaces
        if (col_name.len < available_width) {
            var i = col_name.len;
            while (i < available_width) : (i += 1) {
                win.drawChar(header_y, screen_x + i, ' ', header_style) catch {};
            }
        }
    }

    // Draw separator line
    win.drawHLine(2, 1, content_width, th.border) catch {};

    // Calculate visible rows
    const data_height = content_height - 2; // -2 for header and separator
    const max_scroll_row = if (results.rows.len > data_height)
        results.rows.len - data_height
    else
        0;
    const scroll_row = @min(results.scroll_row, max_scroll_row);

    // Draw data rows
    var row_idx = scroll_row;
    var screen_y: usize = 0;

    while (row_idx < results.rows.len and screen_y < data_height) : (row_idx += 1) {
        const y = screen_y + 3; // +3 for border, header, separator
        const row = results.rows[row_idx];
        const is_selected_row = (row_idx == results.selected_row);

        // Fill row background if selected
        if (is_selected_row) {
            win.fillLine(y, ' ', th.row_selected) catch {};
        }

        // Draw cells
        col_idx = 0;
        while (col_idx < results.columns.len and col_idx < row.len) : (col_idx += 1) {
            const col = results.columns[col_idx];
            const col_x = col_positions.items[col_idx];

            if (col_x < scroll_col) continue;
            const screen_x = col_x - scroll_col + 1;
            if (screen_x >= content_width) break;

            const cell = row[col_idx];
            const is_selected_cell = (row_idx == results.selected_row and col_idx == results.selected_col);

            // Determine cell style
            const cell_style = if (is_selected_cell)
                th.cell_selected
            else if (cell) |c|
                if (c.is_null) th.null_value else th.normal
            else
                th.null_value;

            // Get cell value
            const cell_value = if (cell) |c|
                if (c.is_null) "NULL" else c.value
            else
                "NULL";

            // Truncate cell value if needed
            const available_width = @min(col.width, content_width - screen_x);
            const display_value = if (cell_value.len > available_width)
                cell_value[0..available_width]
            else
                cell_value;

            win.drawText(y, screen_x, display_value, cell_style) catch {};

            // Fill remaining width with spaces (for cell selection highlight)
            if (is_selected_cell and display_value.len < available_width) {
                var i = display_value.len;
                while (i < available_width) : (i += 1) {
                    win.drawChar(y, screen_x + i, ' ', cell_style) catch {};
                }
            }
        }

        screen_y += 1;
    }

    // Draw scrollbar if needed
    if (results.rows.len > data_height) {
        const scrollbar_x = win.rect.w - 1;
        win.drawScrollbar(
            scrollbar_x,
            results.rows.len,
            data_height,
            scroll_row,
            th.scrollbar,
        ) catch {};
    }
}
