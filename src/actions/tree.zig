const std = @import("std");
const model = @import("../model.zig");
const events = @import("../events.zig");

pub fn handleKey(state: *model.State, key_event: events.KeyEvent) void {
    const tree = &state.tree;

    switch (key_event.key) {
        .up => navigateUp(tree),
        .down => navigateDown(tree),
        .left => collapseNode(tree),
        .right => expandNode(tree),
        .enter => activateNode(state),
        .home => navigateHome(tree),
        .end => navigateEnd(tree),
        else => {},
    }
}

fn navigateUp(tree: *model.TreeState) void {
    if (tree.selected > 0) {
        tree.selected -= 1;
        ensureVisible(tree);
    }
}

fn navigateDown(tree: *model.TreeState) void {
    if (tree.nodes.items.len > 0 and tree.selected < tree.nodes.items.len - 1) {
        tree.selected += 1;
        ensureVisible(tree);
    }
}

fn navigateHome(tree: *model.TreeState) void {
    tree.selected = 0;
    tree.scroll = 0;
}

fn navigateEnd(tree: *model.TreeState) void {
    if (tree.nodes.items.len > 0) {
        tree.selected = tree.nodes.items.len - 1;
        ensureVisible(tree);
    }
}

fn collapseNode(tree: *model.TreeState) void {
    if (tree.nodes.items.len == 0) return;

    const node = tree.nodes.items[tree.selected];

    // If node is expanded, collapse it
    if (tree.expanded.get(node.id)) |is_expanded| {
        if (is_expanded) {
            tree.expanded.put(node.id, false) catch {};
            return;
        }
    }

    // Otherwise, navigate to parent
    if (node.parent_id) |parent_id| {
        // Find parent node
        for (tree.nodes.items, 0..) |n, i| {
            if (std.mem.eql(u8, n.id, parent_id)) {
                tree.selected = i;
                ensureVisible(tree);
                break;
            }
        }
    }
}

fn expandNode(tree: *model.TreeState) void {
    if (tree.nodes.items.len == 0) return;

    const node = tree.nodes.items[tree.selected];

    // Check if node is expandable
    const is_expandable = switch (node.kind) {
        .connection, .database, .schema, .table_folder, .table => true,
        else => false,
    };

    if (!is_expandable) return;

    // Expand the node
    tree.expanded.put(node.id, true) catch {};

    // TODO: If children not loaded, trigger lazy loading
}

fn activateNode(state: *model.State) void {
    const tree = &state.tree;
    if (tree.nodes.items.len == 0) return;

    const node = tree.nodes.items[tree.selected];

    // Check if it's the "New Connection" node
    if (std.mem.eql(u8, node.id, "new_connection")) {
        openConnectModal(state);
        return;
    }

    switch (node.kind) {
        .table => {
            // Find the schema node (parent of parent)
            var schema_name: []const u8 = "public"; // Default to public

            if (node.parent_id) |parent_id| {
                // Find parent node (should be a schema)
                for (tree.nodes.items) |n| {
                    if (std.mem.eql(u8, n.id, parent_id)) {
                        if (n.kind == .schema) {
                            schema_name = n.label;
                        }
                        break;
                    }
                }
            }

            // Generate SELECT * query for table with schema qualification
            var query_buf: [256]u8 = undefined;
            const query = std.fmt.bufPrint(&query_buf, "SELECT * FROM {s}.{s} LIMIT 100;", .{ schema_name, node.label }) catch return;

            // Update editor buffer
            state.editor.buffer.clearRetainingCapacity();
            state.editor.buffer.appendSlice(state.editor.allocator, query) catch return;
            state.editor.cursor = .{ .row = 0, .col = query.len };
            state.editor.modified = true;

            // Switch focus to editor
            state.focus = .editor;
            state.status = .{ .idle = "Query template generated" };
        },
        .connection => {
            // Check if already expanded
            const is_expanded = tree.expanded.get(node.id) orelse false;

            if (is_expanded) {
                // Already expanded, collapse it
                tree.expanded.put(node.id, false) catch {};
            } else {
                // Load child nodes if not already loaded
                if (!node.children_loaded) {
                    loadConnectionChildren(state, node.id, tree.selected) catch {
                        state.status = .{ .err = .{
                            .message = "Failed to load database metadata",
                            .details = null,
                            .source = .database,
                        } };
                        return;
                    };
                }
                // Expand
                tree.expanded.put(node.id, true) catch {};
            }
        },
        .database, .schema, .table_folder, .view, .function => {
            // Check if already expanded
            const is_expanded = tree.expanded.get(node.id) orelse false;

            if (is_expanded) {
                // Already expanded, collapse it
                tree.expanded.put(node.id, false) catch {};
            } else {
                // Load child nodes if not already loaded
                if (!node.children_loaded) {
                    loadTableFolderChildren(state, node.id, tree.selected) catch {
                        state.status = .{ .err = .{
                            .message = "Failed to load items",
                            .details = null,
                            .source = .database,
                        } };
                        return;
                    };
                }
                // Expand
                tree.expanded.put(node.id, true) catch {};
            }
        },
        else => {},
    }
}

