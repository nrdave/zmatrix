const std = @import("std");

const AnsiColorCode = enum(u8) {
    black = 0,
    red = 1,
    green = 2,
    yellow = 3,
    blue = 4,
    magenta = 5,
    cyan = 6,
    white = 7,
};

const AnsiColorType = enum(u8) {
    dark_text = 3,
    dark_bg = 4,
    bright_text = 9,
    bright_bg = 10,
};

const AnsiColor = struct {
    color: AnsiColorCode = AnsiColorCode.black,
    type: AnsiColorType = AnsiColorType.dark_text,

    fn val(self: *const AnsiColor) u8 {
        return @intFromEnum(self.color) + @intFromEnum(self.type) * 10;
    }
};

fn set_character_colors(
    fgcolor: AnsiColor,
    bgcolor: AnsiColor,
    writer: std.fs.File.Writer,
) !void {
    try writer.print("\x1b[{d};{d}m", .{
        fgcolor.val(),
        bgcolor.val(),
    });
}

fn reset_terminal_colors(writer: std.fs.File.Writer) !void {
    try writer.print("\x1b[0m", .{});
}

pub fn main() !void {
    const writer = std.io.getStdOut().writer();

    try set_character_colors(
        AnsiColor{ .color = AnsiColorCode.black, .type = AnsiColorType.dark_text },
        AnsiColor{ .color = AnsiColorCode.red, .type = AnsiColorType.bright_bg },
        writer,
    );

    try writer.print("{c}", .{'z'});
    try reset_terminal_colors(writer);
}
