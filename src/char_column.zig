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
        matrix.writeChar(' ', self.col, self.tail, null);
        matrix.writeChar(null, self.col, self.head, matrix.color);

        self.head += 1;
        self.tail += 1;

        matrix.writeChar(new_char, self.col, self.head, .bright_white);
    }
};

fn getRandNormalInt(rng: std.rand.Random, comptime T: type, min: T, max: T, concentration: f64) T {
    const min_float: f64 = @floatFromInt(min);
    const max_float: f64 = @floatFromInt(max);

    const mean: f64 = (max_float - min_float) / 2 + min_float;
    const stddev: f64 = (max_float - min_float) / (2 * concentration); // range of four standard deviations
    var float: f64 = rng.floatNorm(f64) * stddev + mean;
    if (float < min_float) {
        float = min_float;
    } else if (float > max_float) {
        float = max_float;
    }
    const num: T = @intFromFloat(float);
    return num;
}

fn createRandomColumn(col: usize, rows: usize, rng: std.rand.Random) Column {
    const head_offset: isize = @bitCast(rng.intRangeAtMost(
        usize,
        0,
        rows,
    ));
    const len = getRandNormalInt(
        rng,
        usize,
        rows / 16,
        rows,
        2,
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
        if (self.cols.items.len == 0)
            try self.cols.append(createRandomColumn(
                self.column,
                matrix.num_rows,
                rng,
            ));

        if (self.counter >= self.iterate_count) {
            // This method of removing elements from an ArrayList comes from jdh in this livestream:
            // https://www.youtube.com/live/ajbYYgbDXGk?si=T6sL_hrrBfW--8bB&t=12609
            // That said, I think I did it a tiny bit better (no struct member var)
            var i: usize = 0;
            var add_new_col = true;
            const new_char_row = rng.intRangeAtMost(
                usize,
                matrix.num_rows / 8,
                matrix.num_rows,
            );

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
                } else if (col.tail < new_char_row) {
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
    }
    pub fn deinit(self: *ColumnList) void {
        self.cols.deinit();
    }
};
