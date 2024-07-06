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

    pub fn iterate(self: *Column, matrix: *cm.CellMatrix, new_char: u8) void {
        matrix.writeChar(' ', self.col, self.tail);

        self.head += 1;
        self.tail += 1;

        matrix.writeChar(new_char, self.col, @bitCast(self.head));
    }
};

pub fn createRandomColumn(col: usize, rows: usize, rng: std.rand.Random) Column {
    const head_offset: isize = @bitCast(rng.intRangeAtMost(
        usize,
        0,
        rows / 2,
    ));
    const len = rng.intRangeAtMost(
        usize,
        rows / 8,
        rows,
    );
    return Column.init(
        col,
        0 - head_offset,
        len,
    );
}

pub const ColumnList = struct {
    cols: std.ArrayList(Column),
    column: usize,
    counter: u8,
    iterate_count: u8 = 3,

    pub fn init(allocator: std.mem.Allocator, column: usize) ColumnList {
        const c = ColumnList{
            .column = column,
            .counter = 0,
            .cols = std.ArrayList(Column).init(allocator),
        };
        return c;
    }

    pub fn update(
        self: *ColumnList,
        matrix: *cm.CellMatrix,
        rng: std.rand.Random,
    ) !void {
        self.counter += 1;
        var char: u8 = '0';
        if (self.counter >= self.iterate_count) {
            // This method of removing elements from an ArrayList comes from jdh in this livestream:
            // https://www.youtube.com/live/ajbYYgbDXGk?si=T6sL_hrrBfW--8bB&t=12609
            // That said, I think I did it a tiny bit better (no struct member var)
            var i: usize = 0;
            var add_new_col = true;
            while (i < self.cols.items.len) {
                const col = &self.cols.items[i];
                var remove = false;
                // Printable ASCII chars range from 32 to 127, but 32 is
                // space and 127 is delete. The other chars are visible
                char = rng.intRangeLessThan(
                    u8,
                    33,
                    126,
                );
                col.iterate(matrix, char);

                if (col.tail >= matrix.num_rows) {
                    remove = true;
                } else if (col.tail < matrix.num_rows / 4) {
                    add_new_col = false;
                }
                if (remove) {
                    _ = self.cols.swapRemove(i);
                } else i += 1;
            }
            self.counter = 0;
            if (add_new_col)
                try self.cols.append(createRandomColumn(
                    self.column,
                    matrix.num_rows,
                    rng,
                ));
        }
        if (self.cols.items.len == 0)
            try self.cols.append(createRandomColumn(
                self.column,
                matrix.num_rows,
                rng,
            ));
    }
    pub fn deinit(self: *ColumnList) void {
        self.cols.deinit();
    }
};
