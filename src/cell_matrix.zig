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
            try writer.print("\n", .{});
        }
    }

    pub fn deinit(self: CellMatrix, allocator: *const std.mem.Allocator) void {
        for (self.matrix, 0..) |_, i| {
            allocator.free(self.matrix[i]);
        }
        allocator.free(self.matrix);
    }
};

test "cell" {
    const writer = std.io.getStdOut().writer();
    const c = Cell.init(
        'a',
        ansi.AnsiColor{
            .color = ansi.AnsiColorCode.black,
            .type = ansi.AnsiColorType.bright_text,
        },
        ansi.AnsiColor{
            .color = ansi.AnsiColorCode.blue,
            .type = ansi.AnsiColorType.dark_bg,
        },
        ansi.AnsiGraphicsMode.italic,
    );
    try c.print(writer);
    try writer.print("\n", .{});
}

test "cell_matrix" {
    const writer = std.io.getStdOut().writer();

    const cols = 10;
    const rows = 10;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &gpa.allocator();
    defer _ = gpa.deinit();

    var matrix = try CellMatrix.init(rows, cols, allocator);
    defer matrix.deinit(allocator);

    for (matrix.matrix, 0..) |_, i| {
        for (matrix.matrix[i], 0..) |_, j| {
            if (i % 2 == 0) {
                matrix.matrix[i][j] = Cell.init(
                    'a',
                    ansi.AnsiColor{
                        .color = ansi.AnsiColorCode.black,
                        .type = ansi.AnsiColorType.bright_text,
                    },
                    ansi.AnsiColor{
                        .color = ansi.AnsiColorCode.blue,
                        .type = ansi.AnsiColorType.dark_bg,
                    },
                    ansi.AnsiGraphicsMode.italic,
                );
            } else matrix.matrix[i][j] = Cell.init(
                'b',
                ansi.AnsiColor{
                    .color = ansi.AnsiColorCode.red,
                    .type = ansi.AnsiColorType.dark_text,
                },
                ansi.AnsiColor{
                    .color = ansi.AnsiColorCode.magenta,
                    .type = ansi.AnsiColorType.bright_bg,
                },
                ansi.AnsiGraphicsMode.underline,
            );
        }
    }

    try matrix.print(writer);
    try writer.print("\n", .{});
}
