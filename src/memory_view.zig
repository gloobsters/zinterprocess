const win32 = @import("win32");
const std = @import("std");

const MemoryFileWindows = struct {
    pub fn testytest(self: MemoryFileWindows) void {
        _ = self;
        // win32.test();
    }
};

const MemoryFileUnix = struct {
    pub fn testytest(self: MemoryFileUnix) void {
        _ = self;
        // std.os.posix.test();
    }
};

pub const MemoryFile = if (@import("builtin").os.tag == .windows) MemoryFileWindows else MemoryFileUnix;
