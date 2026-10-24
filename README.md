# vulpea-agenda-timestamps

An Emacs package for reducing Org Agenda file scanning through Vulpea's indexed
tags and relevant ordinary active timestamps.

`SCHEDULED` and `DEADLINE` timestamps are intentionally excluded because the
intended workflow discovers their files through `vulpea-auto-tag` and its
`todo` tag.

## Development

The package requires Emacs 30.2 or newer.

Run the test suite in an isolated Emacs process:

```sh
make test
```

Run tests, strict byte compilation, and documentation checks:

```sh
make all
```

## Repository layout

```text
vulpea-agenda-timestamps.el Package entry point and public API
test/                        ERT tests and batch runner
Makefile                     Local and CI commands
.github/workflows/ci.yml     Continuous integration
docs/                        Design and cleanup-safety specifications
```

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
