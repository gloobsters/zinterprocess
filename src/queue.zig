const MemoryFile = @import("memory_view.zig").MemoryFile;

pub const QueueOptions = struct {
    /// The side of the queue, either Publisher (write) or Subscriber (read).
    side: QueueSide,
    /// The unique name of the memory view.
    memory_view_name: []const u8 = "Local\\zinterprocess",
    /// The path to the directory in which the memory mapped file/other files will be stored.
    path: ?[]const u8 = null,
    /// The size of the memory view.
    capacity: u32 = 1024,
    /// Whether the memory view should be destroyed on deinit.
    /// This only deletes the backing file if a file path is specified.
    destroy_on_deinit: bool = false,
};

pub const QueueSide = enum { Publisher, Subscriber };
pub const Queue = struct {
    side: QueueSide,
    memory_view: MemoryFile,

    pub fn init(options: QueueOptions) !Queue {
        return .{
            .side = options.side,
            .memory_view = try .init(options),
        };
    }

    pub fn deinit(self: Queue) void {
        self.memory_view.deinit();
    }
};
