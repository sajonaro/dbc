const std = @import("std");
const view = @import("view.zig");
const ui = @import("../ui/ui.zig");
const modal_model = @import("../model/modal.zig");

pub fn render(ctx: view.RenderContext, win: *ui.Window) void {
    const modal = &ctx.state.modal;
    const th = ctx.theme;

    // Draw overlay (dim effect)
    var y: usize = 0;
    while (y < win.rect.h) : (y += 1) {
        var x: usize = 0;
        while (x < win.rect.w) : (x += 1) {
            win.drawChar(y, x, ' ', th.modal_overlay) catch {};
        }
    }

    switch (modal.*) {
        .none => {},
        .confirm => |confirm| renderConfirm(ctx, win, confirm),
        .input => |input| renderInput(ctx, win, input),
        .err => |err| renderError(ctx, win, err),
        .connect => |connect| renderConnect(ctx, win, connect),
    }
}

fn renderConfirm(ctx: view.RenderContext, win: *ui.Window, confirm: modal_model.ConfirmModal) void {
    const th = ctx.theme;

    // Calculate modal size (centered, 50% width, auto height)
    const modal_w = @min(60, win.rect.w * 50 / 100);
    const modal_h = 8;
    const modal_x = (win.rect.w - modal_w) / 2;
    const modal_y = (win.rect.h - modal_h) / 2;

    // Draw modal background directly on the window
    var y: usize = 0;
    while (y < modal_h) : (y += 1) {
        var x: usize = 0;
        while (x < modal_w) : (x += 1) {
            win.drawChar(modal_y + y, modal_x + x, ' ', th.modal_bg) catch {};
        }
    }

    // Draw border (simplified - just corners and lines)
    // Top border
    win.drawChar(modal_y, modal_x, '+', th.modal_border) catch {};
    win.drawChar(modal_y, modal_x + modal_w - 1, '+', th.modal_border) catch {};
    var x: usize = 1;
    while (x < modal_w - 1) : (x += 1) {
        win.drawChar(modal_y, modal_x + x, '-', th.modal_border) catch {};
    }

    // Title
    const title_max = @min(confirm.title.len, modal_w - 4);
    win.drawText(modal_y, modal_x + 2, confirm.title[0..title_max], th.modal_border) catch {};

    // Draw message (centered)
    const msg_y = modal_y + 2;
    const msg_x = if (modal_w > confirm.message.len + 2)
        modal_x + (modal_w - confirm.message.len) / 2
    else
        modal_x + 1;
    win.drawText(msg_y, msg_x, confirm.message, th.modal_bg) catch {};

    // Draw buttons (centered)
    const buttons_y = modal_y + 5;
    const button_gap = 4;
    const confirm_btn = confirm.confirm_label;
    const cancel_btn = confirm.cancel_label;
    const total_width = confirm_btn.len + button_gap + cancel_btn.len;
    const buttons_x = if (modal_w > total_width + 2)
        modal_x + (modal_w - total_width) / 2
    else
        modal_x + 1;

    win.drawText(buttons_y, buttons_x, confirm_btn, th.button_primary) catch {};
    win.drawText(buttons_y, buttons_x + confirm_btn.len + button_gap, cancel_btn, th.button) catch {};
}

fn renderInput(ctx: view.RenderContext, win: *ui.Window, input: modal_model.InputModal) void {
    const th = ctx.theme;

    // Calculate modal size (centered, 60% width)
    const modal_w = @min(60, win.rect.w * 60 / 100);
    const modal_h = 8;
    const modal_x = (win.rect.w - modal_w) / 2;
    const modal_y = (win.rect.h - modal_h) / 2;

    // Draw modal background
    var y: usize = 0;
    while (y < modal_h) : (y += 1) {
        var x: usize = 0;
        while (x < modal_w) : (x += 1) {
            win.drawChar(modal_y + y, modal_x + x, ' ', th.modal_bg) catch {};
        }
    }

    // Draw border
    win.drawChar(modal_y, modal_x, '+', th.modal_border) catch {};
    win.drawChar(modal_y, modal_x + modal_w - 1, '+', th.modal_border) catch {};
    var x: usize = 1;
    while (x < modal_w - 1) : (x += 1) {
        win.drawChar(modal_y, modal_x + x, '-', th.modal_border) catch {};
    }

    // Title
    const title_max = @min(input.title.len, modal_w - 4);
    win.drawText(modal_y, modal_x + 2, input.title[0..title_max], th.modal_border) catch {};

    // Prompt
    const prompt_y = modal_y + 2;
    win.drawText(prompt_y, modal_x + 2, input.prompt, th.modal_bg) catch {};

    // Input field
    const input_y = modal_y + 4;
    const input_x = modal_x + 2;
    const input_w = modal_w - 4;

    // Draw input background
    var ix: usize = 0;
    while (ix < input_w) : (ix += 1) {
        win.drawChar(input_y, input_x + ix, ' ', th.input_focused) catch {};
    }

    // Draw input text
    const display_text = if (input.buffer.items.len > input_w - 2)
        input.buffer.items[input.buffer.items.len - input_w + 2 ..]
    else
        input.buffer.items;
    win.drawText(input_y, input_x + 1, display_text, th.input_focused) catch {};

    // Show cursor at input position
    const cursor_pos = if (input.buffer.items.len > input_w - 2)
        input_w - 2
    else
        input.cursor;
    win.move(input_y, input_x + 1 + cursor_pos);
    win.setCursor(true);

    // Instructions
    const help_y = modal_y + modal_h - 2;
    win.drawText(help_y, modal_x + 2, "Enter: Save  Esc: Cancel", th.modal_bg) catch {};
}

