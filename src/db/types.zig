const std = @import("std");

pub const DbError = struct {
    message: []const u8,
    details: ?[]const u8,
};

pub const QueryData = struct {
    columns: []Column,
    rows: [][]?Cell,
    time_ms: u64,
    affected: ?u64,
};

pub const Column = struct {
    name: []const u8,
    data_type: []const u8,
};

pub const Cell = struct {
    value: []const u8,
    is_null: bool,
};

pub const Database = struct {
    name: []const u8,
};

pub const Schema = struct {
    name: []const u8,
};

pub const Table = struct {
    name: []const u8,
    schema: []const u8,
};
