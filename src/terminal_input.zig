const std = @import("std");

var char: ?u8 = null;
var run = true;
var io_thread: std.Thread = undefined;

fn readInput(reader: std.fs.File.Reader) !void {
    while (run) {
        char = try reader.readByte();
    }
}

pub fn init() !void {
    const stdin = std.io.getStdIn().reader();
    io_thread = try std.Thread.spawn(
        .{},
        readInput,
        .{stdin},
    );
    io_thread.detach();
}

pub fn getInput() ?u8 {
    var t: ?u8 = null;

    if (char) |c| {
        t = c;
        char = null;
    }
    return t;
}
