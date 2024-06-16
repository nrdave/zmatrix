const std = @import("std");
const builtin = @import("builtin");

const is_windows = builtin.os.tag == .windows;

pub const TermStatus = if (is_windows) std.os.windows.DWORD else std.posix.termios;

pub fn enableRawMode(input: std.fs.File.Handle) !TermStatus {
    if (is_windows) {
        var orig_mode: TermStatus = undefined;

        if (std.os.windows.kernel32.GetConsoleMode(input, &orig_mode) == 0) {
            return switch (std.os.windows.kernel32.GetLastError()) {
                .INVALID_HANDLE => error.InvalidHandle,
                else => |err| std.os.windows.unexpectedError(err),
            };
        }

        var t = orig_mode;
        // This line clears the following flags
        // 0x04: ENABLE_ECHO_INPUT
        // 0x02: ENABLE_LINE_INPUT
        // It also sets the ENABLE_VIRTUAL_TERMINAL_INPUT flag 0x200
        t = t & ~(@as(std.os.windows.DWORD, 0x04 | 0x02)) | 0x200;
        if (std.os.windows.kernel32.SetConsoleMode(input, t) == 0) {
            return switch (std.os.windows.kernel32.GetLastError()) {
                .INVALID_HANDLE => error.InvalidHandle,
                else => |err| std.os.windows.unexpectedError(err),
            };
        }

        return orig_mode;
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
        if (std.os.windows.kernel32.SetConsoleMode(input, original_term_status) == 0) {
            return switch (std.os.windows.kernel32.GetLastError()) {
                .INVALID_HANDLE => error.InvalidHandle,
                else => |err| std.os.windows.unexpectedError(err),
            };
        }
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
