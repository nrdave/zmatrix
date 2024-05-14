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

    pub fn init(len: u32, allocator: std.mem.Allocator) !CellColumn {
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
        for (0..self.cells.len - 1) |i| {
            self.cells[i] = self.cells[i + 1];
        }
        self.cells[self.cells.len - 1] = newChar;
    }

    pub fn deinit(self: CellColumn, allocator: std.mem.Allocator) void {
        allocator.free(self.cells);
    }
};

pub const CellMatrix = struct {
    num_rows: u32,
    num_cols: u32,

    columns: []CellColumn,

    pub fn init(r: u32, c: u32, allocator: std.mem.Allocator) !CellMatrix {
        // Copied this from https://stackoverflow.com/q/66630797
        const m = try allocator.alloc(CellColumn, c);
        for (m) |*col| {
            col.* = try CellColumn.init(r, allocator);
            for (col.cells) |*cell| {
                cell.* = Cell.init(
                    ' ',
                    ansi.AnsiColor{
                        .color = ansi.AnsiColorCode.white,
                        .type = ansi.AnsiColorType.bright_text,
                    },
                    ansi.AnsiColor{
                        .color = ansi.AnsiColorCode.black,
                        .type = ansi.AnsiColorType.dark_bg,
                    },
                    ansi.AnsiGraphicsMode.italic,
                );
            }
        }
        return CellMatrix{
            .num_rows = r,
            .num_cols = c,
            .columns = m,
        };
    }

    pub fn print(self: CellMatrix, writer: std.fs.File.Writer) !void {
        for (0..self.num_rows) |row| {
            for (0..self.num_cols) |col| {
                try self.columns[col].cells[row].print(writer);
            }
            if (row < self.num_rows - 1) {
                try writer.print("\n", .{});
            }
        }
    }

    pub fn deinit(self: CellMatrix, allocator: std.mem.Allocator) void {
        for (self.columns) |column| {
            column.deinit(allocator);
        }
        allocator.free(self.columns);
    }
};

test "cell" {
    const stdout = std.io.getStdOut().writer();
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
    try c.print(stdout);

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
    try c.print(stdout);

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
    try c.print(stdout);

    try stdout.print("\n", .{});
}

test "cell_matrix" {
    const stdout = std.io.getStdOut().writer();

    const cols = 10;
    const rows = 9;
    const allocator = std.testing.allocator;

    var matrix = try CellMatrix.init(rows, cols, allocator);
    defer matrix.deinit(allocator);

    for (0..matrix.num_rows) |row| {
        for (0..matrix.num_cols) |col| {
            if (row % 2 == 0) {
                matrix.columns[col].cells[row] = Cell.init(
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
            } else matrix.columns[col].cells[row] = Cell.init(
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

    try matrix.print(stdout);
    try stdout.print("\n", .{});
}

test "cell_column" {
    const stdout = std.io.getStdOut().writer();

    // Setting up the initial matrix
    const cols = 5;
    const rows = 5;
    const allocator = std.testing.allocator;

    var matrix = try CellMatrix.init(rows, cols, allocator);
    defer matrix.deinit(allocator);

    for (0..matrix.num_rows) |row| {
        for (0..matrix.num_cols) |col| {
            if (row % 2 == 0) {
                matrix.columns[col].cells[row] = Cell.init(
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
            } else matrix.columns[col].cells[row] = Cell.init(
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

    try matrix.print(stdout);
    try stdout.print("\n", .{});

    for (matrix.columns) |*column| {
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
    try matrix.print(stdout);
    try stdout.print("\n", .{});
}
