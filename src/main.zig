const std = @import("std");
const ansi = @import("ansi_term_codes.zig");
const cm = @import("cell_matrix.zig");
const col = @import("char_column.zig");
const termsize = @import("termsize");
const termctrl = @import("terminal_mode_control.zig");
const builtin = @import("builtin");

fn getInput(reader: std.fs.File.Reader, char: *u8) !void {
    while (char.* != 'q') {
        char.* = try reader.readByte();
    }
}

var orig_term_state: termctrl.TermStatus = undefined;

fn windows_exit_handler(ctrl_type: std.os.windows.DWORD) callconv(std.os.windows.WINAPI) std.os.windows.BOOL {
    _ = ctrl_type;
    cleanup(
        std.io.getStdIn().handle,
        std.io.getStdOut().writer(),
        orig_term_state,
    ) catch unreachable;
    return std.os.windows.FALSE;
}

fn posix_exit_handler(sig: i32, info: *const std.posix.siginfo_t, ctx_ptr: ?*anyopaque) callconv(.C) void {
    _ = ctx_ptr;
    if (sig == info.signo) {
        cleanup(
            std.io.getStdIn().handle,
            std.io.getStdOut().writer(),
            orig_term_state,
        ) catch unreachable;
        std.process.exit(0);
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
        orig_term_state = try termctrl.enableRawMode(std.io.getStdIn().handle);

        var rng = std.rand.DefaultPrng.init(@bitCast(std.time.timestamp()));

        if (builtin.os.tag == .windows) {
            std.os.windows.SetConsoleCtrlHandler(
                windows_exit_handler,
                std.os.windows.TRUE,
            );
        } else {
            var sa: std.posix.Sigaction = .{
                .handler = .{ .sigaction = posix_exit_handler },
                .mask = std.posix.empty_sigset,
                .flags = std.posix.SA.SIGINFO,
            };
            try std.posix.sigaction(std.posix.SIG.INT, &sa, null);
        }

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

        var charstrs = try allocator.alloc(col.ColumnList, 0);
        defer {
            for (charstrs) |*str| {
                str.deinit();
            }
            allocator.free(charstrs);
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
                for (charstrs) |*str| {
                    str.deinit();
                }
                allocator.free(charstrs);
                try ansi.clearScreen(stdout);

                matrix = try cm.CellMatrix.init(
                    rows,
                    cols,
                    allocator,
                    ansi.AnsiColor{ .color = .green },
                );
                charstrs = try allocator.alloc(col.ColumnList, cols);

                for (charstrs, 0..) |*c, i| {
                    c.* = col.ColumnList.init(allocator, i);
                }
            }

            try matrix.print(bufOut);
            try buffer.flush();

            for (charstrs) |*c| {
                try c.update(&matrix, rng.random());
            }
            prev_cols = cols;
            prev_rows = rows;

            std.time.sleep(printDelay);
        }
        try cleanup(std.io.getStdIn().handle, stdout, orig_term_state);
    } else {
        std.debug.print("Unable to start zmatrix: Could not determine terminal size\n", .{});
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
