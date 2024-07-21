// Struct containing all possible flags
// Used to pass flag info between functions when necessary
pub const Flags = packed struct {
    async_cols: bool = false,
    bold: bool = false,
    all_bold: bool = false,
};

pub const help_str = [_][]const u8{
    "Usage: zmatrix -[a]",
    "-a: asynchronous scroll - columns of characters move at different speeds",
};
