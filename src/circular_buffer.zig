const std = @import("std");

pub const CircularBuffer = struct {
    buffer: [*]u8,
    capacity: usize,

    fn get_pointer(self: CircularBuffer, offset: usize) [*]u8 {
        return self.buffer + self.adjusted_offset(offset);
    }

    fn adjusted_offset(self: CircularBuffer, offset: usize) usize {
        return offset % self.capacity;
    }

    pub fn read(self: CircularBuffer, offset: usize, out: []u8) void {
        if (out.len == 0) return;

        const read_offset = self.adjusted_offset(offset);

        const source_buffer = self.buffer + read_offset;
        const right_len = @min(self.capacity - read_offset, out.len);
        @memcpy(out[0..right_len], source_buffer[0..right_len]);

        const left_len = out.len - right_len;
        @memcpy(out[right_len..out.len], self.buffer[0..left_len]);
    }
};
