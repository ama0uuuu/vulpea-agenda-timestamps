# Timestamp-Based Vulpea Tagging Plan

## Goal

Maintain a conservative file-level tag for Vulpea notes that contain ordinary
active timestamps relevant today or in the future.  Consumers such as
`vulpea-agenda` can query that tag from Vulpea's index without opening every
candidate file while building an agenda.

`SCHEDULED` and `DEADLINE` timestamps are outside this package's scope.  In the
intended workflow, `vulpea-auto-tag` makes unfinished TODO files discoverable
through a separate `todo` tag.

## Data flow

```text
save an Org note
    |
    | vulpea-auto-tag rule parses the current buffer
    v
add or remove the timestamp file tag
    |
    | Vulpea indexes the saved metadata
    v
tag consumers query the database
```

The timestamp and TODO rules use distinct tags:

```elisp
(setq vulpea-agenda-tags '("todo" "timestamp"))
```

This prevents one automatic rule from removing a tag owned by another rule.

## Timestamp semantics

The rule uses calendar dates rather than wall-clock times.  It:

- includes ordinary active timestamps dated today or later;
- includes active ranges whose end date is today or later;
- conservatively includes repeating active timestamps;
- ignores inactive timestamps; and
- ignores `SCHEDULED` and `DEADLINE` planning timestamps.

TODO state does not affect ordinary timestamp selection.

## Tag maintenance

The normal path is the `vulpea-auto-tag-rules`-compatible save-time rule.  The
rule adds the configurable timestamp tag when the current buffer qualifies and
removes it otherwise.

Time passing can leave a past-only file tagged even though the file was not
edited.  This is a safe false positive: the tag was present before the event
date, so the event remains discoverable when due.  Stale tags can be removed
explicitly with:

```text
M-x vulpea-agenda-timestamps-cleanup-stale-tags
```

Existing notes can be initialized or fully refreshed with:

```text
M-x vulpea-agenda-timestamps-reindex
```

Both commands save only files whose tag changes, skip required edits in
buffers with unsaved changes, isolate per-file failures, and report completion
counts.

## Performance decision

This package does not advise `org-agenda-files`, filter paths during agenda
construction, or provide agenda profiling.  Measurements showed that parsing
candidate files at agenda time added substantial work while eliminating no
files in the representative dataset.  Indexed tag lookup is therefore the
only agenda-time mechanism; cleanup is an explicit maintenance operation.

`vulpea-agenda` remains an optional consumer rather than a package dependency.

## Test strategy

ERT tests cover timestamp classification, ranges, repeaters, planning and
inactive exclusions, automatic tag changes, unsaved-buffer protection,
maintenance outcome counts, full reindexing, and remove-only cleanup.  Tests
use temporary Org files and do not depend on the user's Vulpea database.
