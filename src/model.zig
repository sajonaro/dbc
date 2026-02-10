const std = @import("std");
const tree = @import("model/tree.zig");
const editor = @import("model/editor.zig");
pub const results = @import("model/results.zig");
const modal = @import("model/modal.zig");

pub const TreeState = tree.TreeState;
pub const Node = tree.Node;
pub const NodeKind = tree.NodeKind;

pub const EditorState = editor.EditorState;
pub const Position = editor.Position;
pub const Selection = editor.Selection;
pub const Snapshot = editor.Snapshot;

pub const ResultsState = results.ResultsState;
pub const Column = results.Column;
pub const Cell = results.Cell;

pub const Modal = modal.Modal;
pub const ConfirmModal = modal.ConfirmModal;
pub const InputModal = modal.InputModal;
pub const ErrorModal = modal.ErrorModal;
pub const ConnectModal = modal.ConnectModal;
pub const ConnectField = modal.ConnectField;

pub const State = struct {
    // Connections
    connections: std.ArrayList(Connection),
    active_connection: ?usize,
    db_connection: ?*db.Connection,

    // Component states
    tree: TreeState,
    editor: EditorState,
    results: ResultsState,

    // UI state
    focus: Focus,
    modal: Modal,
    status: Status,

    // App state
    running: bool,
    theme: *const Theme,

    // Async
    async_queue: *AsyncQueue,
};

pub const Connection = struct {
    id: u32,
    name: []const u8,
    driver: DbDriver,
    host: []const u8,
    port: u16,
    database: []const u8,
    user: []const u8,
    connected: bool,
    handle: ?*db.Connection,
};

pub const DbDriver = enum {
    postgresql,
    mssql,
    sqlite,
    mariadb,
};

const db = @import("db/db.zig");

pub const Focus = enum {
    tree,
    editor,
    results,

    pub fn next(self: Focus) Focus {
        return switch (self) {
            .tree => .editor,
            .editor => .results,
            .results => .tree,
        };
    }

    pub fn prev(self: Focus) Focus {
        return switch (self) {
            .tree => .results,
            .editor => .tree,
            .results => .editor,
        };
    }
};

pub const Status = union(enum) {
    idle: []const u8,
    loading: []const u8,
    err: AppError,
};

pub const AppError = struct {
    message: []const u8,
    details: ?[]const u8,
    source: ErrorSource,
};

pub const ErrorSource = enum {
    database,
    filesystem,
    network,
    internal,
};

// Import theme and async types
pub const Theme = @import("theme.zig").Theme;
pub const AsyncQueue = @import("async.zig").AsyncQueue;