fn openConnectModal(state: *model.State) void {
    const allocator = state.editor.allocator;

    state.modal = .{
        .connect = .{
            .driver = .postgresql,
            .host = .{ .items = &.{}, .capacity = 0 },
            .port = .{ .items = &.{}, .capacity = 0 },
            .database = .{ .items = &.{}, .capacity = 0 },
            .user = .{ .items = &.{}, .capacity = 0 },
            .password = .{ .items = &.{}, .capacity = 0 },
            .focused_field = .host,
        },
    };

    // Pre-fill with defaults
    state.modal.connect.host.appendSlice(allocator, "localhost") catch {};
    state.modal.connect.port.appendSlice(allocator, "5433") catch {};
    state.modal.connect.database.appendSlice(allocator, "testdb") catch {};
    state.modal.connect.user.appendSlice(allocator, "dbcuser") catch {};

    state.status = .{ .idle = "Fill in connection details and press Enter to connect" };
}

fn loadConnectionChildren(state: *model.State, parent_id: []const u8, parent_index: usize) !void {
    const allocator = state.editor.allocator;
    const tree = &state.tree;

    // Get database connection
    const db_conn = state.db_connection orelse return error.NoConnection;

    // Get list of schemas from database (for future use)
    const schemas = try db_conn.driver.postgresql.listSchemas();
    defer {
        // Memory leak fix: Free schema names
        for (schemas) |schema| {
            allocator.free(schema.name);
        }
        allocator.free(schemas);
    }

    // For now, create a simple structure:
    // - Tables folder
    // - Views folder (stub)
    // - Functions folder (stub)
    // - Stored Procedures folder (stub)

    const insert_pos = parent_index + 1;

    // Create Tables folder
    const tables_id = try std.fmt.allocPrint(allocator, "{s}_tables", .{parent_id});
    errdefer allocator.free(tables_id);
    try tree.nodes.insert(allocator, insert_pos, .{
        .id = tables_id,
        .label = "Tables",
        .kind = .table_folder,
        .depth = 1,
        .parent_id = parent_id,
        .children_loaded = false, // Will load actual tables on expand
    });

    // Create Views folder
    const views_id = try std.fmt.allocPrint(allocator, "{s}_views", .{parent_id});
    errdefer allocator.free(views_id);
    try tree.nodes.insert(allocator, insert_pos + 1, .{
        .id = views_id,
        .label = "Views",
        .kind = .view,
        .depth = 1,
        .parent_id = parent_id,
        .children_loaded = false, // Will load on expand
    });

    // Create Functions folder
    const funcs_id = try std.fmt.allocPrint(allocator, "{s}_functions", .{parent_id});
    errdefer allocator.free(funcs_id);
    try tree.nodes.insert(allocator, insert_pos + 2, .{
        .id = funcs_id,
        .label = "Functions",
        .kind = .function,
        .depth = 1,
        .parent_id = parent_id,
        .children_loaded = false, // Will load on expand
    });

    // Create Stored Procedures folder
    const procs_id = try std.fmt.allocPrint(allocator, "{s}_procedures", .{parent_id});
    errdefer allocator.free(procs_id);
    try tree.nodes.insert(allocator, insert_pos + 3, .{
        .id = procs_id,
        .label = "Stored Procedures",
        .kind = .function,
        .depth = 1,
        .parent_id = parent_id,
        .children_loaded = false, // Will load on expand
    });

    // Mark parent as having children loaded
    tree.nodes.items[parent_index].children_loaded = true;

    // Expand the parent node
    try tree.expanded.put(parent_id, true);
}

