const std = @import("std");
const ansi = @import("ansi_term_codes.zig");
const cm = @import("cell_matrix.zig");
const col = @import("char_column.zig");
const termsize = @import("termsize");
const termctrl = @import("terminal_mode_control.zig");
const cleanutils = @import("cleanup.zig");

const Cleanup = cleanutils.Cleanup;

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

        try Cleanup.init(
            orig_term_state,
            std.io.getStdIn().handle,
            stdout,
        );

        try ansi.hideCursor(stdout);
        try ansi.clearScreen(stdout);

        var matrix: cm.CellMatrix = try cm.CellMatrix.init(
            0,
            0,
            allocator,
            .green,
            null,
        );

        defer matrix.deinit(allocator);

        var charstrs = std.ArrayList(col.ColumnList).init(allocator);
        defer {
            for (charstrs.items) |*c| {
                c.deinit();
            }
            charstrs.deinit();
        }

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
                for (charstrs.items) |*c| {
                    c.deinit();
                }
                charstrs.deinit();

                try ansi.clearScreen(stdout);

                matrix = try cm.CellMatrix.init(
                    rows,
                    cols,
                    allocator,
                    .green,
                    null,
                );
                charstrs = std.ArrayList(col.ColumnList).init(allocator);

                for (0..cols - 2) |i| {
                    if (i % 2 == 1) {
                        try charstrs.append(col.ColumnList.init(allocator, i));
                    }
                }
            }

            try matrix.print(bufOut);
            try buffer.flush();

            for (charstrs.items) |*c| {
                try c.update(&matrix, rng.random());
            }
            prev_cols = cols;
            prev_rows = rows;

            std.time.sleep(printDelay);
        }
        try Cleanup.cleanup();
    } else {
        std.debug.print("Unable to start zmatrix: Could not determine terminal size\n", .{});
    }
}
