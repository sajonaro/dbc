const std = @import("std");
const model = @import("../model.zig");
const events = @import("../events.zig");

pub fn handleKey(state: *model.State, key_event: events.KeyEvent) void {
    const results = &state.results;

    // Handle Ctrl key combinations
    if (key_event.modifiers.ctrl) {
        switch (key_event.key) {
            .char => |ch| {
                switch (ch) {
                    'c' => copyCell(results),
                    'e' => exportResults(results),
                    else => {},
                }
            },
            .home => navigateFirstRow(results),
            .end => navigateLastRow(results),
            else => {},
        }
        return;
    }

    // Handle regular keys
    switch (key_event.key) {
        .up => navigateUp(results),
        .down => navigateDown(results),
        .left => navigateLeft(results),
        .right => navigateRight(results),
        .home => navigateRowStart(results),
        .end => navigateRowEnd(results),
        .page_up => pageUp(results),
        .page_down => pageDown(results),
        .enter => viewCellInModal(state),
        else => {},
    }
}

fn navigateUp(results: *model.ResultsState) void {
    if (results.selected_row > 0) {
        results.selected_row -= 1;
        ensureRowVisible(results);
    }
}

fn navigateDown(results: *model.ResultsState) void {
    if (results.rows.len > 0 and results.selected_row < results.rows.len - 1) {
        results.selected_row += 1;
        ensureRowVisible(results);
    }
}

fn navigateLeft(results: *model.ResultsState) void {
    if (results.selected_col > 0) {
        results.selected_col -= 1;
        ensureColVisible(results);
    }
}

fn navigateRight(results: *model.ResultsState) void {
    if (results.columns.len > 0 and results.selected_col < results.columns.len - 1) {
        results.selected_col += 1;
        ensureColVisible(results);
    }
}

fn navigateRowStart(results: *model.ResultsState) void {
    results.selected_col = 0;
    results.scroll_col = 0;
}

fn navigateRowEnd(results: *model.ResultsState) void {
    if (results.columns.len > 0) {
        results.selected_col = results.columns.len - 1;
        ensureColVisible(results);
    }
}

fn navigateFirstRow(results: *model.ResultsState) void {
    results.selected_row = 0;
    results.scroll_row = 0;
}

fn navigateLastRow(results: *model.ResultsState) void {
    if (results.rows.len > 0) {
        results.selected_row = results.rows.len - 1;
        ensureRowVisible(results);
    }
}

fn pageUp(results: *model.ResultsState) void {
    const page_size: usize = 20; // Visible rows
    if (results.selected_row > page_size) {
        results.selected_row -= page_size;
    } else {
        results.selected_row = 0;
    }
    ensureRowVisible(results);
}

fn pageDown(results: *model.ResultsState) void {
    const page_size: usize = 20; // Visible rows
    if (results.rows.len > 0) {
        const new_row = results.selected_row + page_size;
        results.selected_row = @min(new_row, results.rows.len - 1);
        ensureRowVisible(results);
    }
}

fn copyCell(results: *model.ResultsState) void {
    // TODO: Implement clipboard copy
    _ = results;
}

fn exportResults(results: *model.ResultsState) void {
    // TODO: Show export dialog
    _ = results;
}

fn viewCellInModal(state: *model.State) void {
    // TODO: Show cell value in a modal for large values
    _ = state;
}

fn ensureRowVisible(results: *model.ResultsState) void {
    const visible_rows: usize = 20;

    if (results.selected_row < results.scroll_row) {
        results.scroll_row = results.selected_row;
    } else if (results.selected_row >= results.scroll_row + visible_rows) {
        results.scroll_row = results.selected_row - visible_rows + 1;
    }
}

fn ensureColVisible(results: *model.ResultsState) void {
    // TODO: Implement horizontal scrolling based on column widths
    _ = results;
}
