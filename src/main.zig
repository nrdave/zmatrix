const std = @import("std");
const ansi = @import("ansi_term_codes.zig");
const AnsiColorCode = ansi.AnsiColorCode;
const AnsiColorType = ansi.AnsiColorType;
const AnsiColor = ansi.AnsiColor;
const AnsiGraphicsMode = ansi.AnsiGraphicsMode;

pub fn main() !void {
    const writer = std.io.getStdOut().writer();

    try ansi.set_colors(
        AnsiColor{ .color = AnsiColorCode.black, .type = AnsiColorType.dark_text },
        AnsiColor{ .color = AnsiColorCode.red, .type = AnsiColorType.bright_bg },
        writer,
    );

    try writer.print("{c}\n", .{'z'});

    try ansi.set_colors(
        AnsiColor{ .color = AnsiColorCode.black, .type = AnsiColorType.bright_text },
        AnsiColor{ .color = AnsiColorCode.blue, .type = AnsiColorType.dark_bg },
        writer,
    );

    try ansi.set_mode(AnsiGraphicsMode.strikethrough, writer);

    try writer.print("{s}\n", .{"hola"});

    try ansi.set_mode(AnsiGraphicsMode.underline, writer);
    try writer.print("{s}\n", .{"lines"});

    try ansi.clear_mode(AnsiGraphicsMode.strikethrough, writer);
    try writer.print("{s}\n", .{"line"});

    try ansi.reset_codes(writer);
    try writer.print("\n", .{});
}
