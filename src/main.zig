const std = @import("std");
const ansi = @import("ansi_colors.zig");
const AnsiColorCode = ansi.AnsiColorCode;
const AnsiColorType = ansi.AnsiColorType;
const AnsiColor = ansi.AnsiColor;

pub fn main() !void {
    const writer = std.io.getStdOut().writer();

    try ansi.set_character_colors(
        AnsiColor{ .color = AnsiColorCode.black, .type = AnsiColorType.dark_text },
        AnsiColor{ .color = AnsiColorCode.red, .type = AnsiColorType.bright_bg },
        writer,
    );

    try writer.print("{c}", .{'z'});
    try ansi.reset_terminal_colors(writer);
}
