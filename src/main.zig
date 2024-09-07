const std = @import("std");
const ansi = @import("ansi_term_codes.zig");
const col = @import("char_column.zig");
const Terminal = @import("Terminal.zig");
const parg = @import("parg");
const options = @import("options.zig");

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
    const b = std.io.BufferedWriter(1_000_000, @TypeOf(stdout));
    var buffer: b = .{ .unbuffered_writer = stdout };
    const bufOut = buffer.writer();

    try Terminal.init(allocator);
    try Terminal.enableRawMode();
    defer Terminal.deinit() catch unreachable;

    var rng = std.rand.DefaultPrng.init(@bitCast(std.time.timestamp()));
    try ansi.hideCursor(stdout);
    try ansi.clearScreen(stdout);

    for (Terminal.getGrid()) |row| {
        for (row) |*cell| {
            cell.setBgColor(bg_color);
        }
    }

    var charstrs = std.ArrayList(col.ColumnList).init(allocator);
    defer {
        for (charstrs.items) |*c| {
            c.deinit();
        }
        charstrs.deinit();
    }
    for (0..Terminal.getWidth()) |i| {
        // Only have columns for every other column in the terminal
        // It looks a lot better (and is what cmatrix does)
        if (i % 2 == 0) {
            try charstrs.append(col.ColumnList.init(
                allocator,
                i,
                &flags,
                &rng.random(),
                color,
            ));
        }
    }

    var input: ?u8 = 0;

    while (true) {
        input = Terminal.getRawInput();

        if (Terminal.checkSizeChange()) {
            for (charstrs.items) |*c| {
                c.deinit();
            }
            charstrs.deinit();

            try ansi.clearScreen(stdout);

            try Terminal.updateSize();

            for (Terminal.getGrid()) |row| {
                for (row) |*cell| {
                    cell.setBgColor(bg_color);
                }
            }

            charstrs = std.ArrayList(col.ColumnList).init(allocator);

            for (0..Terminal.getWidth()) |i| {
                // Only have columns for every other column in the terminal
                // It looks a lot better (and is what cmatrix does)
                if (i % 2 == 0) {
                    try charstrs.append(col.ColumnList.init(
                        allocator,
                        i,
                        &flags,
                        &rng.random(),
                        color,
                    ));
                }
            }
        }

        try Terminal.print(bufOut);
        try buffer.flush();

        if (input) |i| {
            switch (i) {
                '!', '@', '#', '$', '%', '^', '&' => |c| {
                    color = switch (c) {
                        '!' => .red,
                        '@' => .green,
                        '#' => .yellow,
                        '$' => .blue,
                        '%' => .magenta,
                        '^' => .cyan,
                        '&' => .white,
                        else => .default,
                    };
                    flags.rainbow = false;
                    setColor(color);
                    for (charstrs.items) |*colList| {
                        colList.color = color;
                    }
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
                'q' => {
                    break;
                },
                else => {},
            }
        }

        for (charstrs.items) |*c| {
            try c.update();
        }
        std.time.sleep(@intFromEnum(printDelay));
    }
}

fn setColor(color: ansi.ColorCode) void {
    for (Terminal.getGrid()) |row| {
        for (row) |*cell| {
            cell.setFgColor(color);
        }
    }
}
