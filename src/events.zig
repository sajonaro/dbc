const std = @import("std");
const model = @import("model.zig");
const db_types = @import("db/types.zig");

pub const Event = union(enum) {
    // User input
    key: KeyEvent,
    mouse: MouseEvent,
    resize: Size,

    // Async completions
    query_complete: QueryCompleteEvent,
    query_error: QueryErrorEvent,
    connect_complete: ConnectCompleteEvent,
    metadata_loaded: MetadataLoadedEvent,

    // Timers
    tick,
};

pub const QueryCompleteEvent = struct {
    columns: []db_types.Column,
    rows: [][]?db_types.Cell,
    time_ms: u64,
    affected: ?u64,
};

pub const QueryErrorEvent = struct {
    message: []const u8,
};

pub const ConnectCompleteEvent = struct {
    success: bool,
    error_message: ?[]const u8,
};

pub const MetadataLoadedEvent = struct {
    kind: enum { databases, schemas, tables, columns },
    databases: ?[]db_types.Database,
    schemas: ?[]db_types.Schema,
    tables: ?[]db_types.Table,
    columns: ?[]db_types.Column,
};

pub const KeyEvent = struct {
    key: Key,
    modifiers: Modifiers,

    pub const Modifiers = packed struct {
        ctrl: bool = false,
        alt: bool = false,
        shift: bool = false,
    };
};

pub const Key = union(enum) {
    char: u8,
    F1,
    F2,
    F3,
    F4,
    F5,
    F6,
    F7,
    F8,
    F9,
    F10,
    F11,
    F12,
    up,
    down,
    left,
    right,
    home,
    end,
    page_up,
    page_down,
    enter,
    tab,
    escape,
    backspace,
    delete,
};

pub const MouseEvent = struct {
    x: usize,
    y: usize,
    button: MouseButton,
    kind: MouseKind,
};

pub const MouseButton = enum {
    left,
    right,
    middle,
};

pub const MouseKind = enum {
    press,
    release,
    drag,
};

pub const Size = struct {
    width: usize,
    height: usize,
};
