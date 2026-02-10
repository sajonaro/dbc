const std = @import("std");
const theme = @import("../theme.zig");

// ncurses C bindings
const c = @cImport({
    @cInclude("ncurses.h");
    @cInclude("locale.h");
});

pub const Rect = struct {
    x: usize,
    y: usize,
    w: usize,
    h: usize,
};

pub const Screen = struct {
    width: usize,
    height: usize,
    color_pairs: [32]ColorPair,
    next_pair_id: u8,

    const ColorPair = struct {
        fg: theme.Color,
        bg: theme.Color,
        id: u8,
    };

    pub fn init() !Screen {
        // Set locale for UTF-8 support
        _ = c.setlocale(c.LC_ALL, "");

        // Initialize ncurses
        _ = c.initscr();

        // Configure ncurses
        _ = c.raw(); // Disable line buffering
        _ = c.noecho(); // Don't echo input
        _ = c.keypad(c.stdscr, true); // Enable special keys
        _ = c.curs_set(0); // Hide cursor by default
        _ = c.set_escdelay(25); // Short escape delay

        // Initialize colors
        if (!c.has_colors()) {
            return error.NoColorSupport;
        }
        _ = c.start_color();
        _ = c.use_default_colors();

        const height = c.getmaxy(c.stdscr);
        const width = c.getmaxx(c.stdscr);

        return Screen{
            .width = @intCast(width),
            .height = @intCast(height),
            .color_pairs = undefined,
            .next_pair_id = 1,
        };
    }

    pub fn deinit(self: *Screen) void {
        _ = self;
        _ = c.endwin();
    }

    pub fn getSize(self: *Screen) struct { width: usize, height: usize } {
        const height = c.getmaxy(c.stdscr);
        const width = c.getmaxx(c.stdscr);
        self.width = @intCast(width);
        self.height = @intCast(height);
        return .{ .width = self.width, .height = self.height };
    }

    pub fn clear(self: *Screen) void {
        _ = self;
        _ = c.clear();
    }

    pub fn refresh(self: *Screen) void {
        _ = self;
        _ = c.refresh();
    }

    pub fn doupdate(self: *Screen) void {
        _ = self;
        _ = c.doupdate();
    }

    pub fn getOrCreateColorPair(self: *Screen, style: theme.Style) !u8 {
        // Check if this color pair already exists
        for (self.color_pairs[0..self.next_pair_id]) |pair| {
            if (pair.fg == style.fg and pair.bg == style.bg) {
                return pair.id;
            }
        }

        // Create a new color pair
        if (self.next_pair_id >= 32) {
            return error.TooManyColorPairs;
        }

        const pair_id = self.next_pair_id;
        const fg = colorToNcurses(style.fg);
        const bg = colorToNcurses(style.bg);

        _ = c.init_pair(@intCast(pair_id), fg, bg);

        self.color_pairs[pair_id] = .{
            .fg = style.fg,
            .bg = style.bg,
            .id = pair_id,
        };
        self.next_pair_id += 1;

        return pair_id;
    }

    fn colorToNcurses(color: theme.Color) c_short {
        return switch (color) {
            .default => -1,
            .black => c.COLOR_BLACK,
            .red => c.COLOR_RED,
            .green => c.COLOR_GREEN,
            .yellow => c.COLOR_YELLOW,
            .blue => c.COLOR_BLUE,
            .magenta => c.COLOR_MAGENTA,
            .cyan => c.COLOR_CYAN,
            .white => c.COLOR_WHITE,
            .bright_black => 8,
            .bright_red => 9,
            .bright_green => 10,
            .bright_yellow => 11,
            .bright_blue => 12,
            .bright_magenta => 13,
            .bright_cyan => 14,
            .bright_white => 15,
        };
    }
};

