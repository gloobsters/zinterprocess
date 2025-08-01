const MemoryFile = @import("memory_view.zig").MemoryFile;

pub const QueueSide = enum { Publisher, Subscriber };
pub const Queue = struct {
    side: QueueSide,
    memory_view: MemoryFile,

    pub fn init(self: Queue) void {
        self.memory_view.fart();
    }
};
