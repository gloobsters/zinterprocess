const std = @import("std");
const MemoryFile = @import("memory_view.zig").MemoryFile;
const CircularBuffer = @import("circular_buffer.zig").CircularBuffer;
const MessageHeader = @import("message.zig").MessageHeader;
const MessageState = @import("message.zig").MessageState;
const common = @import("common.zig");

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
    read_offset: i64,
    write_offset: i64,
    read_lock_timestamp: i64,
    reserved: i64,

    pub fn isEmpty(self: QueueHeader) bool {
        return self.read_offset == self.write_offset;
    }
};

comptime {
    if (@sizeOf(QueueHeader) != 32)
        @compileError("Queue header size must be 32 bytes");
}

pub const QueueError = error{
    InvalidQueueSide,
    QueueEmpty,
    QueueReadLocked,
    PublisherCrashed,
    ReadLockFailed,
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

    fn get_header(self: Queue) *QueueHeader {
        return @ptrCast(@alignCast(self.memory_view.data_ptr));
    }

    fn safe_increment_message_offset(self: Queue, offset: i64, increment: i64) i64 {
        const capacity: i64 = @intCast(self.buffer.capacity);
        return @mod(offset + increment, capacity * 2);
    }

    pub fn dequeueOnce(self: Queue) ![]u8 {
        if (self.options.runtime_safety and self.side != QueueSide.Subscriber) {
            return QueueError.InvalidQueueSide;
        }

        const header = self.get_header();
        if (header.isEmpty()) {
            return QueueError.QueueEmpty;
        }

        const read_lock_timestamp = header.read_lock_timestamp;
        const start = common.get_ticks();

        const ticks_for_ten_seconds = 10 * std.time.ns_per_s / 100;
        if (start - read_lock_timestamp < ticks_for_ten_seconds)
            return QueueError.QueueReadLocked;

        // should we use strong instead?
        if (@cmpxchgWeak(i64, &header.read_lock_timestamp, read_lock_timestamp, start, .seq_cst, .seq_cst) != null) {
            return QueueError.ReadLockFailed;
        }

        if (header.isEmpty())
            return QueueError.QueueEmpty;

        const read_offset = header.read_offset;
        const write_offset = header.write_offset;
        const message_header: *MessageHeader = @ptrCast(@alignCast(self.buffer.get_pointer(@intCast(read_offset))));

        while (true) {
            const state = @cmpxchgWeak(MessageState, &message_header.state, .ReadyToBeConsumed, .LockedToBeConsumed, .seq_cst, .seq_cst);

            if (state == null)
                break;

            if (common.get_ticks() - start > ticks_for_ten_seconds) {
                @atomicStore(i64, &header.write_offset, write_offset, .seq_cst);
                return QueueError.PublisherCrashed;
            }

            try std.Thread.yield();
        }

        const body_length: usize = @intCast(message_header.body_length);

        const buffer = try self.options.allocator.alloc(u8, body_length);
        self.buffer.read(common.message_body_offset(body_length), buffer);

        const message_length = common.padded_message_length(body_length);
        self.buffer.clear(@intCast(read_offset), message_length);

        const newReadOffset = self.safe_increment_message_offset(read_offset, @intCast(message_length));
        @atomicStore(i64, &header.read_offset, newReadOffset, .seq_cst);

        @atomicStore(i64, &header.read_lock_timestamp, 0, .seq_cst);

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
