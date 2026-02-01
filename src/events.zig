const std = @import("std");
const model = @import("model.zig");
const db = @import("db/db.zig");

pub const Event = union(enum) {
    // User input
    key: KeyEvent,
    mouse: MouseEvent,
    resize: Size,

    // Async completions
    query_complete: db.QueryResult,
    connect_complete: db.ConnectResult,
    metadata_loaded: db.MetadataResult,

    // Timers
    tick,
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