fn renderError(ctx: view.RenderContext, win: *ui.Window, err: modal_model.ErrorModal) void {
    _ = ctx;
    _ = win;
    _ = err;
}

fn renderConnect(ctx: view.RenderContext, win: *ui.Window, connect: modal_model.ConnectModal) void {
    const th = ctx.theme;

    // Calculate modal size (centered, 60% width)
    const modal_w = @min(70, win.rect.w * 60 / 100);
    const modal_h = 18;
    const modal_x = (win.rect.w - modal_w) / 2;
    const modal_y = (win.rect.h - modal_h) / 2;

    // Draw modal background
    var y: usize = 0;
    while (y < modal_h) : (y += 1) {
        var x: usize = 0;
        while (x < modal_w) : (x += 1) {
            win.drawChar(modal_y + y, modal_x + x, ' ', th.modal_bg) catch {};
        }
    }

    // Draw border
    win.drawChar(modal_y, modal_x, '+', th.modal_border) catch {};
    win.drawChar(modal_y, modal_x + modal_w - 1, '+', th.modal_border) catch {};
    var x: usize = 1;
    while (x < modal_w - 1) : (x += 1) {
        win.drawChar(modal_y, modal_x + x, '-', th.modal_border) catch {};
    }

    // Title
    const title = " New Database Connection ";
    win.drawText(modal_y, modal_x + 2, title, th.modal_border) catch {};

    // Driver (read-only for now)
    const driver_y = modal_y + 2;
    win.drawText(driver_y, modal_x + 2, "Driver:     PostgreSQL", th.modal_bg) catch {};

    // Fields
    const fields = [_]struct { label: []const u8, field: modal_model.ConnectField }{
        .{ .label = "Host:      ", .field = .host },
        .{ .label = "Port:      ", .field = .port },
        .{ .label = "Database:  ", .field = .database },
        .{ .label = "Username:  ", .field = .user },
        .{ .label = "Password:  ", .field = .password },
    };

    var field_y = driver_y + 2;
    for (fields) |f| {
        const is_focused = connect.focused_field == f.field;
        const style = if (is_focused) th.input_focused else th.modal_bg;

        // Draw label
        win.drawText(field_y, modal_x + 2, f.label, th.modal_bg) catch {};

        // Draw input field background
        const input_x = modal_x + 2 + f.label.len;
        const input_w = modal_w - f.label.len - 6;
        var ix: usize = 0;
        while (ix < input_w) : (ix += 1) {
            win.drawChar(field_y, input_x + ix, ' ', style) catch {};
        }

        // Draw field value
        const value = switch (f.field) {
            .driver => "",
            .host => connect.host.items,
            .port => connect.port.items,
            .database => connect.database.items,
            .user => connect.user.items,
            .password => "", // We'll draw asterisks directly instead
        };

        if (f.field != .password) {
            const display_value = if (value.len > input_w - 2) value[0 .. input_w - 2] else value;
            win.drawText(field_y, input_x + 1, display_value, style) catch {};
        } else {
            // For password, draw asterisks directly
            var i: usize = 0;
            while (i < connect.password.items.len and i < input_w - 2) : (i += 1) {
                win.drawChar(field_y, input_x + 1 + i, '*', style) catch {};
            }
        }

        field_y += 2;
    }

    // Instructions
    const help_y = modal_y + modal_h - 3;
    win.drawText(help_y, modal_x + 2, "Tab: Next field  Enter: Connect  Esc: Cancel", th.modal_bg) catch {};
}
