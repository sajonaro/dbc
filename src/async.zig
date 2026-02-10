const std = @import("std");
const events = @import("events.zig");

pub const AsyncQueue = struct {
    mutex: std.Thread.Mutex,
    events: std.ArrayList(events.Event),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) AsyncQueue {
        return .{
            .mutex = .{},
            .events = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AsyncQueue) void {
        self.events.deinit(self.allocator);
    }

    pub fn push(self: *AsyncQueue, event: events.Event) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.events.append(self.allocator, event) catch {};
    }

    pub fn drain(self: *AsyncQueue) []events.Event {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.events.items.len == 0) return &.{};

        const items = self.events.toOwnedSlice(self.allocator) catch return &.{};
        return items;
    }
};
