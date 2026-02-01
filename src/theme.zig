const std = @import("std");

pub const Theme = struct {
    // Base colors
    normal: Style,
    muted: Style,

    // Borders
    border: Style,
    border_focused: Style,

    // Selection
    selection: Style,

    // Status bar
    status_bar: Style,
    status_loading: Style,
    status_error: Style,
    status_muted: Style,

    // Results grid
    header: Style,
    header_selected: Style,
    row_selected: Style,
    cell_selected: Style,
    null_value: Style,

    // Syntax highlighting
    syntax_keyword: Style,
    syntax_string: Style,
    syntax_number: Style,
    syntax_comment: Style,
    syntax_operator: Style,

    // Modal
    modal_bg: Style,
    modal_border: Style,
    modal_overlay: Style,

    // Buttons
    button: Style,
    button_primary: Style,

    // Editor
    line_number: Style,

    // Scrollbar
    scrollbar: Style,

    // Error
    error_border: Style,
    error_text: Style,
};

pub const Style = struct {
    fg: Color,
    bg: Color,
    bold: bool = false,
    underline: bool = false,
    reverse: bool = false,
};

pub const Color = enum {
    default,
    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,
    bright_black,
    bright_red,
    bright_green,
    bright_yellow,
    bright_blue,
    bright_magenta,
    bright_cyan,
    bright_white,
};

pub const dark = Theme{
    .normal = .{ .fg = .white, .bg = .default },
    .muted = .{ .fg = .bright_black, .bg = .default },

    .border = .{ .fg = .bright_black, .bg = .default },
    .border_focused = .{ .fg = .cyan, .bg = .default },

    .selection = .{ .fg = .black, .bg = .cyan },

    .status_bar = .{ .fg = .black, .bg = .white },
    .status_loading = .{ .fg = .black, .bg = .yellow },
    .status_error = .{ .fg = .white, .bg = .red },
    .status_muted = .{ .fg = .bright_black, .bg = .white },

    .header = .{ .fg = .cyan, .bg = .default, .bold = true },
    .header_selected = .{ .fg = .black, .bg = .cyan, .bold = true },
    .row_selected = .{ .fg = .white, .bg = .bright_black },
    .cell_selected = .{ .fg = .black, .bg = .cyan },
    .null_value = .{ .fg = .bright_black, .bg = .default },

    .syntax_keyword = .{ .fg = .magenta, .bg = .default, .bold = true },
    .syntax_string = .{ .fg = .green, .bg = .default },
    .syntax_number = .{ .fg = .yellow, .bg = .default },
    .syntax_comment = .{ .fg = .bright_black, .bg = .default },
    .syntax_operator = .{ .fg = .cyan, .bg = .default },

    .modal_bg = .{ .fg = .white, .bg = .black },
    .modal_border = .{ .fg = .cyan, .bg = .black },
    .modal_overlay = .{ .fg = .default, .bg = .default },

    .button = .{ .fg = .white, .bg = .bright_black },
    .button_primary = .{ .fg = .black, .bg = .cyan },

    .line_number = .{ .fg = .bright_black, .bg = .default },

    .scrollbar = .{ .fg = .bright_black, .bg = .default },

    .error_border = .{ .fg = .red, .bg = .default },
    .error_text = .{ .fg = .red, .bg = .default },
};

pub const light = Theme{
    .normal = .{ .fg = .black, .bg = .default },
    .muted = .{ .fg = .bright_black, .bg = .default },

    .border = .{ .fg = .bright_black, .bg = .default },
    .border_focused = .{ .fg = .blue, .bg = .default },

    .selection = .{ .fg = .white, .bg = .blue },

    .status_bar = .{ .fg = .white, .bg = .black },
    .status_loading = .{ .fg = .black, .bg = .yellow },
    .status_error = .{ .fg = .white, .bg = .red },
    .status_muted = .{ .fg = .bright_black, .bg = .black },

    .header = .{ .fg = .blue, .bg = .default, .bold = true },
    .header_selected = .{ .fg = .white, .bg = .blue, .bold = true },
    .row_selected = .{ .fg = .black, .bg = .bright_white },
    .cell_selected = .{ .fg = .white, .bg = .blue },
    .null_value = .{ .fg = .bright_black, .bg = .default },

    .syntax_keyword = .{ .fg = .magenta, .bg = .default, .bold = true },
    .syntax_string = .{ .fg = .green, .bg = .default },
    .syntax_number = .{ .fg = .yellow, .bg = .default },
    .syntax_comment = .{ .fg = .bright_black, .bg = .default },
    .syntax_operator = .{ .fg = .blue, .bg = .default },

    .modal_bg = .{ .fg = .black, .bg = .white },
    .modal_border = .{ .fg = .blue, .bg = .white },
    .modal_overlay = .{ .fg = .default, .bg = .default },

    .button = .{ .fg = .black, .bg = .bright_white },
    .button_primary = .{ .fg = .white, .bg = .blue },

    .line_number = .{ .fg = .bright_black, .bg = .default },

    .scrollbar = .{ .fg = .bright_black, .bg = .default },

    .error_border = .{ .fg = .red, .bg = .default },
    .error_text = .{ .fg = .red, .bg = .default },
};
