const std = @import("std");
const model = @import("../model.zig");
const events = @import("../events.zig");

pub fn handleKey(state: *model.State, key_event: events.KeyEvent) void {
    const editor = &state.editor;

    // Handle Ctrl key combinations
    if (key_event.modifiers.ctrl) {
        switch (key_event.key) {
            .char => |ch| {
                switch (ch) {
                    'a' => selectAll(editor),
                    'z' => undo(editor),
                    'y' => redo(editor),
                    'l' => formatSQL(editor),
                    else => {},
                }
            },
            else => {},
        }
        return;
    }

    // Handle regular keys
    switch (key_event.key) {
        .char => |ch| insertChar(editor, ch),
        .enter => insertNewline(editor),
        .backspace => handleBackspace(editor),
        .delete => handleDelete(editor),
        .up => moveCursorUp(editor),
        .down => moveCursorDown(editor),
        .left => moveCursorLeft(editor),
        .right => moveCursorRight(editor),
        .home => moveCursorHome(editor),
        .end => moveCursorEnd(editor),
        else => {},
    }
}

fn insertChar(editor: *model.EditorState, ch: u8) void {
    const pos = getCursorBytePosition(editor);
    editor.buffer.insert(editor.allocator, pos, ch) catch return;
    editor.cursor.col += 1;
    editor.modified = true;
    ensureCursorVisible(editor);
}

fn insertNewline(editor: *model.EditorState) void {
    const pos = getCursorBytePosition(editor);
    editor.buffer.insert(editor.allocator, pos, '\n') catch return;
    editor.cursor.row += 1;
    editor.cursor.col = 0;
    editor.modified = true;
    ensureCursorVisible(editor);
}

fn handleBackspace(editor: *model.EditorState) void {
    if (editor.cursor.col > 0) {
        const pos = getCursorBytePosition(editor);
        if (pos > 0) {
            _ = editor.buffer.orderedRemove(pos - 1);
            editor.cursor.col -= 1;
            editor.modified = true;
        }
    } else if (editor.cursor.row > 0) {
        // Join with previous line
        const pos = getCursorBytePosition(editor);
        if (pos > 0 and editor.buffer.items[pos - 1] == '\n') {
            _ = editor.buffer.orderedRemove(pos - 1);
            editor.cursor.row -= 1;
            // Move to end of previous line
            editor.cursor.col = getLineLength(editor, editor.cursor.row);
            editor.modified = true;
        }
    }
    ensureCursorVisible(editor);
}

fn handleDelete(editor: *model.EditorState) void {
    const pos = getCursorBytePosition(editor);
    if (pos < editor.buffer.items.len) {
        _ = editor.buffer.orderedRemove(pos);
        editor.modified = true;
    }
}

fn moveCursorUp(editor: *model.EditorState) void {
    if (editor.cursor.row > 0) {
        editor.cursor.row -= 1;
        const line_len = getLineLength(editor, editor.cursor.row);
        if (editor.cursor.col > line_len) {
            editor.cursor.col = line_len;
        }
        ensureCursorVisible(editor);
    }
}

fn moveCursorDown(editor: *model.EditorState) void {
    const total_lines = countLines(editor);
    if (editor.cursor.row < total_lines - 1) {
        editor.cursor.row += 1;
        const line_len = getLineLength(editor, editor.cursor.row);
        if (editor.cursor.col > line_len) {
            editor.cursor.col = line_len;
        }
        ensureCursorVisible(editor);
    }
}

fn moveCursorLeft(editor: *model.EditorState) void {
    if (editor.cursor.col > 0) {
        editor.cursor.col -= 1;
    } else if (editor.cursor.row > 0) {
        editor.cursor.row -= 1;
        editor.cursor.col = getLineLength(editor, editor.cursor.row);
    }
    ensureCursorVisible(editor);
}

fn moveCursorRight(editor: *model.EditorState) void {
    const line_len = getLineLength(editor, editor.cursor.row);
    if (editor.cursor.col < line_len) {
        editor.cursor.col += 1;
    } else {
        const total_lines = countLines(editor);
        if (editor.cursor.row < total_lines - 1) {
            editor.cursor.row += 1;
            editor.cursor.col = 0;
        }
    }
    ensureCursorVisible(editor);
}

fn moveCursorHome(editor: *model.EditorState) void {
    editor.cursor.col = 0;
    ensureCursorVisible(editor);
}

fn moveCursorEnd(editor: *model.EditorState) void {
    editor.cursor.col = getLineLength(editor, editor.cursor.row);
    ensureCursorVisible(editor);
}

fn selectAll(editor: *model.EditorState) void {
    // TODO: Implement selection
    _ = editor;
}

fn undo(editor: *model.EditorState) void {
    // TODO: Implement undo
    _ = editor;
}

fn redo(editor: *model.EditorState) void {
    // TODO: Implement redo
    _ = editor;
}

fn formatSQL(editor: *model.EditorState) void {
    // TODO: Implement SQL formatting
    _ = editor;
}

fn getCursorBytePosition(editor: *model.EditorState) usize {
    var pos: usize = 0;
    var current_row: usize = 0;
    var current_col: usize = 0;

    for (editor.buffer.items) |ch| {
        if (current_row == editor.cursor.row and current_col == editor.cursor.col) {
            break;
        }

        if (ch == '\n') {
            current_row += 1;
            current_col = 0;
        } else {
            current_col += 1;
        }
        pos += 1;
    }

    return pos;
}

fn getLineLength(editor: *model.EditorState, row: usize) usize {
    var current_row: usize = 0;
    var line_len: usize = 0;

    for (editor.buffer.items) |ch| {
        if (current_row == row) {
            if (ch == '\n') break;
            line_len += 1;
        } else if (ch == '\n') {
            current_row += 1;
            line_len = 0;
        }
    }

    return line_len;
}

fn countLines(editor: *model.EditorState) usize {
    if (editor.buffer.items.len == 0) return 1;
    var count: usize = 1;
    for (editor.buffer.items) |ch| {
        if (ch == '\n') count += 1;
    }
    return count;
}

fn ensureCursorVisible(editor: *model.EditorState) void {
    // Assume visible area (will be calculated by view)
    const visible_rows: usize = 20;
    const visible_cols: usize = 80;

    // Vertical scrolling
    if (editor.cursor.row < editor.scroll.row) {
        editor.scroll.row = editor.cursor.row;
    } else if (editor.cursor.row >= editor.scroll.row + visible_rows) {
        editor.scroll.row = editor.cursor.row - visible_rows + 1;
    }

    // Horizontal scrolling
    if (editor.cursor.col < editor.scroll.col) {
        editor.scroll.col = editor.cursor.col;
    } else if (editor.cursor.col >= editor.scroll.col + visible_cols) {
        editor.scroll.col = editor.cursor.col - visible_cols + 1;
    }
}
