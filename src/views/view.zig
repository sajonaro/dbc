const std = @import("std");
const model = @import("../model.zig");
const theme = @import("../theme.zig");

/// Context passed to all views
pub const RenderContext = struct {
    state: *const model.State,
    theme: *const theme.Theme,
};

// Note: All views follow this pattern:
// fn render(ctx: RenderContext, win: *ui.Window) void
