const std = @import("std");
const view = @import("view.zig");

pub const RenderContext = view.RenderContext;

pub fn render(ctx: RenderContext, screen: *anyopaque) void {
    // TODO: Implement main view composition
    // - Calculate layout
    // - Render tree, editor, results, status panels
    // - Render modal if present
    _ = ctx;
    _ = screen;
}
