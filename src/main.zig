const std = @import("std");
const zinterprocess = @import("zinterprocess");
const builtin = @import("builtin");
const win32 = @import("win32");

const runtime_safety = switch (builtin.mode) {
    .Debug, .ReleaseSafe => true,
    .ReleaseFast, .ReleaseSmall => false,
};

pub fn main() !void {
    var debug_alloc_impl: std.heap.DebugAllocator(.{}) = .init;
    const gpa = if (runtime_safety) debug_alloc_impl.allocator() else std.heap.smp_allocator;

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

    const queue = try zinterprocess.Queue.init(.{
        .side = zinterprocess.QueueSide.Subscriber,
        .path = tempPath,
        .allocator = gpa,
        .runtime_safety = runtime_safety,
        .memory_view_name = "sample-queue",
    });

    while (true) {
        const data = try queue.dequeue();
        defer gpa.free(data);

        std.debug.print("Received data: {s} ({d} bytes)\n", .{ data, data.len });

        for (data) |byte| {
            std.debug.print("{X:0>2}", .{byte});
        }

        if (data.len > 0) {
            std.debug.print("\n", .{});
        }
    }

    defer queue.deinit();
}
