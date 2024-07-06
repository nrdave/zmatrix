const std = @import("std");
const ansi = @import("ansi_term_codes.zig");

pub const Cell = struct {
    char: u8,
    updated: bool,

    pub fn init(c: u8) Cell {
        return Cell{
            .char = c,
            .updated = true,
        };
    }
};

pub const CellMatrix = struct {
    x0: usize = 0,
    y0: usize = 0,
    num_rows: usize,
    num_cols: usize,
    color: ansi.AnsiColor,

    matrix: [][]Cell,

    pub fn init(r: u32, c: u32, allocator: std.mem.Allocator, color: ansi.AnsiColor) !CellMatrix {
        // Copied this from https://stackoverflow.com/q/66630797
        const m = try allocator.alloc([]Cell, r);
        for (m) |*row| {
            row.* = try allocator.alloc(Cell, c);
            for (row.*) |*cell| {
                cell.* = Cell.init(
                    ' ',
                );
            }
        }
        return CellMatrix{ .num_rows = r, .num_cols = c, .matrix = m, .color = color };
    }

    pub fn setOrigin(self: *CellMatrix, x: usize, y: usize) void {
        self.x0 = x;
        self.y0 = y;
    }

    pub fn writeChar(self: CellMatrix, char: u8, x: usize, y: isize) void {
        const row: usize = @bitCast(y);
        const col = x;

        if (((row < self.matrix.len) and (row >= 0)) and (col < self.matrix[0].len)) {
            self.matrix[row][col].char = char;
            self.matrix[row][col].updated = true;
        }
    }

    pub fn print(self: CellMatrix, writer: anytype) !void {
        try ansi.setColor(self.color, writer);
        for (0..self.num_rows) |row| {
            for (0..self.num_cols) |col| {
                if (self.matrix[row][col].updated == true) {
                    try ansi.setCursorPos(writer, row + self.y0, col + self.x0);
                    try writer.print("{c}", .{self.matrix[row][col].char});
                    self.matrix[row][col].updated = false;
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
        ansi.AnsiColor{ .color = .blue },
    );
    x.setOrigin(60, 0);
    try x.writeChar('c', 3, 3);

    const stdout = std.io.getStdOut().writer();
    try ansi.clearScreen(stdout);

    try x.print(stdout);

    x.deinit(alloc);
}
