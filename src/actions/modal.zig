const std = @import("std");
const model = @import("../model.zig");
const events = @import("../events.zig");

pub fn handleKey(state: *model.State, key_event: events.KeyEvent) void {
    switch (state.modal) {
        .none => {},
        .confirm => handleConfirmModal(state, key_event),
        .input => handleInputModal(state, key_event),
        .err => handleErrorModal(state, key_event),
        .connect => handleConnectModal(state, key_event),
    }
}

fn handleConfirmModal(state: *model.State, key_event: events.KeyEvent) void {
    switch (key_event.key) {
        .enter => {
            // TODO: Call confirm callback
            state.modal = .none;
        },
        .escape => {
            // TODO: Call cancel callback if exists
            state.modal = .none;
        },
        else => {},
    }
}

fn handleInputModal(state: *model.State, key_event: events.KeyEvent) void {
    // TODO: Implement input modal key handling
    switch (key_event.key) {
        .enter => {
            // TODO: Call submit callback with input text
            state.modal = .none;
        },
        .escape => {
            state.modal = .none;
        },
        else => {},
    }
}

fn handleErrorModal(state: *model.State, key_event: events.KeyEvent) void {
    switch (key_event.key) {
        .enter, .escape => {
            state.modal = .none;
        },
        else => {},
    }
}

fn handleConnectModal(state: *model.State, key_event: events.KeyEvent) void {
    if (state.modal != .connect) return;

    var connect = &state.modal.connect;

    switch (key_event.key) {
        .up => {
            // Navigate to previous field
            connect.focused_field = switch (connect.focused_field) {
                .driver => .driver,
                .host => .driver,
                .port => .host,
                .database => .port,
                .user => .database,
                .password => .user,
            };
        },
        .down, .tab => {
            // Navigate to next field
            connect.focused_field = switch (connect.focused_field) {
                .driver => .host,
                .host => .port,
                .port => .database,
                .database => .user,
                .user => .password,
                .password => .password,
            };
        },
        .enter => {
            // Submit connection form
            submitConnection(state);
        },
        .escape => {
            // Clean up modal (get allocator from editor which has it)
            const allocator = state.editor.allocator;
            connect.host.deinit(allocator);
            connect.port.deinit(allocator);
            connect.database.deinit(allocator);
            connect.user.deinit(allocator);
            connect.password.deinit(allocator);
            state.modal = .none;
        },
        .backspace => {
            // Delete character from current field
            const field = getCurrentField(connect);
            if (field.items.len > 0) {
                _ = field.pop();
            }
        },
        .char => |c| {
            // Add character to current field
            const allocator = state.editor.allocator;
            const field = getCurrentField(connect);
            field.append(allocator, c) catch {};
        },
        else => {},
    }
}

fn getCurrentField(connect: *model.ConnectModal) *std.ArrayList(u8) {
    return switch (connect.focused_field) {
        .driver => &connect.host, // Driver is read-only, default to host
        .host => &connect.host,
        .port => &connect.port,
        .database => &connect.database,
        .user => &connect.user,
        .password => &connect.password,
    };
}

fn submitConnection(state: *model.State) void {
    if (state.modal != .connect) return;

    const connect = &state.modal.connect;
    const allocator = state.editor.allocator;

    // Build connection string
    const conninfo = std.fmt.allocPrint(allocator, "postgresql://{s}:{s}@{s}:{s}/{s}", .{
        connect.user.items,
        connect.password.items,
        connect.host.items,
        connect.port.items,
        connect.database.items,
    }) catch {
        state.status = .{ .err = .{
            .message = "Failed to build connection string",
            .details = null,
            .source = .internal,
        } };
        return;
    };
    defer allocator.free(conninfo);

    // Attempt to connect
    const db = @import("../db/db.zig");
    var connection = db.Connection.connectPostgreSQL(allocator, conninfo) catch |err| {
        const err_msg = std.fmt.allocPrint(allocator, "Failed to connect: {}", .{err}) catch "Connection failed";
        // Memory leak fix: Free error message when overwriting status
        defer if (!std.mem.eql(u8, err_msg, "Connection failed")) allocator.free(err_msg);

        state.status = .{ .err = .{
            .message = err_msg,
            .details = null,
            .source = .database,
        } };
        return;
    };

    // Store connection in state
    const conn_ptr = allocator.create(db.Connection) catch {
        connection.disconnect();
        state.status = .{ .err = .{
            .message = "Failed to allocate connection",
            .details = null,
            .source = .internal,
        } };
        return;
    };
    conn_ptr.* = connection;
    state.db_connection = conn_ptr;

    // Add connection to tree
    const conn_name = std.fmt.allocPrint(allocator, "{s}@{s}:{s}", .{ connect.user.items, connect.host.items, connect.port.items }) catch "New Connection";
    // Memory leak fix: If allocation fails, we use a string literal, so only free if not the default
    errdefer if (!std.mem.eql(u8, conn_name, "New Connection")) allocator.free(conn_name);

    const conn_id = std.fmt.allocPrint(allocator, "conn_{d}", .{std.time.timestamp()}) catch "conn_new";
    // Memory leak fix: If allocation fails, we use a string literal, so only free if not the default
    errdefer if (!std.mem.eql(u8, conn_id, "conn_new")) allocator.free(conn_id);

    state.tree.nodes.insert(allocator, 1, .{
        .id = conn_id,
        .label = conn_name,
        .kind = .connection,
        .depth = 0,
        .parent_id = null,
        .children_loaded = false,
    }) catch {
        // Memory leak fix: Free allocated strings if insert fails
        if (!std.mem.eql(u8, conn_name, "New Connection")) allocator.free(conn_name);
        if (!std.mem.eql(u8, conn_id, "conn_new")) allocator.free(conn_id);
    };

    // Clean up modal
    connect.host.deinit(allocator);
    connect.port.deinit(allocator);
    connect.database.deinit(allocator);
    connect.user.deinit(allocator);
    connect.password.deinit(allocator);
    state.modal = .none;

    state.status = .{ .idle = "Connected successfully!" };
}
