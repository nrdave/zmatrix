const std = @import("std");
const ansi = @import("ansi_term_codes.zig");
const Terminal = @import("Terminal.zig");
const options = @import("options.zig");

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

    pub fn iterate(
        self: *Column,
        new_char: u8,
        new_char_color: ?ansi.ColorCode,
        new_char_modes: ?ansi.GraphicsModes,
        last_color: ?ansi.ColorCode,
    ) void {
        Terminal.writeChar(
            ' ',
            self.col,
            self.tail,
            null,
            null,
            null,
        );
        Terminal.writeChar(
            null,
            self.col,
            self.head,
            last_color,
            null,
            null,
        );

        self.head += 1;
        self.tail += 1;

        Terminal.writeChar(
            new_char,
            self.col,
            self.head,
            new_char_color orelse .default,
            null,
            new_char_modes orelse null,
        );
    }
};

fn getRandNormalInt(rng: std.Random, comptime T: type, min: T, max: T, concentration: f64) T {
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

fn createRandomColumn(col: usize, rows: usize, rng: *const std.Random) Column {
    const head_offset: isize = @bitCast(rng.intRangeAtMost(
        usize,
        0,
        rows,
    ));
    const len = getRandNormalInt(
        rng.*,
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
    iterate_count: u8,
    flags: *options.Flags,
    color: ansi.ColorCode,
    rng: *const std.Random,

    const default_iterate_count = 3;

    // Odds out of 10 that a given char is bold (assuming the bold flag is set)
    const bold_odds = 3;

    pub fn init(
        allocator: std.mem.Allocator,
        column: usize,
        flags: *options.Flags,
        rng: *const std.Random,
        color: ansi.ColorCode,
    ) ColumnList {
        const c = ColumnList{
            .column = column,
            .counter = 0,
            .cols = std.ArrayList(Column).init(allocator),
            .iterate_count = if (flags.async_cols) rng.intRangeAtMost(
                u8,
                ColumnList.default_iterate_count,
                ColumnList.default_iterate_count * 2,
            ) else default_iterate_count,
            .flags = flags,
            .rng = rng,
            .color = color,
        };
        return c;
    }

    pub fn update(
        self: *ColumnList,
    ) !void {
        self.counter += 1;
        var char: u8 = '0';
        if (self.cols.items.len == 0)
            try self.cols.append(createRandomColumn(
                self.column,
                Terminal.getHeight(),
                self.rng,
            ));

        if (self.counter >= self.iterate_count) {
            var i: usize = 0;
            var add_new_col = true;
            const new_char_row = self.rng.intRangeAtMost(
                usize,
                Terminal.getHeight() / 8,
                Terminal.getHeight(),
            );

            while (i < self.cols.items.len) {
                const col = &self.cols.items[i];
                var remove = false;
                // Printable ASCII chars range from 32 to 127, but 32 is
                // space and 127 is delete. The other chars are visible
                char = self.rng.intRangeLessThan(
                    u8,
                    33,
                    126,
                );
                var g = ansi.GraphicsModes{};

                // Handle bold character flags
                if (self.flags.all_bold) {
                    g.bold = true;
                } else if (self.flags.bold) {
                    if (self.rng.intRangeAtMost(u8, 0, 10) < bold_odds)
                        g.bold = true;
                }
                col.iterate(
                    char,
                    if (self.flags.rainbow) @enumFromInt(self.rng.intRangeAtMost(
                        u8,
                        @intFromEnum(ansi.ColorCode.red),
                        @intFromEnum(ansi.ColorCode.white),
                    )) else null,
                    g,
                    if (self.flags.rainbow) null else self.color,
                );

                // This method of removing elements from an ArrayList comes from jdh in this livestream:
                // https://www.youtube.com/live/ajbYYgbDXGk?si=T6sL_hrrBfW--8bB&t=12609
                // That said, I think I did it a tiny bit better (no struct member var)
                if (col.tail >= Terminal.getHeight()) {
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
                    Terminal.getHeight(),
                    self.rng,
                ));
        }
    }
    pub fn deinit(self: *ColumnList) void {
        self.cols.deinit();
    }
};
