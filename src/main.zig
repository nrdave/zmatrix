const std = @import("std");
const ansi = @import("ansi_term_codes.zig");
const cm = @import("cell_matrix.zig");
const col = @import("char_column.zig");
const termsize = @import("termsize");
const termctrl = @import("terminal_mode_control.zig");
const cleanutils = @import("cleanup.zig");
const parg = @import("parg");

const Cleanup = cleanutils.Cleanup;

fn getInput(reader: std.fs.File.Reader, char: *u8) !void {
    while (char.* != 'q') {
        char.* = try reader.readByte();
    }
}

fn Delay() type {
    const updates_per_sec = [_]f64{
        20.0,
        40.0,
        60.0,
        80.0,
        100.0,
        120.0,
        160.0,
        200.0,
        250.0,
        500.0,
    };
    const ns_per_sec = 1_000_000_000;
    var fields: [updates_per_sec.len]std.builtin.Type.EnumField = undefined;
    var tmp_var: u32 = 0;
    for (updates_per_sec, 0..) |ups, i| {
        tmp_var = @intFromFloat(ups);
        fields[i] = .{
            .name = "UPS_" ++ std.fmt.comptimePrint("{d}", .{tmp_var}),
            .value = @intFromFloat(ns_per_sec / ups),
        };
    }
    return @Type(.{
        .Enum = .{
            .tag_type = u64,
            .fields = fields[0..],
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_exhaustive = true,
        },
    });
}

var printDelay: Delay() = .UPS_60;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    var t = try termsize.termSize(std.io.getStdOut());

    var async_enabled = false;

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

        var p = try parg.parseProcess(allocator, .{});
        defer p.deinit();

        // Skip executable name or panic if it's not found
        _ = p.nextValue() orelse @panic("no executable name");

        while (p.next()) |token| {
            switch (token) {
                .flag => |flag| {
                    if (flag.isShort("a"))
                        async_enabled = true;
                },
                .arg => {},
                .unexpected_value => @panic("unexpected value"),
            }
        }

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

                for (0..cols) |i| {
                    if (i % 2 == 0) {
                        try charstrs.append(col.ColumnList.init(
                            allocator,
                            i,
                            if (async_enabled)
                                rng.random().intRangeAtMost(u8, 3, 6)
                            else
                                null,
                        ));
                    }
                }
            }

            try matrix.print(bufOut);
            try buffer.flush();

            switch (input) {
                '!' => {
                    matrix.setColor(.red);
                },
                '@' => {
                    matrix.setColor(.green);
                },
                '#' => {
                    matrix.setColor(.yellow);
                },
                '$' => {
                    matrix.setColor(.blue);
                },
                '%' => {
                    matrix.setColor(.magenta);
                },
                '^' => {
                    matrix.setColor(.cyan);
                },
                '&' => {
                    matrix.setColor(.white);
                },
                '0' => {
                    printDelay = .UPS_500;
                },
                '1' => {
                    printDelay = .UPS_250;
                },
                '2' => {
                    printDelay = .UPS_200;
                },
                '3' => {
                    printDelay = .UPS_160;
                },
                '4' => {
                    printDelay = .UPS_120;
                },
                '5' => {
                    printDelay = .UPS_100;
                },
                '6' => {
                    printDelay = .UPS_80;
                },
                '7' => {
                    printDelay = .UPS_60;
                },
                '8' => {
                    printDelay = .UPS_40;
                },
                '9' => {
                    printDelay = .UPS_20;
                },

                else => {},
            }

            for (charstrs.items) |*c| {
                try c.update(&matrix, rng.random());
            }
            prev_cols = cols;
            prev_rows = rows;

            std.time.sleep(@intFromEnum(printDelay));
        }
        try Cleanup.cleanup();
    } else {
        std.debug.print("Unable to start zmatrix: Could not determine terminal size\n", .{});
    }
}
