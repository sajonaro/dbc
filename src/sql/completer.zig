const std = @import("std");

pub const Completion = struct {
    text: []const u8,
    kind: CompletionKind,
};

pub const CompletionKind = enum {
    keyword,
    table,
    column,
    function,
};

pub fn getCompletions(sql: []const u8, cursor_pos: usize) []Completion {
    // TODO: Implement autocomplete logic
    _ = sql;
    _ = cursor_pos;
    return &.{};
}
