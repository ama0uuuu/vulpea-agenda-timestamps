# My Package

A minimal, general-purpose project template for an Emacs Lisp package.

Before using it, replace `my-package` in file names and source code, then fill
in the author, URL, description, dependencies, keywords, and license details.

## Development

The template declares Emacs 29.1 as its minimum version. Change that version
to match the APIs used by the finished package.

Run the test suite in an isolated Emacs process:

```sh
make test
```

Run tests, byte compilation, and documentation checks:

```sh
make all
make checkdoc
```

## Repository layout

```text
my-package.el                Package entry point and public API
test/                        ERT tests and batch runner
Makefile                     Local and CI commands
.github/workflows/ci.yml     Continuous integration
```

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
