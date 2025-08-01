const std = @import("std");
const MemoryFile = @import("memory_view.zig").MemoryFile;
const CircularBuffer = @import("circular_buffer.zig").CircularBuffer;

pub const QueueOptions = struct {
    /// The side of the queue, either Publisher (write) or Subscriber (read).
    side: QueueSide,
    /// The unique name of the memory view.
    memory_view_name: []const u8 = "zinterprocess",
    /// The path to the directory in which the memory mapped file/other files will be stored.
    path: ?[]const u8 = null,
    /// The size of the memory view.
    capacity: u32 = 1024,
    /// Whether the memory view should be destroyed on deinit.
    /// This only deletes the backing file if a file path is specified.
    destroy_on_deinit: bool = false,
    allocator: std.mem.Allocator,
    runtime_safety: bool = true,
};

pub const QueueSide = enum { Publisher, Subscriber };

pub const QueueHeader = struct {
    ReadOffset: i64,
    WriteOffset: i64,
    ReadLockTimestamp: i64,
    Reserved: i64,

    pub fn isEmpty(self: QueueHeader) bool {
        return self.ReadOffset == self.WriteOffset;
    }
};

comptime {
    if (@sizeOf(QueueHeader) != 32)
        @compileError("Queue header size must be 32 bytes");
}

pub const QueueError = error{
    InvalidQueueSide,
    QueueEmpty,
    NotImplemented,
};

pub const Queue = struct {
    side: QueueSide,
    memory_view: MemoryFile,
    options: QueueOptions,
    buffer: CircularBuffer,

    pub fn init(options: QueueOptions) !Queue {
        const memory_view = try MemoryFile.init(options);

        return .{
            .side = options.side,
            .memory_view = memory_view,
            .options = options,
            .buffer = CircularBuffer{
                .buffer = memory_view.data_ptr + @sizeOf(QueueHeader),
                .capacity = options.capacity,
            },
        };
    }

    pub fn deinit(self: Queue) void {
        self.memory_view.deinit();
    }

    pub fn get_header(self: Queue) *QueueHeader {
        return @ptrCast(@alignCast(self.memory_view.data_ptr));
    }

    pub fn dequeueOnce(self: Queue) ![]u8 {
        if (self.options.runtime_safety and self.side != QueueSide.Subscriber) {
            return QueueError.InvalidQueueSide;
        }

        const header = self.get_header();
        if (header.isEmpty()) {
            return QueueError.QueueEmpty;
        }

        // below is temporary
        const buffer = try self.options.allocator.alloc(u8, 1024);

        self.buffer.read(0, buffer);

        return buffer;
    }

    pub fn dequeue(self: Queue) ![]u8 {
        while (true) {
            const result = self.dequeueOnce() catch |err| {
                if (err == QueueError.QueueEmpty) {
                    std.Thread.sleep(10 * std.time.ns_per_ms);
                    continue;
                } else {
                    return err;
                }
            };

            return result;
        }
    }
};
