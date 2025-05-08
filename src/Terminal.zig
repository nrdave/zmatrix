const std = @import("std");
const ansi = @import("ansi_term_codes.zig");
const window = @import("terminal_window.zig");
const modectrl = @import("terminal_mode_control.zig");
const input = @import("terminal_input.zig");
const builtin = @import("builtin");
const termsize = @import("termsize");

var term_mode: ?modectrl.TermStatus = null;
pub var term_height: u16 = 0;
pub var term_width: u16 = 0;

var alloc: std.mem.Allocator = undefined;
var stdin: std.fs.File = undefined;

pub fn init(allocator: std.mem.Allocator) !void {
    const ts = try termsize.termSize(std.io.getStdOut());
    stdin = std.io.getStdIn();

    if (ts) |t| {
        alloc = allocator;

        try window.init(t.height, t.width, alloc);

        term_height = t.height;
        term_width = t.width;

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
            std.posix.sigaction(std.posix.SIG.INT, &sa, null);
            std.posix.sigaction(std.posix.SIG.TERM, &sa, null);
        }
    }
}

pub fn enableRawMode() !void {
    try input.init();
    term_mode = try modectrl.enableRawMode(stdin.handle);
}

pub const getRawInput = input.getInput;
pub const writeChar = window.writeChar;

pub fn checkSizeChange() bool {
    var size_changed = false;

    const ts = (termsize.termSize(stdin) catch unreachable).?;

    if ((ts.height != term_height) or (ts.width != term_width)) {
        term_height = ts.height;
        term_width = ts.width;

        size_changed = true;
    }
    return size_changed;
}

pub fn updateSize() !void {
    try window.resize(term_height, term_width, alloc);
}

pub fn getHeight() u16 {
    return term_height;
}
pub fn getWidth() u16 {
    return term_width;
}
pub const getGrid = window.getGrid;
pub const print = window.print;

pub fn deinit() !void {
    const stdout = std.io.getStdOut().writer();

    window.deinit(alloc);
    if (term_mode) |t|
        try modectrl.restoreTermMode(stdin.handle, t);

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
