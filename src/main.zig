const std = @import("std");
const ansi = @import("ansi_term_codes.zig");
const termsize = @import("termsize");
const AnsiColorCode = ansi.AnsiColorCode;
const AnsiColorType = ansi.AnsiColorType;
const AnsiColor = ansi.AnsiColor;
const AnsiGraphicsMode = ansi.AnsiGraphicsMode;

// Copied these from https://stackoverflow.com/q/66630797
inline fn alloc2d(comptime t: type, m: u32, n: u32, allocator: *const std.mem.Allocator) ![][]t {
    const array = try allocator.alloc([]t, m);
    for (array, 0..) |_, i| {
        array[i] = try allocator.alloc(t, n);
    }
    return array;
}

inline fn free2d(comptime t: type, array: [][]t, allocator: *const std.mem.Allocator) void {
    for (array, 0..) |_, i| {
        allocator.free(array[i]);
    }
    allocator.free(array);
}

pub fn main() !void {
    const writer = std.io.getStdOut().writer();

    const t = try termsize.termSize(std.io.getStdOut());

    if (t) |*terminfo| {
        const cols = terminfo.width;
        const rows = terminfo.height;
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = &gpa.allocator();
        defer _ = gpa.deinit();

        var matrix = try alloc2d(
            u8,
            rows,
            cols,
            allocator,
        );
        defer free2d(u8, matrix, allocator);

        for (matrix, 0..) |_, i| {
            for (matrix[i], 0..) |_, j| {
                matrix[i][j] = 'a';
            }
        }
        for (matrix) |row| {
            try writer.print("{s}\n", .{row});
        }
    }
}
