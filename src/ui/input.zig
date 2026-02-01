const std = @import("std");
const events = @import("../events.zig");

pub fn poll(timeout_ms: u64) ?events.Event {
    // TODO: Implement input polling from ncurses
    _ = timeout_ms;
    return null;
}
