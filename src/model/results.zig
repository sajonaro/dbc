const std = @import("std");

pub const ResultsState = struct {
    columns: []Column,
    rows: [][]?Cell,

    // Navigation
    selected_row: usize,
    selected_col: usize,
    scroll_row: usize,
    scroll_col: usize,

    // Metadata
    row_count: usize,
    execution_time_ms: u64,
    affected_rows: ?u64,
};

pub const Column = struct {
    name: []const u8,
    data_type: []const u8,
    nullable: bool,
    width: usize,
};

pub const Cell = struct {
    value: []const u8,
    is_null: bool,
};
