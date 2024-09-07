const std = @import("std");
const ansi = @import("ansi_term_codes.zig");

pub const Cell = struct {
    char: u8,
    fgcolor: ansi.ColorCode,
    bgcolor: ansi.ColorCode,
    modes: ansi.GraphicsModes,
    updated: bool,

    const Self = @This();

    pub fn init(c: u8, fgcolor: ?ansi.ColorCode, bgcolor: ?ansi.ColorCode) Self {
        return Self{
            .char = c,
            .fgcolor = fgcolor orelse .default,
            .bgcolor = bgcolor orelse .default,
            .modes = .{},
            .updated = true,
        };
    }

    pub fn setFgColor(self: *Self, color: ansi.ColorCode) void {
        self.fgcolor = color;
        self.updated = true;
    }

    pub fn setBgColor(self: *Self, color: ansi.ColorCode) void {
        self.bgcolor = color;
        self.updated = true;
    }

    pub fn print(self: *Self, writer: anytype) !void {
        try self.modes.setModes(writer);
        try ansi.setForegroundColor(writer, self.fgcolor);
        try ansi.setBackgroundColor(writer, self.bgcolor);
        try writer.print("{c}", .{self.char});
        self.updated = false;
    }
};

// ANSI cursor locations are 1-based i.e. 1 represents the first row/col
var x0: usize = 1;
var y0: usize = 1;
var grid: [][]Cell = undefined;

pub fn init(
    r: u32,
    c: u32,
    allocator: std.mem.Allocator,
) !void {
    // Copied this from https://stackoverflow.com/q/66630797
    grid = try allocator.alloc([]Cell, r);
    for (grid) |*row| {
        row.* = try allocator.alloc(Cell, c);
        for (row.*) |*cell| {
            cell.* = Cell.init(' ', null, null);
        }
    }
}

pub fn setOrigin(x: usize, y: usize) void {
    x0 = x;
    y0 = y;
}

pub fn writeChar(
    char: ?u8,
    x: usize,
    y: isize,
    fgcolor: ?ansi.ColorCode,
    bgcolor: ?ansi.ColorCode,
    modes: ?ansi.GraphicsModes,
) void {
    const row: usize = @bitCast(y);
    const col = x;

    if (((row < grid.len) and (row >= 0)) and (col < grid[0].len)) {
        if (char) |c|
            grid[row][col].char = c;
        if (fgcolor) |f|
            grid[row][col].fgcolor = f;
        if (bgcolor) |b|
            grid[row][col].bgcolor = b;
        if (modes) |m|
            grid[row][col].modes = m;
        grid[row][col].updated = true;
    }
}

pub fn print(writer: anytype) !void {
    for (grid, 0..) |rows, r| {
        for (rows, 0..) |*cell, c| {
            if (cell.updated == true) {
                try ansi.setCursorPos(
                    writer,
                    r + y0,
                    c + x0,
                );
                try cell.print(writer);
            }
        }
    }
}

pub fn resize(
    r: u32,
    c: u32,
    allocator: std.mem.Allocator,
) !void {
    deinit(allocator);
    try init(r, c, allocator);
}

pub fn getGrid() [][]Cell {
    return grid;
}

pub fn deinit(allocator: std.mem.Allocator) void {
    for (grid) |row| {
        allocator.free(row);
    }
    allocator.free(grid);
}

test "terminal_window" {
    // This test is meant to be used to visually confirm functionality i.e.
    // the reported test result is meaningless
    const alloc = std.testing.allocator;

    try init(5, 5, alloc);
    setOrigin(6, 0);
    writeChar('c', 3, 3, null, null, .{ .bold = true });

    const stdout = std.io.getStdOut().writer();
    try ansi.clearScreen(stdout);

    try print(stdout);

    // Check for block of struckthrough blue a's with red background
    try resize(8, 8, alloc);
    setOrigin(15, 9);
    for (grid, 0..) |row, r| {
        for (row, 0..) |_, c| {
            writeChar('a', c, @bitCast(r), .blue, .red, .{ .strikethrough = true });
        }
    }

    try print(stdout);

    _ = try stdout.writeByte('\n');

    deinit(alloc);
}
