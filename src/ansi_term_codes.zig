const std = @import("std");

const esc = std.ascii.control_code.esc;

pub const ColorCode = enum(u8) {
    black = 30,
    red = 31,
    green = 32,
    yellow = 33,
    blue = 34,
    magenta = 35,
    cyan = 36,
    white = 37,
    default = 39,
    bright_black = 90,
    bright_red = 91,
    bright_green = 92,
    bright_yellow = 93,
    bright_blue = 94,
    bright_magenta = 95,
    bright_cyan = 96,
    bright_white = 97,
};

pub const GraphicsModes = packed struct {
    bold: bool = false,
    dim: bool = false,
    italics: bool = false,
    underline: bool = false,
    blinking: bool = false,
    inverse: bool = false,
    hidden: bool = false,
    strikethrough: bool = false,

    const set_mode_map = std.StaticStringMap(u8).initComptime(.{
        .{ "bold", 1 },
        .{ "dim", 2 },
        .{ "italics", 3 },
        .{ "underline", 4 },
        .{ "blinking", 5 },
        .{ "inverse", 7 },
        .{ "hidden", 8 },
        .{ "strikethrough", 9 },
    });

    const clear_mode_map = std.StaticStringMap(u8).initComptime(.{
        .{ "italics", 23 },
        .{ "underline", 24 },
        .{ "blinking", 25 },
        .{ "inverse", 27 },
        .{ "hidden", 28 },
        .{ "strikethrough", 29 },
    });

    const Self = @This();

    pub fn updateGraphicsModes(self: *GraphicsModes, writer: anytype) !void {
        // Handle bold and dim differently because the clear code for both is
        // the same. WHYYYYYY!
        if (!(self.bold and self.dim))
            try writer.print("{c}[22m", .{esc});
        inline for (std.meta.fields(Self)[0..2]) |field| {
            if (@field(self.*, field.name))
                try writer.print("{c}[{d}m", .{
                    esc,
                    set_mode_map.get(field.name).?,
                });
        }

        var code: u8 = 0;
        inline for (std.meta.fields(Self)[2..]) |field| {
            if (@field(self.*, field.name)) {
                code = set_mode_map.get(field.name).?;
            } else code = clear_mode_map.get(field.name).?;
            try writer.print("{c}[{d}m", .{ esc, code });
        }
    }
};

pub fn setForegroundColor(
    writer: anytype,
    code: ColorCode,
) !void {
    try writer.print("{c}[{d}m", .{
        esc,
        @intFromEnum(code),
    });
}
pub fn setBackgroundColor(
    writer: anytype,
    code: ColorCode,
) !void {
    try writer.print("{c}[{d}m", .{
        esc,
        @intFromEnum(code) + 10,
    });
}

pub fn resetCodes(writer: anytype) !void {
    try writer.print(
        "{c}[0m",
        .{esc},
    );
}

pub fn clearScreen(writer: anytype) !void {
    try writer.print("{c}[2J", .{esc});
}

pub fn hideCursor(writer: anytype) !void {
    try writer.print("{c}[?25l", .{esc});
}

pub fn showCursor(writer: anytype) !void {
    try writer.print("{c}[?25h", .{esc});
}

pub fn setCursorPos(writer: anytype, row: usize, col: usize) !void {
    try writer.print("{c}[{d};{d}H", .{
        esc,
        row,
        col,
    });
}

test "color_change" {
    const writer = std.io.getStdOut().writer();

    try setForegroundColor(writer, .bright_yellow);
    try setBackgroundColor(writer, .blue);

    try writer.print("{c}\n", .{'z'});

    try setForegroundColor(writer, .default);
    try setBackgroundColor(writer, .black);

    try writer.print("{c}\n", .{'a'});

    try setForegroundColor(writer, .green);
    try setBackgroundColor(writer, .default);

    try writer.print("{c}\n", .{'F'});

    try resetCodes(writer);
}

test "graphics_modes" {
    const writer = std.io.getStdOut().writer();

    var g = GraphicsModes{};

    g.bold = true;
    try g.updateGraphicsModes(writer);
    _ = try writer.write("hola\n");
    g.bold = false;
    try g.updateGraphicsModes(writer);
}
