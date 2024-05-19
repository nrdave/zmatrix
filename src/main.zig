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
        const b = std.io.BufferedWriter(1_000_000, @TypeOf(stdout));
        var buffer: b = .{ .unbuffered_writer = stdout };
        const bufOut = buffer.writer();

        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = gpa.allocator();
        defer _ = gpa.deinit();

        var matrix = try cm.CellMatrix.init(rows, cols, allocator);
        defer matrix.deinit(allocator);

        // Enable the Raw Terminal mode (and store the previous mode for when the program exits)
        const orig_term_state = try termctrl.enableRawMode(std.io.getStdIn().handle);

        try ansi.hideCursor(stdout);

        var input: u8 = 0;

        while (input != 'q') {
            try ansi.clearScreen(stdout);
            try matrix.print(bufOut);

            try buffer.flush();
            for (matrix.columns) |*column| {
                column.iterate(cm.Cell.init(
                    'c',
                    ansi.AnsiColor{
                        .color = ansi.AnsiColorCode.red,
                        .category = ansi.AnsiColorType.bright_text,
                    },
                    ansi.AnsiGraphicsMode.underline,
                ));
            }

            input = try stdin.readByte();
        }
        try cleanup(std.io.getStdIn().handle, stdout, orig_term_state);
    }
}

inline fn cleanup(
    input_handle: std.fs.File.Handle,
    output: std.fs.File.Writer,
    original_term_state: termctrl.TermStatus,
) !void {
    try termctrl.restoreTermMode(input_handle, original_term_state);
    try ansi.showCursor(output);
}
