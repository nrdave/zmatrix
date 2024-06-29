const std = @import("std");
const cm = @import("cell_matrix.zig");

pub const Column = struct {
    col: usize,
    head: usize,
    len: usize,
    tail: isize,

    pub fn init(col: usize, len: usize) Column {
        const temp: isize = @bitCast(len);
        return Column{
            .col = col,
            .head = 0,
            .len = len,
            .tail = -temp,
        };
    }

    pub fn iterate(self: *Column, matrix: *cm.CellMatrix, newChar: u8) !void {
        matrix.writeChar(' ', self.col, self.tail);

        self.head += 1;
        self.tail += 1;

        matrix.writeChar(newChar, self.col, @bitCast(self.head));
    }
};
