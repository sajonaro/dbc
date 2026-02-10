const std = @import("std");
const view = @import("view.zig");
const ui = @import("../ui/ui.zig");
const tree_model = @import("../model/tree.zig");

pub fn render(ctx: view.RenderContext, win: *ui.Window, focused: bool) void {
    const tree = &ctx.state.tree;
    const th = ctx.theme;

    // Draw border
    const border_style = if (focused) th.border_focused else th.border;
    win.drawBorder(border_style, "Database Tree", focused) catch return;

    if (tree.nodes.items.len == 0) {
        // No nodes to display
        const empty_msg = "No connections";
        const msg_x = if (win.rect.w > empty_msg.len + 2) (win.rect.w - empty_msg.len) / 2 else 1;
        const msg_y = win.rect.h / 2;
        win.drawText(msg_y, msg_x, empty_msg, th.muted) catch return;
        return;
    }

    // Calculate visible area (exclude border)
    const content_height = if (win.rect.h > 2) win.rect.h - 2 else 0;
    const content_width = if (win.rect.w > 2) win.rect.w - 2 else 0;

    if (content_height == 0 or content_width == 0) return;

    // Ensure scroll is within bounds
    const max_scroll = if (tree.nodes.items.len > content_height)
        tree.nodes.items.len - content_height
    else
        0;
    const scroll = @min(tree.scroll, max_scroll);

    // Render visible nodes (skip hidden children of collapsed nodes)
    var line: usize = 0;
    var node_idx: usize = 0;
    var visible_count: usize = 0;

    while (node_idx < tree.nodes.items.len) : (node_idx += 1) {
        const node = tree.nodes.items[node_idx];

        // Check if this node should be visible (parent is expanded)
        const is_visible = isNodeVisible(tree, node_idx);

        if (!is_visible) {
            continue; // Skip this node
        }

        // This node is visible, check if we should render it
        if (visible_count >= scroll and line < content_height) {
            const is_selected = node_idx == tree.selected;
            const y = line + 1; // +1 for border

            // Determine style
            const style = if (is_selected) th.selection else th.normal;

            // Build the line to render
            var buf: [256]u8 = undefined;
            var fba = std.heap.FixedBufferAllocator.init(&buf);
            const allocator = fba.allocator();

            const line_text = formatTreeLine(allocator, node, tree.expanded, content_width) catch continue;

            // Fill the entire line with the style (for selection background)
            if (is_selected) {
                win.fillLine(y, ' ', style) catch {};
            }

            // Draw the text
            win.drawText(y, 1, line_text, style) catch {};

            line += 1;
        }

        visible_count += 1;
    }

    // Draw scrollbar if needed
    if (tree.nodes.items.len > content_height) {
        const scrollbar_x = win.rect.w - 1;
        win.drawScrollbar(
            scrollbar_x,
            tree.nodes.items.len,
            content_height,
            scroll,
            th.scrollbar,
        ) catch {};
    }
}

fn isNodeVisible(tree: *const tree_model.TreeState, node_idx: usize) bool {
    const node = tree.nodes.items[node_idx];

    // Root nodes are always visible
    if (node.parent_id == null) {
        return true;
    }

    // Find parent node
    for (tree.nodes.items, 0..) |n, i| {
        if (node.parent_id) |parent_id| {
            if (std.mem.eql(u8, n.id, parent_id)) {
                // Check if parent is expanded
                const parent_expanded = tree.expanded.get(parent_id) orelse false;

                if (!parent_expanded) {
                    return false; // Parent is collapsed, this node is hidden
                }

                // Parent is expanded, check if parent itself is visible
                return isNodeVisible(tree, i);
            }
        }
    }

    return true; // If parent not found, assume visible
}

fn formatTreeLine(
    allocator: std.mem.Allocator,
    node: tree_model.Node,
    expanded: std.StringHashMap(bool),
    max_width: usize,
) ![]const u8 {
    // Calculate indentation
    const indent_size = node.depth * 2;

    // Check if node is expandable (has potential children)
    // Tables are leaf nodes and shouldn't show expand indicator
    const is_expandable = switch (node.kind) {
        .connection, .database, .schema, .table_folder => true,
        .table => false, // Tables are leaves
        else => false,
    };

    const is_expanded = expanded.get(node.id) orelse false;

    // Build the line:
    // [indent][+/-/space][icon] [label]
    var parts = std.ArrayList(u8).initCapacity(allocator, 0) catch return error.OutOfMemory;

    // Indentation
    var i: usize = 0;
    while (i < indent_size) : (i += 1) {
        try parts.append(allocator, ' ');
    }

    // Expand/collapse indicator
    if (is_expandable) {
        const indicator = if (is_expanded) "- " else "+ ";
        try parts.appendSlice(allocator, indicator);
    } else {
        try parts.appendSlice(allocator, "  ");
    }

    // Icon
    const icon = node.kind.icon();
    try parts.appendSlice(allocator, icon);
    try parts.append(allocator, ' ');

    // Label (truncate if too long)
    const remaining_width = if (max_width > parts.items.len)
        max_width - parts.items.len
    else
        0;

    if (remaining_width > 0) {
        const label_len = @min(node.label.len, remaining_width);
        try parts.appendSlice(allocator, node.label[0..label_len]);
    }

    return parts.items;
}
