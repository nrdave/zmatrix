const std = @import("std");
const cm = @import("cell_matrix.zig");

pub const Column = struct {
    col: usize,
    head: isize,
    len: usize,
    tail: isize,

    pub fn init(col: usize, head: isize, len: usize) Column {
        const temp: isize = @bitCast(len);
        return Column{
            .col = col,
            .head = head,
            .len = len,
            .tail = head - temp,
        };
    }

    pub fn iterate(self: *Column, matrix: *cm.CellMatrix, newChar: u8) !void {
        matrix.writeChar(' ', self.col, self.tail);

        self.head += 1;
        self.tail += 1;

        matrix.writeChar(newChar, self.col, @bitCast(self.head));
    }
};

pub fn createRandomColumn(col: usize, rows: usize, rng: std.rand.Random) Column {
    const head_offset: isize = @bitCast(rng.intRangeAtMost(
        usize,
        0,
        rows / 4,
    ));
    const len = rng.intRangeAtMost(
        usize,
        rows / 8,
        rows / 4,
    );
    return Column.init(
        col,
        0 - head_offset,
        len,
    );
}
