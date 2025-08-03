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
    data: []u8,
    data_ptr: [*]u8,

    pub fn init(options: queue.QueueOptions) !MemoryFileUnix {
        const path_len = if (options.path) |p| p.len else 0;
        const file_ext = ".qu";
        const filename: []u8 = try options.allocator.alloc(u8, path_len + options.memory_view_name.len + file_ext.len);
        defer options.allocator.free(filename);

        if (options.path) |p| {
            @memcpy(filename[0..path_len], p);
        }
        @memcpy(filename[path_len .. path_len + options.memory_view_name.len], options.memory_view_name);
        @memcpy(filename[path_len + options.memory_view_name.len ..], file_ext);

        std.debug.print("Using path for memory file: {s}\n", .{filename});

        if (options.path) |p| {
            const root = try std.fs.openDirAbsolute("/", .{});
            try root.makePath(p);
        }

        const file = try std.fs.cwd().createFile(filename, .{
            .read = true,
            .truncate = true,
            .exclusive = false,
        });
        defer file.close();

        try file.setEndPos(options.capacity);

        const ptr = try std.posix.mmap(
            null,
            options.capacity,
            std.posix.PROT.READ | std.posix.PROT.WRITE,
            .{ .TYPE = .SHARED },
            file.handle,
            0,
        );

        const mapped_file: MemoryFileUnix = .{
            .data_ptr = ptr.ptr,
            .data = ptr,
        };
        return mapped_file;
    }

    pub fn deinit(self: MemoryFileUnix) void {
        std.posix.munmap(@alignCast(self.data));
    }
};

pub const MemoryFile = if (@import("builtin").os.tag == .windows) MemoryFileWindows else MemoryFileUnix;
