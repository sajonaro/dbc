const std = @import("std");

pub const TreeState = struct {
    nodes: std.ArrayList(Node),
    selected: usize,
    scroll: usize,
    expanded: std.StringHashMap(bool),
};

pub const Node = struct {
    id: []const u8,
    label: []const u8,
    kind: NodeKind,
    depth: usize,
    parent_id: ?[]const u8,

    // For lazy loading
    children_loaded: bool,
};

pub const NodeKind = enum {
    connection,
    database,
    schema,
    table_folder,
    table,
    view,
    column,
    index,
    function,

    pub fn icon(self: NodeKind) []const u8 {
        return switch (self) {
            .connection => "[C]",
            .database => "[D]",
            .schema => "[S]",
            .table_folder => "[F]",
            .table => "[T]",
            .view => "[V]",
            .column => "[c]",
            .index => "[i]",
            .function => "[f]",
        };
    }
};
