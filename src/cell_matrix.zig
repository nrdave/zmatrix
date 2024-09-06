const std = @import("std");
const ansi = @import("ansi_term_codes.zig");

pub const Cell = struct {
    char: u8,
    fgcolor: ansi.ColorCode,
    bgcolor: ansi.ColorCode,
    modes: ansi.GraphicsModes,
    updated: bool,

    pub fn init(c: u8, fgcolor: ?ansi.ColorCode, bgcolor: ?ansi.ColorCode) Cell {
        return Cell{
            .char = c,
            .fgcolor = fgcolor orelse .default,
            .bgcolor = bgcolor orelse .default,
            .modes = .{},
            .updated = true,
        };
    }

    pub fn setFgColor(self: *Cell, color: ansi.ColorCode) void {
        self.fgcolor = color;
        self.updated = true;
    }

    pub fn setBgColor(self: *Cell, color: ansi.ColorCode) void {
        self.bgcolor = color;
        self.updated = true;
    }

    pub fn print(self: *Cell, writer: anytype) !void {
        try self.modes.setModes(writer);
        try ansi.setForegroundColor(writer, self.fgcolor);
        try ansi.setBackgroundColor(writer, self.bgcolor);
        try writer.print("{c}", .{self.char});
        self.updated = false;
    }
};

pub const CellMatrix = struct {
    // ANSI cursor locations are 1-based i.e. 1 represents the first row/col
    x0: usize = 1,
    y0: usize = 1,
    num_rows: usize,
    num_cols: usize,
    matrix: [][]Cell,

    pub fn init(
        r: u32,
        c: u32,
        allocator: std.mem.Allocator,
    ) !CellMatrix {
        // Copied this from https://stackoverflow.com/q/66630797
        const m = try allocator.alloc([]Cell, r);
        for (m) |*row| {
            row.* = try allocator.alloc(Cell, c);
            for (row.*) |*cell| {
                cell.* = Cell.init(' ', null, null);
            }
        }
        return CellMatrix{
            .num_rows = r,
            .num_cols = c,
            .matrix = m,
        };
    }

    pub fn setOrigin(self: *CellMatrix, x: usize, y: usize) void {
        self.x0 = x;
        self.y0 = y;
    }

    pub fn writeChar(
        self: CellMatrix,
        char: ?u8,
        x: usize,
        y: isize,
        fgcolor: ?ansi.ColorCode,
        bgcolor: ?ansi.ColorCode,
        modes: ?ansi.GraphicsModes,
    ) void {
        const row: usize = @bitCast(y);
        const col = x;

        if (((row < self.matrix.len) and (row >= 0)) and (col < self.matrix[0].len)) {
            if (char) |c|
                self.matrix[row][col].char = c;
            if (fgcolor) |f|
                self.matrix[row][col].fgcolor = f;
            if (bgcolor) |b|
                self.matrix[row][col].bgcolor = b;
            if (modes) |m|
                self.matrix[row][col].modes = m;
            self.matrix[row][col].updated = true;
        }
    }

    pub fn print(self: CellMatrix, writer: anytype) !void {
        for (self.matrix, 0..) |rows, r| {
            for (rows, 0..) |*cell, c| {
                if (cell.updated == true) {
                    try ansi.setCursorPos(
                        writer,
                        r + self.y0,
                        c + self.x0,
                    );
                    try cell.print(writer);
                }
            }
        }
    }

    pub fn deinit(self: CellMatrix, allocator: std.mem.Allocator) void {
        for (self.matrix) |row| {
            allocator.free(row);
        }
        allocator.free(self.matrix);
    }
};

test "cell_matrix" {
    const alloc = std.testing.allocator;

    var x = try CellMatrix.init(
        5,
        5,
        alloc,
        .blue,
        null,
    );
    x.setOrigin(60, 0);
    x.writeChar('c', 3, 3, null);

    const stdout = std.io.getStdOut().writer();
    try ansi.clearScreen(stdout);

    try x.print(stdout);

    x.deinit(alloc);
}
