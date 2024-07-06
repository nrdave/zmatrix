const std = @import("std");
const ansi = @import("ansi_term_codes.zig");
const termctrl = @import("terminal_mode_control.zig");
const builtin = @import("builtin");

pub const Cleanup = struct {
    var term_state: termctrl.TermStatus = undefined;
    var input_handle: std.fs.File.Handle = std.io.getStdIn().handle;
    var output: std.fs.File.Writer = std.io.getStdOut().writer();

    pub fn init(
        t: termctrl.TermStatus,
        i: std.fs.File.Handle,
        o: std.fs.File.Writer,
    ) !void {
        term_state = t;
        input_handle = i;
        output = o;
        if (builtin.os.tag == .windows) {
            std.os.windows.SetConsoleCtrlHandler(
                &Cleanup.windows_exit_handler,
                std.os.windows.TRUE,
            );
        } else {
            var sa: std.posix.Sigaction = .{
                .handler = .{
                    .sigaction = &Cleanup.posix_exit_handler,
                },
                .mask = std.posix.empty_sigset,
                .flags = std.posix.SA.SIGINFO,
            };
            try std.posix.sigaction(std.posix.SIG.INT, &sa, null);
            try std.posix.sigaction(std.posix.SIG.TERM, &sa, null);
        }
    }

    fn windows_exit_handler(ctrl_type: std.os.windows.DWORD) callconv(std.os.windows.WINAPI) std.os.windows.BOOL {
        _ = ctrl_type;
        cleanup() catch unreachable;
        return std.os.windows.FALSE;
    }

    fn posix_exit_handler(sig: i32, info: *const std.posix.siginfo_t, ctx_ptr: ?*anyopaque) callconv(.C) void {
        _ = ctx_ptr;
        if (sig == info.signo) {
            cleanup() catch unreachable;
            std.process.exit(0);
        }
    }

    pub inline fn cleanup() !void {
        try termctrl.restoreTermMode(input_handle, term_state);
        try ansi.showCursor(output);
        try ansi.resetCodes(output);
        try ansi.setCursorPos(output, 0, 0);
        try ansi.clearScreen(output);
    }
};
