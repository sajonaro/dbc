const std = @import("std");

pub const EditorState = struct {
    allocator: std.mem.Allocator,
    buffer: std.ArrayList(u8),
    cursor: Position,
    scroll: Position,
    selection: ?Selection,

    // File tracking
    current_file: ?[]const u8,

    // State flags
    modified: bool,
    executing: bool,

    // Undo/redo
    undo_stack: std.ArrayList(Snapshot),
    redo_stack: std.ArrayList(Snapshot),
};

pub const Position = struct {
    row: usize,
    col: usize,
};

pub const Selection = struct {
    start: Position,
    end: Position,
};

pub const Snapshot = struct {
    buffer: []const u8,
    cursor: Position,
};
