//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

const queue = @import("queue.zig");

pub const Queue = queue.Queue;
pub const QueueSide = queue.QueueSide;
