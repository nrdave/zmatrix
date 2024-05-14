const std = @import("std");
const builtin = @import("builtin");

const is_windows = builtin.os.tag == .windows;

const TermStatus = if (is_windows) std.windows.DWORD else std.posix.termios;

pub fn enableRawMode(input: std.fs.File.Handle) !TermStatus {
    if (is_windows) {
        @compileError("Windows support not ready");
    } else {
        const orig_termios = try std.posix.tcgetattr(input);
        var t = orig_termios;
        t.lflag.ECHO = false;
        t.lflag.ICANON = false;
        try std.posix.tcsetattr(input, std.posix.TCSA.FLUSH, t);

        return orig_termios;
    }
}

pub fn restoreTermMode(input: std.fs.File.Handle, original_term_status: TermStatus) !void {
    if (is_windows) {
        @compileError("Windows support not ready");
    } else {
        try std.posix.tcsetattr(input, std.posix.TCSA.FLUSH, original_term_status);
    }
}

test "raw_term_mode" {
    var c: u8 = 'a';
    const stdin = std.io.getStdIn();

    const t = try enableRawMode(stdin.handle);

    std.debug.print(
        "Press q to quit. Other chars do nothing. No characters should appear\n",
        .{},
    );

    while (c != 'q') {
        c = try stdin.reader().readByte();
    }

    try restoreTermMode(stdin.handle, t);
}
