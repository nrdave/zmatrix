// Struct containing all possible flags
// Used to pass flag info between functions when necessary
pub const Flags = packed struct {
    async_cols: bool = false,
    bold: bool = false,
    all_bold: bool = false,
    rainbow: bool = false,
};

pub const help_str = [_][]const u8{
    "Usage: zmatrix -[abBCh]",
    "-a: Asynchronous scroll - columns of characters move at different speeds",
    "-b: Bold - characters can be in bold",
    "-B: All bold - all characters are bold",
    "-C [color]: set the desired character color (default: green)",
    "-h: Help - print this help message",
    "-r: rainbow: random colors for each character",
};
