const std = @import("std");
const zinterprocess = @import("zinterprocess");

pub fn main() !void {
    const queue = zinterprocess.Queue{ .side = zinterprocess.QueueSide.Publisher, .memory_view = .init() };
    defer queue.deinit();
}
