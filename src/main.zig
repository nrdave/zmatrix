const std = @import("std");
const ansi = @import("ansi_term_codes.zig");
const cm = @import("cell_matrix.zig");
const termsize = @import("termsize");
const AnsiColorCode = ansi.AnsiColorCode;
const AnsiColorType = ansi.AnsiColorType;
const AnsiColor = ansi.AnsiColor;
const AnsiGraphicsMode = ansi.AnsiGraphicsMode;

pub fn main() !void {
    const writer = std.io.getStdOut().writer();

    const t = try termsize.termSize(std.io.getStdOut());

    if (t) |*terminfo| {
        const cols = terminfo.width;
        const rows = terminfo.height;
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = &gpa.allocator();
        defer _ = gpa.deinit();

        var matrix = try cm.CellMatrix.init(rows, cols, allocator);
        defer matrix.deinit(allocator);

        for (matrix.matrix, 0..) |_, i| {
            for (matrix.matrix[i], 0..) |_, j| {
                if (i % 2 == 0) {
                    matrix.matrix[i][j] = cm.Cell.init(
                        'a',
                        AnsiColor{
                            .color = AnsiColorCode.black,
                            .type = AnsiColorType.bright_text,
                        },
                        AnsiColor{
                            .color = AnsiColorCode.blue,
                            .type = AnsiColorType.dark_bg,
                        },
                        AnsiGraphicsMode.italic,
                    );
                } else matrix.matrix[i][j] = cm.Cell.init(
                    'b',
                    AnsiColor{
                        .color = AnsiColorCode.red,
                        .type = AnsiColorType.dark_text,
                    },
                    AnsiColor{
                        .color = AnsiColorCode.magenta,
                        .type = AnsiColorType.bright_bg,
                    },
                    AnsiGraphicsMode.underline,
                );
            }
        }

        try matrix.print(writer);
    }
}
