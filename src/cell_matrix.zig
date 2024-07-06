const std = @import("std");
const ansi = @import("ansi_term_codes.zig");

pub const Cell = struct {
    char: u8,
    color: ansi.ColorCode,
    updated: bool,

    pub fn init(c: u8, color: ?ansi.ColorCode) Cell {
        return Cell{
            .char = c,
            .color = color orelse .default,
            .updated = true,
        };
    }

    pub fn setColor(self: *Cell, color: ansi.ColorCode) void {
        self.color = color;
        self.updated = true;
    }
};

pub const CellMatrix = struct {
    // ANSI cursor locations are 1-based i.e. 1 represents the first row/col
    x0: usize = 1,
    y0: usize = 1,
    num_rows: usize,
    num_cols: usize,
    color: ansi.ColorCode,
    leading_color: ansi.ColorCode,

    matrix: [][]Cell,

    pub fn init(
        r: u32,
        c: u32,
        allocator: std.mem.Allocator,
        color: ansi.ColorCode,
        leading_color: ?ansi.ColorCode,
    ) !CellMatrix {
        // Copied this from https://stackoverflow.com/q/66630797
        const m = try allocator.alloc([]Cell, r);
        for (m) |*row| {
            row.* = try allocator.alloc(Cell, c);
            for (row.*) |*cell| {
                cell.* = Cell.init(
                    ' ',
                    color,
                );
            }
        }
        return CellMatrix{
            .num_rows = r,
            .num_cols = c,
            .matrix = m,
            .color = color,
            .leading_color = leading_color orelse .white,
        };
    }

    pub fn setOrigin(self: *CellMatrix, x: usize, y: usize) void {
        self.x0 = x;
        self.y0 = y;
    }

    pub fn setColor(self: *CellMatrix, color: ansi.ColorCode) void {
        if (self.color != color) {
            self.color = color;
            for (self.matrix) |row| {
                for (row) |*cell| {
                    cell.color = color;
                    cell.updated = true;
                }
            }
        }
    }

    pub fn writeChar(self: CellMatrix, char: ?u8, x: usize, y: isize, color: ?ansi.ColorCode) void {
        const row: usize = @bitCast(y);
        const col = x;

        if (((row < self.matrix.len) and (row >= 0)) and (col < self.matrix[0].len)) {
            if (char) |c|
                self.matrix[row][col].char = c;
            self.matrix[row][col].color = color orelse self.color;
            self.matrix[row][col].updated = true;
        }
    }

    pub fn print(self: CellMatrix, writer: anytype) !void {
        for (0..self.num_rows) |row| {
            for (0..self.num_cols) |col| {
                if (self.matrix[row][col].updated == true) {
                    try ansi.setForegroundColor(
                        writer,
                        self.matrix[row][col].color,
                    );
                    try ansi.setCursorPos(
                        writer,
                        row + self.y0,
                        col + self.x0,
                    );
                    try writer.print(
                        "{c}",
                        .{self.matrix[row][col].char},
                    );
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