fn loadTableFolderChildren(state: *model.State, parent_id: []const u8, parent_index: usize) !void {
    const allocator = state.editor.allocator;
    const tree = &state.tree;

    // Get the parent node to determine what type of items to load
    const parent_node = tree.nodes.items[parent_index];

    // Get database connection
    const db_conn = state.db_connection orelse return error.NoConnection;

    // Get list of schemas
    const schemas = try db_conn.driver.postgresql.listSchemas();
    defer {
        // Memory leak fix: Free schema names
        for (schemas) |schema| {
            allocator.free(schema.name);
        }
        allocator.free(schemas);
    }

    if (schemas.len == 0) {
        tree.nodes.items[parent_index].children_loaded = true;
        return;
    }

    const insert_pos = parent_index + 1;
    var current_pos = insert_pos;

    // Load different items based on parent node kind
    switch (parent_node.kind) {
        .table_folder => {
            // Create schema nodes, each will contain tables
            for (schemas) |schema| {
                const schema_id = try std.fmt.allocPrint(allocator, "{s}_schema_{s}", .{ parent_id, schema.name });
                errdefer allocator.free(schema_id);
                // Need to duplicate the schema name since it will be freed in defer
                const schema_name_copy = try allocator.dupe(u8, schema.name);
                errdefer allocator.free(schema_name_copy);
                try tree.nodes.insert(allocator, current_pos, .{
                    .id = schema_id,
                    .label = schema_name_copy,
                    .kind = .schema,
                    .depth = 2,
                    .parent_id = parent_id,
                    .children_loaded = false, // Will load tables when expanded
                });
                current_pos += 1;
            }
        },
        .schema => {
            // Load tables for this schema
            // Extract schema name from parent node label
            const schema_name = parent_node.label;
            const tables = try db_conn.driver.postgresql.listTables(schema_name);
            defer {
                // Memory leak fix: Free table names and schemas
                for (tables) |table| {
                    allocator.free(table.name);
                    allocator.free(table.schema);
                }
                allocator.free(tables);
            }

            for (tables, 0..) |table, i| {
                // Use a static buffer for IDs instead of allocPrint to avoid leaks
                var id_buf: [256]u8 = undefined;
                const table_id = std.fmt.bufPrint(&id_buf, "{s}_table_{d}", .{ parent_id, i }) catch continue;

                const id_copy = try allocator.dupe(u8, table_id);
                errdefer allocator.free(id_copy);
                // Need to duplicate the table name since it will be freed in defer
                const table_name_copy = try allocator.dupe(u8, table.name);
                errdefer allocator.free(table_name_copy);
                try tree.nodes.insert(allocator, insert_pos + i, .{
                    .id = id_copy,
                    .label = table_name_copy,
                    .kind = .table,
                    .depth = 3,
                    .parent_id = parent_id,
                    .children_loaded = true,
                });
            }
        },
        .view, .function => {
            // For now, just mark as loaded with no children
            state.status = .{ .idle = "No items to display (not yet implemented)" };
        },
        else => {},
    }

    // Mark parent as having children loaded
    tree.nodes.items[parent_index].children_loaded = true;

    // Expand the parent node
    try tree.expanded.put(parent_id, true);
}

fn ensureVisible(tree: *model.TreeState) void {
    // Assume visible area height (will be calculated by view)
    const visible_height: usize = 20; // This should come from layout

    if (tree.selected < tree.scroll) {
        tree.scroll = tree.selected;
    } else if (tree.selected >= tree.scroll + visible_height) {
        tree.scroll = tree.selected - visible_height + 1;
    }
}
