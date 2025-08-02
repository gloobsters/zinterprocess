const std = @import("std");
const MessageHeader = @import("message.zig").MessageHeader;

pub fn get_ticks() i64 {
    return @intCast(@divTrunc(std.time.nanoTimestamp(), 100));
}

pub fn padded_message_length(length: usize) usize {
    const size: f64 = @floatFromInt(length + @sizeOf(MessageHeader));
    const ceil: usize = @intFromFloat(@ceil(size / 8.0));
    return 8 * ceil;
}

pub fn message_body_offset(offset: usize) usize {
    return offset + @sizeOf(MessageHeader);
}
