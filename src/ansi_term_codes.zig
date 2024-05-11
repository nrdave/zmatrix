const std = @import("std");

pub const AnsiColorCode = enum(u8) {
    black = 0,
    red = 1,
    green = 2,
    yellow = 3,
    blue = 4,
    magenta = 5,
    cyan = 6,
    white = 7,
};

pub const AnsiColorType = enum(u8) {
    dark_text = 3,
    dark_bg = 4,
    bright_text = 9,
    bright_bg = 10,
};

pub const AnsiGraphicsMode = enum(u8) {
    normal = 0,
    bold = 1,
    dim = 2,
    italic = 3,
    underline = 4,
    blinking = 5,
    reverse = 7,
    hidden = 8,
    strikethrough = 9,
};

pub const AnsiColor = struct {
    color: AnsiColorCode = AnsiColorCode.black,
    type: AnsiColorType = AnsiColorType.dark_text,

    fn val(self: *const AnsiColor) u8 {
        return @intFromEnum(self.color) + @intFromEnum(self.type) * 10;
    }
};

pub fn setColors(
    fgcolor: AnsiColor,
    bgcolor: AnsiColor,
    writer: std.fs.File.Writer,
) !void {
    try writer.print("\x1b[{d};{d}m", .{
        fgcolor.val(),
        bgcolor.val(),
    });
}

pub fn resetCodes(writer: std.fs.File.Writer) !void {
    try writer.print("\x1b[0m", .{});
}

pub fn setMode(mode: AnsiGraphicsMode, writer: std.fs.File.Writer) !void {
    try writer.print("\x1b[{d}m", .{@intFromEnum(mode)});
}

pub fn clearMode(mode: AnsiGraphicsMode, writer: std.fs.File.Writer) !void {
    const code = switch (mode) {
        AnsiGraphicsMode.bold => 22,
        else => @intFromEnum(mode) + 20,
    };

    try writer.print("\x1b[{d}m", .{code});
}

pub fn clearScreen(writer: std.fs.File.Writer) !void {
    try writer.print("\x1b[2J", .{});
}

test "color_change" {
    const writer = std.io.getStdOut().writer();

    try setColors(
        AnsiColor{
            .color = AnsiColorCode.black,
            .type = AnsiColorType.dark_text,
        },
        AnsiColor{
            .color = AnsiColorCode.red,
            .type = AnsiColorType.bright_bg,
        },
        writer,
    );

    try writer.print("{c}\n", .{'z'});
    try resetCodes(writer);
}

test "mode change" {
    const writer = std.io.getStdOut().writer();

    try setColors(
        AnsiColor{
            .color = AnsiColorCode.black,
            .type = AnsiColorType.bright_text,
        },
        AnsiColor{
            .color = AnsiColorCode.blue,
            .type = AnsiColorType.dark_bg,
        },
        writer,
    );

    try setMode(AnsiGraphicsMode.strikethrough, writer);

    try writer.print("{s}\n", .{"hola"});

    try setMode(AnsiGraphicsMode.underline, writer);
    try writer.print("{s}\n", .{"lines"});

    try clearMode(AnsiGraphicsMode.strikethrough, writer);
    try writer.print("{s}", .{"line"});

    try resetCodes(writer);
    try writer.print("jj\n", .{});
}
