const std = @import("std");
const ansi = @import("ansi_term_codes.zig");

pub const Cell = struct {
    char: u8,
    fgcolor: ansi.AnsiColor,
    bgcolor: ansi.AnsiColor,
    mode: ansi.AnsiGraphicsMode,

    pub fn init(c: u8, fgclr: ansi.AnsiColor, bgclr: ansi.AnsiColor, m: ansi.AnsiGraphicsMode) Cell {
        return Cell{
            .char = c,
            .fgcolor = fgclr,
            .bgcolor = bgclr,
            .mode = m,
        };
    }

    pub fn print(self: Cell, writer: std.fs.File.Writer) !void {
        try ansi.setColors(self.fgcolor, self.bgcolor, writer);
        try ansi.setMode(self.mode, writer);
        try writer.print("{c}", .{self.char});
        try ansi.resetCodes(writer);
    }
};

pub const CellMatrix = struct {
    rows: u32,
    columns: u32,

    matrix: [][]Cell,

    pub fn init(r: u32, c: u32, allocator: *const std.mem.Allocator) !CellMatrix {
        // Copied this from https://stackoverflow.com/q/66630797
        var m = try allocator.alloc([]Cell, r);
        for (m, 0..) |_, i| {
            m[i] = try allocator.alloc(Cell, c);
        }
        return CellMatrix{
            .rows = r,
            .columns = c,
            .matrix = m,
        };
    }

    pub fn print(self: CellMatrix, writer: std.fs.File.Writer) !void {
        for (self.matrix) |row| {
            for (row) |cell| {
                try cell.print(writer);
            }
        }
    }

    pub fn deinit(self: CellMatrix, allocator: *const std.mem.Allocator) void {
        for (self.matrix, 0..) |_, i| {
            allocator.free(self.matrix[i]);
        }
        allocator.free(self.matrix);
    }
};
