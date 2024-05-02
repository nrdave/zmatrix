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

fn print_colored_char(
    char: u8,
    fgcolor: AnsiColor,
    bgcolor: AnsiColor,
) !void {
    try std.io.getStdOut().writer().print("\x1b[{d};{d}m{c}\x1b[0m\n", .{
        fgcolor.val(),
        bgcolor.val(),
        char,
    });
}

pub fn main() !void {
    try print_colored_char(
        'z',
        AnsiColor{ .color = AnsiColorCode.black, .type = AnsiColorType.dark_text },
        AnsiColor{ .color = AnsiColorCode.red, .type = AnsiColorType.bright_bg },
    );
}
