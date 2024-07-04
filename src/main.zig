const std = @import("std");
const ansi = @import("ansi_term_codes.zig");
const cm = @import("cell_matrix.zig");
const col = @import("char_column.zig");
const termsize = @import("termsize");
const termctrl = @import("terminal_mode_control.zig");

fn getInput(reader: std.fs.File.Reader, char: *u8) !void {
    while (char.* != 'q') {
        char.* = try reader.readByte();
    }
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    var t = try termsize.termSize(std.io.getStdOut());

    const printDelay = 16_666_667; // Approximately the number of nanoseconds to delay to get 60 FPS

    if (t) |*terminfo| {
        // If the termsize is available, create a cell matrix of that size
        var prev_cols: u16 = 0;
        var prev_rows: u16 = 0;
        const b = std.io.BufferedWriter(1_000_000, @TypeOf(stdout));
        var buffer: b = .{ .unbuffered_writer = stdout };
        const bufOut = buffer.writer();

        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = gpa.allocator();
        defer _ = gpa.deinit();

        // Enable the Raw Terminal mode (and store the previous mode for when the program exits)
        const orig_term_state = try termctrl.enableRawMode(std.io.getStdIn().handle);

        var rng = std.rand.DefaultPrng.init(@bitCast(std.time.timestamp()));
        var char = rng.random().intRangeAtMost(u8, 0, 127);

        try ansi.hideCursor(stdout);
        try ansi.clearScreen(stdout);

        var matrix: cm.CellMatrix = try cm.CellMatrix.init(
            0,
            0,
            allocator,
            ansi.AnsiColor{
                .color = .green,
            },
        );

        defer matrix.deinit(allocator);

        var charcols: []col.Column = try allocator.alloc(col.Column, 0);
        defer allocator.free(charcols);

        var input: u8 = 0;

        var io_thread = try std.Thread.spawn(
            .{},
            getInput,
            .{ stdin, &input },
        );
        defer io_thread.join();

        var cols: u16 = 0;
        var rows: u16 = 0;

        while (input != 'q') {
            t = (try termsize.termSize(std.io.getStdOut())).?;
            cols = terminfo.width;
            rows = terminfo.height;

            if ((cols != prev_cols) or (rows != prev_rows)) {
                matrix.deinit(allocator);
                allocator.free(charcols);

                matrix = try cm.CellMatrix.init(rows, cols, allocator, ansi.AnsiColor{ .color = .green });

                charcols = try allocator.alloc(col.Column, cols);
                for (0.., charcols) |i, *c| {
                    c.* = col.Column.init(
                        i,
                        rng.random().intRangeAtMost(
                            usize,
                            5,
                            cols / 4,
                        ),
                    );
                }
            }

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
            prev_cols = cols;
            prev_rows = rows;

            std.time.sleep(printDelay);
        }
        try cleanup(std.io.getStdIn().handle, stdout, orig_term_state);
    } else {
        std.debug.print("Unable to start zmatrix: Could not determine terminal size", .{});
    }
}

inline fn cleanup(
    input_handle: std.fs.File.Handle,
    output: std.fs.File.Writer,
    original_term_state: termctrl.TermStatus,
) !void {
    try termctrl.restoreTermMode(input_handle, original_term_state);
    try ansi.showCursor(output);
    try ansi.resetCodes(output);
    try ansi.setCursorPos(output, 0, 0);
    try ansi.clearScreen(output);
}
