# Safeguards for Explicit Stale-Tag Cleanup

## Purpose

`vulpea-agenda-timestamps-cleanup-stale-tags` examines indexed notes carrying
the package-owned timestamp tag and removes that tag when no relevant ordinary
active timestamp remains.  Cleanup is explicit; agenda construction never
edits or parses these files.

## Safety properties

The command:

- queries only notes carrying the configured timestamp tag;
- reevaluates each note from its current buffer contents;
- removes only the configured tag and preserves unrelated file tags;
- never adds a tag in cleanup mode;
- skips an edit when the visiting buffer has unsaved changes;
- saves changes normally so backups, hooks, and Vulpea indexing still run;
- leaves pre-existing buffers open;
- closes clean buffers that it opened itself;
- isolates errors to one file and continues processing; and
- reports processed, changed, skipped, and failed counts.

A package-level guard prevents overlapping reindex or cleanup operations.
Automatic tag synchronization is idempotent, so its save hook produces the
same tag state when cleanup saves a changed file.

## Relevance policy

A timestamp tag is retained for:

- an ordinary active timestamp today or in the future;
- an active range whose end is today or later; or
- a repeating active timestamp, regardless of its base date.

Inactive timestamps and `SCHEDULED` or `DEADLINE` planning timestamps do not
retain this tag.  Those planning timestamps belong to the separate TODO-tag
workflow.

Past non-repeating timestamps are deliberately removed by cleanup.  Users who
depend on discovering past ordinary timestamps through the tag should not run
the cleanup command.

## Recovery

Cleanup can modify many notes.  Run it only with normal Emacs backup or version
control protection in place.  Files skipped because of unsaved changes can be
saved or reverted deliberately and handled by a later cleanup run.
