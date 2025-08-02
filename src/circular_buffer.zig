const std = @import("std");

pub const CircularBuffer = struct {
    buffer: []u8,

    pub fn get_pointer(self: CircularBuffer, offset: usize) [*]u8 {
        return self.buffer.ptr + self.adjust_offset(offset);
    }

    fn adjust_offset(self: CircularBuffer, offset: usize) usize {
        return offset % self.buffer.len;
    }

    pub fn read(self: CircularBuffer, offset: usize, out: []u8) void {
        if (out.len == 0) return;

        const read_offset = self.adjust_offset(offset);

        const source_buffer = self.buffer.ptr + read_offset;
        const right_len = @min(self.buffer.len - read_offset, out.len);
        @memcpy(out[0..right_len], source_buffer[0..right_len]);

        const left_len = out.len - right_len;
        @memcpy(out[right_len..out.len], self.buffer[0..left_len]);
    }

    pub fn clear(self: CircularBuffer, offset: usize, len: usize) void {
        if (len == 0) return;

        const offset_adjusted = self.adjust_offset(offset);
        const right_len = @min(self.buffer.len - offset_adjusted, len);
        @memset(self.buffer[offset_adjusted .. offset_adjusted + right_len], 0);

        const left_len = len - right_len;
        if (left_len > 0)
            @memset(self.buffer[0..left_len], 0);
    }
};
