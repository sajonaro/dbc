const std = @import("std");
const types = @import("types.zig");

pub const QueryResult = union(enum) {
    success: types.QueryData,
    failure: types.DbError,
};

pub const ConnectResult = union(enum) {
    success: *anyopaque,
    failure: types.DbError,
};

pub const MetadataResult = union(enum) {
    databases: []types.Database,
    schemas: []types.Schema,
    tables: []types.Table,
    columns: []types.Column,
};

pub fn executeAsync(handle: *anyopaque, sql: []const u8, queue: *anyopaque) void {
    // TODO: Implement async query execution
    _ = handle;
    _ = sql;
    _ = queue;
}

pub fn cancel(handle: *anyopaque) void {
    // TODO: Implement query cancellation
    _ = handle;
}
