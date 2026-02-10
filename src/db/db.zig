const std = @import("std");
const types = @import("types.zig");
const postgresql = @import("drivers/postgresql.zig");
const events = @import("../events.zig");
const async_mod = @import("../async.zig");

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

pub const Connection = struct {
    driver: Driver,
    allocator: std.mem.Allocator,

    pub const Driver = union(enum) {
        postgresql: postgresql.Connection,
    };

    pub fn connectPostgreSQL(allocator: std.mem.Allocator, conninfo: []const u8) !Connection {
        const pg_conn = try postgresql.Connection.connect(allocator, conninfo);
        return Connection{
            .driver = .{ .postgresql = pg_conn },
            .allocator = allocator,
        };
    }

    pub fn disconnect(self: *Connection) void {
        switch (self.driver) {
            .postgresql => |*pg| pg.disconnect(),
        }
    }

    pub fn execute(self: *Connection, sql: []const u8) !types.QueryData {
        return switch (self.driver) {
            .postgresql => |*pg| try pg.execute(sql),
        };
    }

    pub fn listDatabases(self: *Connection) ![]types.Database {
        return switch (self.driver) {
            .postgresql => |*pg| try pg.listDatabases(),
        };
    }

    pub fn listSchemas(self: *Connection) ![]types.Schema {
        return switch (self.driver) {
            .postgresql => |*pg| try pg.listSchemas(),
        };
    }

    pub fn listTables(self: *Connection, schema: []const u8) ![]types.Table {
        return switch (self.driver) {
            .postgresql => |*pg| try pg.listTables(schema),
        };
    }

    pub fn listColumns(self: *Connection, schema: []const u8, table: []const u8) ![]types.Column {
        return switch (self.driver) {
            .postgresql => |*pg| try pg.listColumns(schema, table),
        };
    }
};

const AsyncQueryContext = struct {
    connection: *Connection,
    sql: []const u8,
    allocator: std.mem.Allocator,
    queue: *async_mod.AsyncQueue,
};

fn executeQueryThread(ctx: *AsyncQueryContext) void {
    defer ctx.allocator.destroy(ctx);
    defer ctx.allocator.free(ctx.sql);

    const result = ctx.connection.execute(ctx.sql) catch {
        // Memory leak fix: Use a static error message instead of allocating
        // The error message will be displayed immediately and doesn't need to persist
        const error_msg = "Query execution failed";

        const error_event = events.Event{
            .query_error = .{
                .message = error_msg,
            },
        };
        ctx.queue.push(error_event);
        return;
    };

    const success_event = events.Event{
        .query_complete = .{
            .columns = result.columns,
            .rows = result.rows,
            .time_ms = result.time_ms,
            .affected = result.affected,
        },
    };
    ctx.queue.push(success_event);
}

pub fn executeAsync(connection: *Connection, sql: []const u8, queue: *async_mod.AsyncQueue) !void {
    const allocator = connection.allocator;

    const ctx = try allocator.create(AsyncQueryContext);
    ctx.* = .{
        .connection = connection,
        .sql = try allocator.dupe(u8, sql),
        .allocator = allocator,
        .queue = queue,
    };

    const thread = try std.Thread.spawn(.{}, executeQueryThread, .{ctx});
    thread.detach();
}

pub fn cancel(handle: *anyopaque) void {
    // TODO: Implement query cancellation
    _ = handle;
}
