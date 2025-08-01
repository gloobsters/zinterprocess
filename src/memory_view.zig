const win32 = @import("win32");
const std = @import("std");

const MemoryFileWindows = struct {
    mapHandle: ?win32.foundation.HANDLE,

    pub fn init() MemoryFileWindows {
        const file = MemoryFileWindows{
            .mapHandle = win32.system.memory.CreateFileMappingA(
                win32.foundation.INVALID_HANDLE_VALUE,
                null, // attributes
                win32.system.memory.PAGE_READWRITE, // protection/mode
                0, // max size high
                1024, // max size low size
                "Local\\MemoryView",
            ),
        };

        return file;
    }

    pub fn deinit(self: MemoryFileWindows) void {
        _ = win32.foundation.CloseHandle(self.mapHandle);
    }
};

const MemoryFileUnix = struct {
    pub fn init() MemoryFileWindows {
        const file = MemoryFileUnix{};
        return file;
    }

    pub fn deinit() void {}
};

pub const MemoryFile = if (@import("builtin").os.tag == .windows) MemoryFileWindows else MemoryFileUnix;
