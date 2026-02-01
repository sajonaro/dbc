const std = @import("std");
const model = @import("model.zig");
const events = @import("events.zig");

pub fn processEvent(state: *model.State, event: events.Event) void {
    // TODO: Implement main event router
    // - Route key events to appropriate handlers
    // - Handle async completions
    // - Process timers
    _ = state;
    _ = event;
}
