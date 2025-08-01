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
    data_ptr: [*]u8,

    pub fn init(options: queue.QueueOptions) !MemoryFileWindows {
        const capacity = @sizeOf(queue.QueueHeader) + 1024;

        const lpNamePrefix = "CT_IP_";
        const lpName: []u8 = try options.allocator.alloc(u8, lpNamePrefix.len + options.memory_view_name.len);
        defer options.allocator.free(lpName);

        @memcpy(lpName[0..lpNamePrefix.len], lpNamePrefix);
        @memcpy(lpName[lpNamePrefix.len..], options.memory_view_name);

        const mapHandle = win32.system.memory.CreateFileMappingA(
            win32.foundation.INVALID_HANDLE_VALUE,
            null,
            win32.system.memory.PAGE_READWRITE,
            0,
            options.capacity,
            @ptrCast(lpName),
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

        const data_ptr = @as([*]u8, @ptrCast(viewHandle.?));

        const file = MemoryFileWindows{
            .mapHandle = mapHandle.?,
            .data = data_ptr[0..capacity],
            .data_ptr = data_ptr,
        };

        return file;
    }

    pub fn deinit(self: MemoryFileWindows) void {
        _ = win32.foundation.CloseHandle(self.mapHandle);
    }
};

const MemoryFileUnix = struct {
    data: []u8 = &.{},

    pub fn init(options: queue.QueueOptions) MemoryFileError!MemoryFileUnix {
        _ = options;
        const file = MemoryFileUnix{};
        return file;
    }

    pub fn deinit(self: MemoryFileUnix) void {
        _ = self;
    }
};

pub const MemoryFile = if (@import("builtin").os.tag == .windows) MemoryFileWindows else MemoryFileUnix;
