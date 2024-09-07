const std = @import("std");
const ansi = @import("ansi_term_codes.zig");
const window = @import("terminal_window.zig");
const modectrl = @import("terminal_mode_control.zig");
const input = @import("terminal_input.zig");
const builtin = @import("builtin");

var term_mode: modectrl.TermStatus = undefined;

pub fn init() !void {
    const stdin = std.io.getStdIn();

    try input.init();

    term_mode = try modectrl.enableRawMode(stdin.handle);
    if (builtin.os.tag == .windows) {
        try std.os.windows.SetConsoleCtrlHandler(
            windows_exit_handler,
            true,
        );
    } else {
        var sa: std.posix.Sigaction = .{
            .handler = .{
                .sigaction = posix_exit_handler,
            },
            .mask = std.posix.empty_sigset,
            .flags = std.posix.SA.SIGINFO,
        };
        try std.posix.sigaction(std.posix.SIG.INT, &sa, null);
        try std.posix.sigaction(std.posix.SIG.TERM, &sa, null);
    }
}

pub const getInput = input.getInput;

pub fn deinit() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn();
    try modectrl.restoreTermMode(stdin.handle, term_mode);
    try ansi.showCursor(stdout);
    try ansi.resetCodes(stdout);
    try ansi.setCursorPos(stdout, 0, 0);
    try ansi.clearScreen(stdout);
}

fn windows_exit_handler(ctrl_type: std.os.windows.DWORD) callconv(std.os.windows.WINAPI) std.os.windows.BOOL {
    _ = ctrl_type;
    deinit() catch unreachable;
    return std.os.windows.FALSE;
}

fn posix_exit_handler(sig: i32, info: *const std.posix.siginfo_t, ctx_ptr: ?*anyopaque) callconv(.C) void {
    _ = ctx_ptr;
    if (sig == info.signo) {
        deinit() catch unreachable;
        std.process.exit(0);
    }
}
