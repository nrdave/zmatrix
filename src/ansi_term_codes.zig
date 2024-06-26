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

pub const AnsiColor = struct {
    color: AnsiColorCode = AnsiColorCode.black,
    category: AnsiColorType = AnsiColorType.dark_text,

    fn val(self: *const AnsiColor) u8 {
        return @intFromEnum(self.color) + @intFromEnum(self.category) * 10;
    }
};

pub fn setColor(
    color: AnsiColor,
    writer: anytype,
) !void {
    try writer.print("\x1b[{d}m", .{
        color.val(),
    });
}

pub fn resetCodes(writer: anytype) !void {
    try writer.print("\x1b[0m", .{});
}

pub fn clearScreen(writer: anytype) !void {
    try writer.print("\x1b[2J", .{});
}

pub fn hideCursor(writer: anytype) !void {
    try writer.print("\x1b[?25l", .{});
}

pub fn showCursor(writer: anytype) !void {
    try writer.print("\x1b[?25h", .{});
}

pub fn setCursorPos(writer: anytype, row: usize, col: usize) !void {
    try writer.print("\x1b[{d};{d}H", .{ row, col });
}

test "color_change" {
    const writer = std.io.getStdOut().writer();

    try setColor(
        AnsiColor{
            .color = AnsiColorCode.black,
            .category = AnsiColorType.dark_text,
        },

        writer,
    );

    try writer.print("{c}\n", .{'z'});
    try resetCodes(writer);
}
