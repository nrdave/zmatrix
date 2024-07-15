# zmatrix

zmatrix is a (partial) clone of the popular
[cmatrix](https://github.com/abishekvashok/cmatrix) program written purely in
[Zig](https://ziglang.org/). It's currently just a project for me to learn
Zig as a language, but feel free to contribute any ideas/code.

As of 2024-06-14, zmatrix replicates the core functionality of cmatrix. It
prints characters falling down a terminal window, and a user can change the
color or falling speed of the characters.

## Dependencies

At the moment, zmatrix only depends on the
[zig-termsize](https://github.com/softprops/zig-termsize) library for
determining the terminal size regardless of platform. It's simple, but why
reinvent the wheel.

Unlike cmatrix, zmatrix does not depend on ncurses. This was done for a few
reasons, including

1. I don't know how to add ncurses as a dependency
2. Using ncurses would make compilation for different targets much harder
3. All I need for zmatrix is ANSI terminal codes, which can be set up rather
   easily
