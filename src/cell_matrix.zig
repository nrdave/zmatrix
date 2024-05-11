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
        try ansi.setMode(self.mode, writer);
        try ansi.setColors(self.fgcolor, self.bgcolor, writer);
        try writer.print("{c}", .{self.char});
        try ansi.resetCodes(writer);
    }
};

pub const CellColumn = struct {
    line: u32,
    cells: []Cell,

    pub fn init(len: u32, allocator: *const std.mem.Allocator) !CellColumn {
        const c = try allocator.alloc(Cell, len);

        for (c) |*cell| {
            cell.* = Cell.init(' ', ansi.AnsiColor{
                .color = ansi.AnsiColorCode.black,
                .type = ansi.AnsiColorType.dark_text,
            }, ansi.AnsiColor{
                .color = ansi.AnsiColorCode.red,
                .type = ansi.AnsiColorType.bright_bg,
            }, ansi.AnsiGraphicsMode.normal);
        }

        return CellColumn{
            .line = 0,
            .cells = c,
        };
    }

    pub fn iterate(self: *CellColumn, newChar: Cell) void {
        self.line += 1;
        for (1..self.cells.len) |i| {
            self.cells[self.cells.len - i] = self.cells[self.cells.len - i - 1];
        }
        self.cells[0] = newChar;
    }

    pub fn deinit(self: CellColumn, allocator: *const std.mem.Allocator) void {
        allocator.free(self.cells);
    }
};

pub const CellMatrix = struct {
    rows: u32,
    columns: u32,

    matrix: []CellColumn,

    pub fn init(r: u32, c: u32, allocator: *const std.mem.Allocator) !CellMatrix {
        // Copied this from https://stackoverflow.com/q/66630797
        var m = try allocator.alloc(CellColumn, c);
        for (m, 0..) |_, i| {
            m[i] = try CellColumn.init(r, allocator);
        }
        return CellMatrix{
            .rows = r,
            .columns = c,
            .matrix = m,
        };
    }

    pub fn print(self: CellMatrix, writer: std.fs.File.Writer) !void {
        for (0..self.rows) |row| {
            for (0..self.columns) |col| {
                try self.matrix[col].cells[row].print(writer);
            }
            try writer.print("\n", .{});
        }
    }

    pub fn deinit(self: CellMatrix, allocator: *const std.mem.Allocator) void {
        for (self.matrix) |column| {
            column.deinit(allocator);
        }
        allocator.free(self.matrix);
    }
};

test "cell" {
    const writer = std.io.getStdOut().writer();
    var c = Cell.init(
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

    c = Cell.init(
        'b',
        ansi.AnsiColor{
            .color = ansi.AnsiColorCode.red,
            .type = ansi.AnsiColorType.bright_text,
        },
        ansi.AnsiColor{
            .color = ansi.AnsiColorCode.green,
            .type = ansi.AnsiColorType.bright_bg,
        },
        ansi.AnsiGraphicsMode.underline,
    );
    try c.print(writer);

    c = Cell.init(
        'b',
        ansi.AnsiColor{
            .color = ansi.AnsiColorCode.yellow,
            .type = ansi.AnsiColorType.dark_text,
        },
        ansi.AnsiColor{
            .color = ansi.AnsiColorCode.cyan,
            .type = ansi.AnsiColorType.bright_bg,
        },
        ansi.AnsiGraphicsMode.normal,
    );
    try c.print(writer);

    try writer.print("\n", .{});
}

test "cell_matrix" {
    const writer = std.io.getStdOut().writer();

    const cols = 10;
    const rows = 9;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &gpa.allocator();
    defer _ = gpa.deinit();

    var matrix = try CellMatrix.init(rows, cols, allocator);
    defer matrix.deinit(allocator);

    for (0..matrix.rows) |row| {
        for (0..matrix.columns) |col| {
            if (row % 2 == 0) {
                matrix.matrix[col].cells[row] = Cell.init(
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
            } else matrix.matrix[col].cells[row] = Cell.init(
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

test "cell_column" {
    const writer = std.io.getStdOut().writer();

    // Setting up the initial matrix
    const cols = 5;
    const rows = 5;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &gpa.allocator();
    defer _ = gpa.deinit();

    var matrix = try CellMatrix.init(rows, cols, allocator);
    defer matrix.deinit(allocator);

    for (0..matrix.rows) |row| {
        for (0..matrix.columns) |col| {
            if (row % 2 == 0) {
                matrix.matrix[col].cells[row] = Cell.init(
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
            } else matrix.matrix[col].cells[row] = Cell.init(
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

    for (matrix.matrix) |*column| {
        column.iterate(Cell.init(
            'c',
            ansi.AnsiColor{
                .color = ansi.AnsiColorCode.red,
                .type = ansi.AnsiColorType.bright_text,
            },
            ansi.AnsiColor{
                .color = ansi.AnsiColorCode.green,
                .type = ansi.AnsiColorType.dark_bg,
            },
            ansi.AnsiGraphicsMode.underline,
        ));
    }
    try matrix.print(writer);
    try writer.print("\n", .{});
}
