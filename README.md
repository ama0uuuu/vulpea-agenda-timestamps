# vulpea-agenda-timestamps

An Emacs package for reducing Org Agenda file scanning through Vulpea's indexed
tags and relevant ordinary active timestamps.

`SCHEDULED` and `DEADLINE` timestamps are intentionally excluded because the
intended workflow discovers their files through `vulpea-auto-tag` and its
`todo` tag.

## Configuration

Register the timestamp rule with `vulpea-auto-tag`:

```elisp
(with-eval-after-load 'vulpea-auto-tag
  (add-to-list 'vulpea-auto-tag-rules
               #'vulpea-agenda-timestamps-auto-tag-rule))
```

Enable `vulpea-auto-tag-sync-mode` in the Org buffers managed by Vulpea.  Its
save hook will add the `timestamp` tag when a relevant ordinary active
timestamp exists and remove the tag otherwise.

Configure `vulpea-agenda` to query both automatic tags:

```elisp
(setq vulpea-agenda-tags '("todo" "timestamp"))
```

Customize `vulpea-agenda-timestamps-tag` if a different timestamp tag is
preferred, and use the same value in `vulpea-agenda-tags`.

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