pub const Window = struct {
    win: *c.WINDOW,
    rect: Rect,
    screen: *Screen,

    pub fn init(screen: *Screen, rect: Rect) !Window {
        const win = c.newwin(
            @intCast(rect.h),
            @intCast(rect.w),
            @intCast(rect.y),
            @intCast(rect.x),
        ) orelse return error.WindowCreationFailed;

        _ = c.keypad(win, true);

        return Window{
            .win = win,
            .rect = rect,
            .screen = screen,
        };
    }

    pub fn deinit(self: *Window) void {
        _ = c.delwin(self.win);
    }

    pub fn clear(self: *Window) void {
        _ = c.wclear(self.win);
    }

    pub fn refresh(self: *Window) void {
        _ = c.wrefresh(self.win);
    }

    pub fn noutrefresh(self: *Window) void {
        _ = c.wnoutrefresh(self.win);
    }

    pub fn move(self: *Window, y: usize, x: usize) void {
        _ = c.wmove(self.win, @intCast(y), @intCast(x));
    }

    pub fn setCursor(self: *Window, visible: bool) void {
        _ = self;
        _ = c.curs_set(if (visible) 1 else 0);
    }

    pub fn drawBorder(self: *Window, style: theme.Style, title: ?[]const u8, focused: bool) !void {
        const pair_id = try self.screen.getOrCreateColorPair(if (focused) style else style);
        const attr = c.COLOR_PAIR(@as(c_int, pair_id));

        _ = c.wattron(self.win, attr);
        _ = c.box(self.win, 0, 0);
        _ = c.wattroff(self.win, attr);

        if (title) |t| {
            const max_len = if (self.rect.w > 4) self.rect.w - 4 else 0;
            const title_len = @min(t.len, max_len);

            if (title_len > 0) {
                _ = c.wmove(self.win, 0, 2);
                _ = c.wattron(self.win, attr | c.A_BOLD);
                _ = c.waddnstr(self.win, t.ptr, @intCast(title_len));
                _ = c.wattroff(self.win, attr | c.A_BOLD);
            }
        }
    }

    pub fn drawText(self: *Window, y: usize, x: usize, text: []const u8, style: theme.Style) !void {
        if (y >= self.rect.h or x >= self.rect.w) return;

        const pair_id = try self.screen.getOrCreateColorPair(style);
        var attr: c_int = c.COLOR_PAIR(@as(c_int, pair_id));

        if (style.bold) attr |= c.A_BOLD;
        if (style.underline) attr |= c.A_UNDERLINE;
        if (style.reverse) attr |= c.A_REVERSE;

        _ = c.wattron(self.win, attr);
        _ = c.wmove(self.win, @intCast(y), @intCast(x));

        const max_len = if (self.rect.w > x) self.rect.w - x else 0;
        const text_len = @min(text.len, max_len);

        if (text_len > 0) {
            _ = c.waddnstr(self.win, text.ptr, @intCast(text_len));
        }

        _ = c.wattroff(self.win, attr);
    }

    pub fn drawChar(self: *Window, y: usize, x: usize, ch: u8, style: theme.Style) !void {
        if (y >= self.rect.h or x >= self.rect.w) return;

        const pair_id = try self.screen.getOrCreateColorPair(style);
        var attr: c_int = c.COLOR_PAIR(@as(c_int, pair_id));

        if (style.bold) attr |= c.A_BOLD;
        if (style.underline) attr |= c.A_UNDERLINE;
        if (style.reverse) attr |= c.A_REVERSE;

        _ = c.wmove(self.win, @intCast(y), @intCast(x));
        _ = c.waddch(self.win, @as(c_uint, ch) | @as(c_uint, @intCast(attr)));
    }

    pub fn fillLine(self: *Window, y: usize, ch: u8, style: theme.Style) !void {
        if (y >= self.rect.h) return;

        const pair_id = try self.screen.getOrCreateColorPair(style);
        var attr: c_int = c.COLOR_PAIR(@as(c_int, pair_id));

        if (style.bold) attr |= c.A_BOLD;
        if (style.underline) attr |= c.A_UNDERLINE;
        if (style.reverse) attr |= c.A_REVERSE;

        _ = c.wmove(self.win, @intCast(y), 0);
        _ = c.wattron(self.win, attr);

        var i: usize = 0;
        while (i < self.rect.w) : (i += 1) {
            _ = c.waddch(self.win, ch);
        }

        _ = c.wattroff(self.win, attr);
    }

    pub fn drawHLine(self: *Window, y: usize, x: usize, len: usize, style: theme.Style) !void {
        if (y >= self.rect.h or x >= self.rect.w) return;

        const pair_id = try self.screen.getOrCreateColorPair(style);
        const attr = c.COLOR_PAIR(@as(c_int, pair_id));

        _ = c.wmove(self.win, @intCast(y), @intCast(x));
        _ = c.wattron(self.win, attr);

        const max_len = if (self.rect.w > x) self.rect.w - x else 0;
        const draw_len = @min(len, max_len);

        // Use simple dash character instead of ACS_HLINE to avoid comptime issues
        var i: usize = 0;
        while (i < draw_len) : (i += 1) {
            _ = c.waddch(self.win, '-');
        }
        _ = c.wattroff(self.win, attr);
    }

    pub fn drawVLine(self: *Window, y: usize, x: usize, len: usize, style: theme.Style) !void {
        if (y >= self.rect.h or x >= self.rect.w) return;

        const pair_id = try self.screen.getOrCreateColorPair(style);
        const attr = c.COLOR_PAIR(@as(c_int, pair_id));

        _ = c.wmove(self.win, @intCast(y), @intCast(x));
        _ = c.wattron(self.win, attr);

        const max_len = if (self.rect.h > y) self.rect.h - y else 0;
        const draw_len = @min(len, max_len);

        _ = c.wvline(self.win, c.ACS_VLINE, @intCast(draw_len));
        _ = c.wattroff(self.win, attr);
    }

    pub fn drawScrollbar(self: *Window, x: usize, total: usize, visible: usize, offset: usize, style: theme.Style) !void {
        if (self.rect.h < 3) return; // Need at least 3 lines for scrollbar
        if (x >= self.rect.w) return;

        const scrollbar_height = self.rect.h - 2; // Exclude border

        if (total <= visible) {
            // No scrolling needed, fill with track
            var y: usize = 1;
            while (y < self.rect.h - 1) : (y += 1) {
                try self.drawChar(y, x, ' ', style);
            }
            return;
        }

        // Calculate thumb position and size
        const thumb_size = @max(1, (visible * scrollbar_height) / total);
        const thumb_pos = (offset * scrollbar_height) / total;

        var y: usize = 1;
        while (y < self.rect.h - 1) : (y += 1) {
            const pos = y - 1;
            if (pos >= thumb_pos and pos < thumb_pos + thumb_size) {
                try self.drawChar(y, x, '#', style);
            } else {
                try self.drawChar(y, x, ' ', style);
            }
        }
    }
};
