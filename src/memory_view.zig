const win32 = @import("win32");
const std = @import("std");
const queue = @import("queue.zig");

const MemoryFileError = error{
    MapFailed,
    ViewFailed,
};

const MemoryFileWindows = struct {
    mapHandle: win32.foundation.HANDLE,
    data: []u8,

    pub fn init(options: queue.QueueOptions) MemoryFileError!MemoryFileWindows {
        const size = 1024;

        const mapHandle = win32.system.memory.CreateFileMappingA(
            win32.foundation.INVALID_HANDLE_VALUE,
            null, // attributes
            win32.system.memory.PAGE_READWRITE, // protection/mode
            0, // max size high
            options.capacity, // max size low size
            @ptrCast(options.memory_view_name),
        );

        if (mapHandle == null)
            return MemoryFileError.MapFailed;

        const viewHandle = win32.system.memory.MapViewOfFile(
            mapHandle,
            win32.system.memory.FILE_MAP_ALL_ACCESS, // access
            0, // offset high
            0, // offset low
            options.capacity, // view size
        );

        if (viewHandle == null)
            return MemoryFileError.ViewFailed;

        const file = MemoryFileWindows{
            .mapHandle = mapHandle.?,
            .data = @as([*]u8, @ptrCast(viewHandle.?))[0..size],
        };

        return file;
    }

    pub fn deinit(self: MemoryFileWindows) void {
        _ = win32.foundation.CloseHandle(self.mapHandle);
    }
};

const MemoryFileUnix = struct {
    data: []u8,

    pub fn init() MemoryFileWindows {
        const file = MemoryFileUnix{};
        return file;
    }

    pub fn deinit() void {}
};

pub const MemoryFile = if (@import("builtin").os.tag == .windows) MemoryFileWindows else MemoryFileUnix;
