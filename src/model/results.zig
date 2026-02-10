const std = @import("std");
const db_types = @import("../db/types.zig");

pub const ResultsState = struct {
    columns: []ColumnDisplay,
    rows: [][]?db_types.Cell,

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

// ColumnDisplay extends db_types.Column with UI-specific fields
pub const ColumnDisplay = struct {
    name: []const u8,
    data_type: []const u8,
    width: usize,

    pub fn fromDbColumn(col: db_types.Column) ColumnDisplay {
        return ColumnDisplay{
            .name = col.name,
            .data_type = col.data_type,
            .width = @max(col.name.len, 10), // Minimum width of 10
        };
    }
};

// Re-export Cell type from db_types for convenience
pub const Cell = db_types.Cell;
pub const Column = db_types.Column;
