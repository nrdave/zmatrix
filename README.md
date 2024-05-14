# zmatrix

zmatrix is a (partial) clone of the popular
[cmatrix](https://github.com/abishekvashok/cmatrix) program written purely in
[Zig](https://ziglang.org/). It's currently just a project for me to learn
Zig as a language, but feel free to contribute any ideas/code.

Right now, zmatrix is still in development. It has yet to reach even the basic
functionality of cmatrix.

## Dependencies

Unlike cmatrix, zmatrix does not depend on ncurses. This was done for a few
reasons, including

1. I don't know how to add ncurses as a dependency
2. Using ncurses would make compilation for different targets much harder
3. All I need for zmatrix is ANSI terminal codes, which can be set up rather
   easily
