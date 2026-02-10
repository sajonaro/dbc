const std = @import("std");
const events = @import("../events.zig");

// ncurses C bindings
const c = @cImport({
    @cInclude("ncurses.h");
});

pub fn poll(timeout_ms: u64) ?events.Event {
    // Set timeout for getch
    _ = c.timeout(@intCast(timeout_ms));

    const ch = c.getch();

    if (ch == c.ERR) {
        // No input available
        return null;
    }

    // Handle special keys
    const key_event = parseKey(ch) orelse return null;

    return events.Event{ .key = key_event };
}

fn parseKey(ch: c_int) ?events.KeyEvent {
    var modifiers = events.KeyEvent.Modifiers{};

    // CRITICAL: Check for Enter/Tab/Escape FIRST before Ctrl modifier check!
    // These keys have codes in the 1-26 range but should NOT be treated as Ctrl+Letter
    if (ch == 10 or ch == 13 or ch == c.KEY_ENTER) {
        // Enter key (code 10 = LF, 13 = CR, KEY_ENTER = ncurses constant)
        return .{
            .key = .enter,
            .modifiers = .{},
        };
    }

    if (ch == 9) {
        // Tab key
        return .{
            .key = .tab,
            .modifiers = .{},
        };
    }

    if (ch == 27) {
        // Escape key
        return .{
            .key = .escape,
            .modifiers = .{},
        };
    }

    // Check for F1 explicitly (KEY_F(1) = KEY_F0 + 1)
    // In some terminals, F1 might not be captured by KEY_F0+1 in the switch
    if (ch == c.KEY_F0 + 1) {
        return .{
            .key = .F1,
            .modifiers = .{},
        };
    }

    // Now check for Ctrl modifier (characters 1-26 map to Ctrl+A through Ctrl+Z)
    // EXCEPT the ones we already handled above (Enter, Tab)
    if (ch >= 1 and ch <= 26) {
        modifiers.ctrl = true;
        const char = @as(u8, @intCast(ch + 96)); // Convert to lowercase letter
        return .{
            .key = .{ .char = char },
            .modifiers = modifiers,
        };
    }

    // Map ncurses key codes to our Key enum
    const key: events.Key = switch (ch) {
        // Function keys
        c.KEY_F0 + 1 => .F1,
        c.KEY_F0 + 2 => .F2,
        c.KEY_F0 + 3 => .F3,
        c.KEY_F0 + 4 => .F4,
        c.KEY_F0 + 5 => .F5,
        c.KEY_F0 + 6 => .F6,
        c.KEY_F0 + 7 => .F7,
        c.KEY_F0 + 8 => .F8,
        c.KEY_F0 + 9 => .F9,
        c.KEY_F0 + 10 => .F10,
        c.KEY_F0 + 11 => .F11,
        c.KEY_F0 + 12 => .F12,

        // Arrow keys
        c.KEY_UP => .up,
        c.KEY_DOWN => .down,
        c.KEY_LEFT => .left,
        c.KEY_RIGHT => .right,

        // Navigation keys
        c.KEY_HOME => .home,
        c.KEY_END => .end,
        c.KEY_PPAGE => .page_up,
        c.KEY_NPAGE => .page_down,

        // Backspace (multiple codes for compatibility)
        c.KEY_BACKSPACE => .backspace,
        127 => .backspace, // DEL character
        8 => .backspace, // Ctrl+H

        c.KEY_DC => .delete,

        // Regular characters (32-126 are printable ASCII)
        32...126 => .{ .char = @intCast(ch) },

        else => return null, // Unknown key
    };

    return .{
        .key = key,
        .modifiers = modifiers,
    };
}

// Helper function to check for terminal resize events
pub fn checkResize() ?events.Event {
    if (c.is_term_resized(0, 0)) {
        const height = c.getmaxy(c.stdscr);
        const width = c.getmaxx(c.stdscr);

        _ = c.resize_term(height, width);

        return events.Event{
            .resize = .{
                .width = @intCast(width),
                .height = @intCast(height),
            },
        };
    }
    return null;
}
