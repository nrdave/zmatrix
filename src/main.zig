const std = @import("std");
const ansi = @import("ansi_term_codes.zig");
const cm = @import("cell_matrix.zig");
const col = @import("char_column.zig");
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

        var matrix = try cm.CellMatrix.init(rows, cols, allocator, ansi.AnsiColor{ .color = .green });
        defer matrix.deinit(allocator);

        // Enable the Raw Terminal mode (and store the previous mode for when the program exits)
        const orig_term_state = try termctrl.enableRawMode(std.io.getStdIn().handle);

        var rng = std.rand.DefaultPrng.init(@bitCast(std.time.timestamp()));
        var char = rng.random().intRangeAtMost(u8, 0, 127);

        try ansi.hideCursor(stdout);
        try ansi.clearScreen(stdout);

        const charcols = try allocator.alloc(col.Column, cols);
        defer allocator.free(charcols);
        for (0.., charcols) |i, *c| {
            c.* = col.Column.init(
                i,
                rng.random().intRangeAtMost(
                    usize,
                    0,
                    20,
                ),
            );
        }

        var input: u8 = 0;
        while (input != 'q') {
            try matrix.print(bufOut);
            try buffer.flush();

            for (charcols) |*c| {
                char = rng.random().int(u8);
                if (std.ascii.isPrint(char)) {
                    try c.iterate(&matrix, char);
                }
                if (c.tail > matrix.num_rows) {
                    const i = c.col;
                    c.* = col.Column.init(
                        i,
                        rng.random().intRangeAtMost(
                            usize,
                            0,
                            20,
                        ),
                    );
                }
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
    try ansi.setCursorPos(output, 0, 0);
    try ansi.clearScreen(output);
}
