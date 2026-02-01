const std = @import("std");

pub fn format(allocator: std.mem.Allocator, sql: []const u8) ![]const u8 {
    // TODO: Implement SQL formatter
    _ = allocator;
    return sql;
}
