const std = @import("std");

pub const CharMatrix = struct {
    rows: u32,
    columns: u32,

    matrix: [][]u8,

    pub fn init(r: u32, c: u32, allocator: *const std.mem.Allocator) !CharMatrix {
        // Copied this from https://stackoverflow.com/q/66630797
        var m = try allocator.alloc([]u8, r);
        for (m, 0..) |_, i| {
            m[i] = try allocator.alloc(u8, c);
        }
        return CharMatrix{
            .rows = r,
            .columns = c,
            .matrix = m,
        };
    }

    pub fn print(self: CharMatrix, writer: std.fs.File.Writer) !void {
        for (self.matrix) |row| {
            try writer.print("{s}\n", .{row});
        }
    }

    pub fn deinit(self: CharMatrix, allocator: *const std.mem.Allocator) void {
        for (self.matrix, 0..) |_, i| {
            allocator.free(self.matrix[i]);
        }
        allocator.free(self.matrix);
    }
};
