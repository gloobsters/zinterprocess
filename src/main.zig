const std = @import("std");
const zinterprocess = @import("zinterprocess");
const builtin = @import("builtin");
const win32 = @import("win32");

pub fn main() !void {
    var debug_alloc_impl: std.heap.DebugAllocator(.{}) = .init;
    const gpa = if (std.debug.runtime_safety) debug_alloc_impl.allocator() else std.heap.smp_allocator;

    var tempPath: []const u8 = undefined;
    if (builtin.os.tag == .linux) {
        tempPath = "/dev/shm/.cloudtoid/interprocess/mmf";
    } else if (builtin.os.tag == .windows) {
        var buffer: [std.fs.max_path_bytes]u8 = undefined;

        const len = win32.storage.file_system.GetTempPathA(@intCast(buffer.len), @ptrCast(&buffer));

        if (len == 0 or len > buffer.len) {
            std.debug.panic("GetTempPathA failed", .{});
        }

        tempPath = buffer[0..len];
    } else std.debug.panic("Unsupported OS: {s}", .{builtin.os.tag});

    const queue = try zinterprocess.Queue.init(.{ .side = zinterprocess.QueueSide.Publisher, .path = tempPath, .allocator = gpa });
    defer queue.deinit();
}
