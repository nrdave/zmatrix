const std = @import("std");
const ansi = @import("ansi_term_codes.zig");
const cm = @import("cell_matrix.zig");
const col = @import("char_column.zig");
const termsize = @import("termsize");
const termctrl = @import("terminal_mode_control.zig");
const cleanutils = @import("cleanup.zig");
const parg = @import("parg");
const options = @import("options.zig");

const Cleanup = cleanutils.Cleanup;

// Thread function for getting input from the user
// Not sure how ncurses gets input without blocking, so I
// just used a thread.
fn getInput(reader: std.fs.File.Reader, char: *u8) !void {
    while (char.* != 'q') {
        char.* = try reader.readByte();
    }
}

// Set up enum for delay between updates
// not gonna lie this was kind of just an excuse for me to do crazy
// metaprogramming stuff, but it works lol
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

const color_map = std.StaticStringMap(ansi.ColorCode).initComptime(.{
    .{ "black", .black },
    .{ "red", .red },
    .{ "green", .green },
    .{ "yellow", .yellow },
    .{ "blue", .blue },
    .{ "magenta", .magenta },
    .{ "cyan", .cyan },
    .{ "white", .white },
});

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    var t = try termsize.termSize(std.io.getStdOut());
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var flags: options.Flags = .{};

    var p = try parg.parseProcess(allocator, .{});
    defer p.deinit();

    // Skip executable name or panic if it's not found
    _ = p.nextValue() orelse @panic("no executable name");

    var color: ansi.ColorCode = .green;
    var bg_color: ansi.ColorCode = .default;

    while (p.next()) |token| {
        switch (token) {
            .flag => |flag| {
                if (flag.isShort("a")) {
                    flags.async_cols = true;
                } else if (flag.isShort("B")) {
                    flags.all_bold = true;
                } else if (flag.isShort("b")) {
                    flags.bold = true;
                } else if (flag.isShort("C")) {
                    const col_arg = p.nextValue() orelse @panic("Expected color after -C argument");
                    color = color_map.get(col_arg) orelse @panic("Invalid color specified as -C argument");
                } else if (flag.isShort("g")) {
                    const col_arg = p.nextValue() orelse "black";
                    bg_color = color_map.get(col_arg) orelse .black;
                } else if (flag.isShort("r")) {
                    flags.rainbow = true;
                } else {
                    inline for (options.help_str) |line| {
                        try stdout.print("{s}\n", .{line});
                    }
                    std.process.exit(0);
                }
            },
            .arg => {},
            .unexpected_value => @panic("unexpected value"),
        }
    }

    if (t) |*terminfo| {
        // If the termsize is available, create a cell matrix of that size
        var prev_cols: u16 = 0;
        var prev_rows: u16 = 0;
        const b = std.io.BufferedWriter(1_000_000, @TypeOf(stdout));
        var buffer: b = .{ .unbuffered_writer = stdout };
        const bufOut = buffer.writer();

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
            color,
            bg_color,
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
                    color,
                    bg_color,
                    null,
                );
                charstrs = std.ArrayList(col.ColumnList).init(allocator);

                for (0..cols) |i| {
                    // Only have columns for every other column in the terminal
                    // It looks a lot better (and is what cmatrix does)
                    if (i % 2 == 0) {
                        try charstrs.append(col.ColumnList.init(
                            allocator,
                            i,
                            flags,
                            &rng.random(),
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
                try c.update(&matrix);
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
