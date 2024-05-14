const std = @import("std");
const ansi = @import("ansi_term_codes.zig");
const cm = @import("cell_matrix.zig");
const termsize = @import("termsize");
const termctrl = @import("terminal_mode_control.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    const t = try termsize.termSize(std.io.getStdOut());

    if (t) |*terminfo| {
        // If the termsize is available, create a cell matrix of that size
        const cols = terminfo.width;
        const rows = terminfo.height;
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = gpa.allocator();
        defer _ = gpa.deinit();

        var matrix = try cm.CellMatrix.init(rows, cols, allocator);
        defer matrix.deinit(allocator);

        // Enable the Raw Terminal mode (and store the previous mode for when the program exits)
        const orig_term_state = try termctrl.enableRawMode(std.io.getStdIn().handle);

        var input: u8 = 0;

        while (input != 'q') {
            try ansi.clearScreen(stdout);
            std.time.sleep(20_000_000);
            try matrix.print(stdout);

            for (matrix.columns) |*column| {
                column.iterate(cm.Cell.init(
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

            input = try stdin.readByte();
        }
        try termctrl.restoreTermMode(std.io.getStdIn().handle, orig_term_state);
    }
}
