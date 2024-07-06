const std = @import("std");

const esc = std.ascii.control_code.esc;

pub const AnsiColorCode = enum(u8) {
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

pub fn setForegroundColor(
    writer: anytype,
    code: AnsiColorCode,
) !void {
    try writer.print("{c}[{d}m", .{
        esc,
        @intFromEnum(code),
    });
}
pub fn setBackgroundColor(
    writer: anytype,
    code: AnsiColorCode,
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
