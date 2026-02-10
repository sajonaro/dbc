const std = @import("std");
const types = @import("../types.zig");

// PostgreSQL C library binding
const c = @cImport({
    @cInclude("libpq-fe.h");
});

pub const Connection = struct {
    conn: ?*c.PGconn,
    allocator: std.mem.Allocator,

    pub fn connect(allocator: std.mem.Allocator, conninfo: []const u8) !Connection {
        // Create null-terminated string for libpq
        const conninfo_z = try allocator.dupeZ(u8, conninfo);
        defer allocator.free(conninfo_z);

        const conn = c.PQconnectdb(conninfo_z.ptr);

        if (c.PQstatus(conn) != c.CONNECTION_OK) {
            _ = c.PQerrorMessage(conn);
            c.PQfinish(conn);
            return error.ConnectionFailed;
        }

        return Connection{
            .conn = conn,
            .allocator = allocator,
        };
    }

    pub fn disconnect(self: *Connection) void {
        if (self.conn) |conn| {
            c.PQfinish(conn);
            self.conn = null;
        }
    }

    pub fn execute(self: *Connection, sql: []const u8) !types.QueryData {
        const sql_z = try self.allocator.dupeZ(u8, sql);
        defer self.allocator.free(sql_z);

        const start_time = std.time.milliTimestamp();
        const res = c.PQexec(self.conn, sql_z.ptr);
        const end_time = std.time.milliTimestamp();

        if (res == null) {
            // Connection-level error shown in UI via getLastError()
            _ = c.PQerrorMessage(self.conn);
            return error.QueryFailed;
        }
        defer c.PQclear(res);

        const status = c.PQresultStatus(res);

        // Handle different result statuses
        switch (status) {
            c.PGRES_TUPLES_OK => {
                // SELECT query - has result set
                return try self.buildQueryData(res.?, @intCast(end_time - start_time), null);
            },
            c.PGRES_COMMAND_OK => {
                // INSERT/UPDATE/DELETE - no result set
                const affected_str = c.PQcmdTuples(res);
                const affected = if (std.mem.len(affected_str) > 0)
                    try std.fmt.parseInt(u64, std.mem.span(affected_str), 10)
                else
                    0;

                return types.QueryData{
                    .columns = &.{},
                    .rows = &.{},
                    .time_ms = @intCast(end_time - start_time),
                    .affected = affected,
                };
            },
            else => {
                // Get detailed error message from result
                // Error shown in UI via getLastError()
                _ = c.PQresultErrorMessage(res);
                return error.QueryFailed;
            },
        }
    }

    pub fn getLastError(self: *Connection) []const u8 {
        if (self.conn) |conn| {
            return std.mem.span(c.PQerrorMessage(conn));
        }
        return "No connection";
    }

    fn buildQueryData(self: *Connection, res: *c.PGresult, time_ms: u64, affected: ?u64) !types.QueryData {
        const n_cols = c.PQnfields(res);
        const n_rows = c.PQntuples(res);

        // Build columns
        var columns = try self.allocator.alloc(types.Column, @intCast(n_cols));
        for (0..@intCast(n_cols)) |i| {
            const col_name = c.PQfname(res, @intCast(i));
            const col_type = c.PQftype(res, @intCast(i));

            columns[i] = types.Column{
                .name = try self.allocator.dupe(u8, std.mem.span(col_name)),
                .data_type = try self.pgTypeToString(col_type),
            };
        }

        // Build rows
        var rows = try self.allocator.alloc([]?types.Cell, @intCast(n_rows));
        for (0..@intCast(n_rows)) |row_idx| {
            var row = try self.allocator.alloc(?types.Cell, @intCast(n_cols));

            for (0..@intCast(n_cols)) |col_idx| {
                const is_null = c.PQgetisnull(res, @intCast(row_idx), @intCast(col_idx)) == 1;

                if (is_null) {
                    row[col_idx] = null;
                } else {
                    const value = c.PQgetvalue(res, @intCast(row_idx), @intCast(col_idx));
                    row[col_idx] = types.Cell{
                        .value = try self.allocator.dupe(u8, std.mem.span(value)),
                        .is_null = false,
                    };
                }
            }

            rows[row_idx] = row;
        }

        return types.QueryData{
            .columns = columns,
            .rows = rows,
            .time_ms = time_ms,
            .affected = affected,
        };
    }

    fn pgTypeToString(self: *Connection, oid: c_uint) ![]const u8 {
        // Common PostgreSQL type OIDs
        const type_name = switch (oid) {
            16 => "bool",
            20 => "bigint",
            21 => "smallint",
            23 => "integer",
            25 => "text",
            1043 => "varchar",
            1082 => "date",
            1114 => "timestamp",
            1184 => "timestamptz",
            else => "unknown",
        };

        return try self.allocator.dupe(u8, type_name);
    }

    pub fn listDatabases(self: *Connection) ![]types.Database {
        const sql = "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname;";
        const query_data = try self.execute(sql);

        var databases = try self.allocator.alloc(types.Database, query_data.rows.len);
        for (query_data.rows, 0..) |row, i| {
            if (row[0]) |cell| {
                databases[i] = types.Database{
                    .name = try self.allocator.dupe(u8, cell.value),
                };
            }
        }

        return databases;
    }

    pub fn listSchemas(self: *Connection) ![]types.Schema {
        const sql =
            \\SELECT schema_name 
            \\FROM information_schema.schemata 
            \\WHERE schema_name NOT IN ('pg_catalog', 'information_schema')
            \\ORDER BY schema_name;
        ;

        const query_data = try self.execute(sql);
        // Memory leak fix: Free query_data after extracting needed info
        defer {
            // Free columns
            if (query_data.columns.len > 0) {
                for (query_data.columns) |col| {
                    self.allocator.free(col.name);
                    self.allocator.free(col.data_type);
                }
                self.allocator.free(query_data.columns);
            }
            // Free rows
            for (query_data.rows) |row| {
                for (row) |cell_opt| {
                    if (cell_opt) |cell| {
                        if (!cell.is_null) {
                            self.allocator.free(cell.value);
                        }
                    }
                }
                self.allocator.free(row);
            }
            if (query_data.rows.len > 0) {
                self.allocator.free(query_data.rows);
            }
        }

        var schemas = try self.allocator.alloc(types.Schema, query_data.rows.len);
        for (query_data.rows, 0..) |row, i| {
            if (row[0]) |cell| {
                schemas[i] = types.Schema{
                    .name = try self.allocator.dupe(u8, cell.value),
                };
            }
        }

        return schemas;
    }

    pub fn listTables(self: *Connection, schema: []const u8) ![]types.Table {
        const sql = try std.fmt.allocPrint(self.allocator,
            \\SELECT table_name, table_schema
            \\FROM information_schema.tables
            \\WHERE table_schema = '{s}' AND table_type = 'BASE TABLE'
            \\ORDER BY table_name;
        , .{schema});
        defer self.allocator.free(sql);

        const query_data = try self.execute(sql);
        // Memory leak fix: Free query_data after extracting needed info
        defer {
            // Free columns
            if (query_data.columns.len > 0) {
                for (query_data.columns) |col| {
                    self.allocator.free(col.name);
                    self.allocator.free(col.data_type);
                }
                self.allocator.free(query_data.columns);
            }
            // Free rows
            for (query_data.rows) |row| {
                for (row) |cell_opt| {
                    if (cell_opt) |cell| {
                        if (!cell.is_null) {
                            self.allocator.free(cell.value);
                        }
                    }
                }
                self.allocator.free(row);
            }
            if (query_data.rows.len > 0) {
                self.allocator.free(query_data.rows);
            }
        }

        var tables = try self.allocator.alloc(types.Table, query_data.rows.len);
        for (query_data.rows, 0..) |row, i| {
            const name = if (row[0]) |cell| cell.value else "";
            const schema_name = if (row[1]) |cell| cell.value else "";

            tables[i] = types.Table{
                .name = try self.allocator.dupe(u8, name),
                .schema = try self.allocator.dupe(u8, schema_name),
            };
        }

        return tables;
    }

    pub fn listColumns(self: *Connection, schema: []const u8, table: []const u8) ![]types.Column {
        const sql = try std.fmt.allocPrint(self.allocator,
            \\SELECT column_name, data_type
            \\FROM information_schema.columns
            \\WHERE table_schema = '{s}' AND table_name = '{s}'
            \\ORDER BY ordinal_position;
        , .{ schema, table });
        defer self.allocator.free(sql);

        const query_data = try self.execute(sql);

        var columns = try self.allocator.alloc(types.Column, query_data.rows.len);
        for (query_data.rows, 0..) |row, i| {
            const name = if (row[0]) |cell| cell.value else "";
            const data_type = if (row[1]) |cell| cell.value else "";

            columns[i] = types.Column{
                .name = try self.allocator.dupe(u8, name),
                .data_type = try self.allocator.dupe(u8, data_type),
            };
        }

        return columns;
    }

    pub fn getTableDDL(self: *Connection, schema: []const u8, table: []const u8) ![]const u8 {
        // Simplified DDL generation - can be enhanced later
        const columns = try self.listColumns(schema, table);

        var ddl = std.ArrayList(u8).init(self.allocator);
        defer ddl.deinit();

        try ddl.appendSlice("CREATE TABLE ");
        try ddl.appendSlice(schema);
        try ddl.append('.');
        try ddl.appendSlice(table);
        try ddl.appendSlice(" (\n");

        for (columns, 0..) |col, i| {
            try ddl.appendSlice("  ");
            try ddl.appendSlice(col.name);
            try ddl.append(' ');
            try ddl.appendSlice(col.data_type);

            if (i < columns.len - 1) {
                try ddl.appendSlice(",\n");
            } else {
                try ddl.append('\n');
            }
        }

        try ddl.appendSlice(");");

        return try ddl.toOwnedSlice();
    }
};
