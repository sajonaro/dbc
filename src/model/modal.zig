const std = @import("std");

pub const Modal = union(enum) {
    none,
    confirm: ConfirmModal,
    input: InputModal,
    err: ErrorModal,
    connect: ConnectModal,
};

pub const ConfirmModal = struct {
    title: []const u8,
    message: []const u8,
    confirm_label: []const u8 = "OK",
    cancel_label: []const u8 = "Cancel",
    on_confirm: *const fn (*State) void,
    on_cancel: ?*const fn (*State) void = null,
};

pub const InputModal = struct {
    title: []const u8,
    prompt: []const u8,
    buffer: std.ArrayList(u8),
    cursor: usize,
    on_submit: *const fn (*State, []const u8) void,
};

pub const ErrorModal = struct {
    title: []const u8,
    message: []const u8,
    details: ?[]const u8,
};

pub const ConnectModal = struct {
    driver: DbDriver,
    host: std.ArrayList(u8),
    port: std.ArrayList(u8),
    database: std.ArrayList(u8),
    user: std.ArrayList(u8),
    password: std.ArrayList(u8),
    focused_field: ConnectField,
};

pub const ConnectField = enum {
    driver,
    host,
    port,
    database,
    user,
    password,
};

// Forward declarations to avoid circular dependencies
const State = @import("../model.zig").State;
const DbDriver = @import("../model.zig").DbDriver;
