# Timestamp-Based Vulpea Agenda Filtering Plan

## Goal

Reduce Org Agenda compilation time by limiting `org-agenda-files` to Vulpea
notes that can contribute entries to the requested agenda.

The design builds on two existing packages:

- [`vulpea-agenda`](https://github.com/darcamo/vulpea-agenda) queries Vulpea's
  indexed tag database and adds matching note paths to `org-agenda-files`.
- [`vulpea-auto-tag`](https://github.com/darcamo/vulpea-auto-tag) uses a
  buffer-local `before-save-hook` to add or remove file-level tags according to
  rules applied to the current buffer.

The extension will maintain a file tag for notes containing potentially
relevant ordinary active timestamps, then perform a date-aware check before
returning those files to Org Agenda.

`SCHEDULED` and `DEADLINE` timestamps are deliberately outside this package's
scope. In the intended workflow they occur only on unfinished TODO entries, so
`vulpea-auto-tag` already makes their files discoverable through the `todo`
tag. Completed timestamped entries also use those planning forms. The timestamp
extension therefore does not need to inspect TODO states.

## Core model

Use two filtering stages:

```text
All Vulpea notes
    |
    | fast indexed tag query
    v
Files tagged as timestamp candidates
    |
    | evaluate timestamps for the requested agenda period
    v
Files passed to org-agenda-files
```

The persistent tag is a coarse index. The date comparison is the exact,
time-dependent filter.

TODO files and timestamp files should use separate tags, for example:

```elisp
(setq vulpea-agenda-tags '("todo" "timestamp"))
```

Separate tags prevent independent automatic-tagging rules from incorrectly
removing a shared tag required by another rule.

## Persistent timestamp tag

Add a rule compatible with `vulpea-auto-tag-rules`. On save, it should:

1. Parse the current Org buffer.
2. Determine whether it contains a candidate active timestamp.
3. Add the `timestamp` file tag when a candidate exists.
4. Remove the tag when no candidate exists.

Use Org's parser rather than a regular expression. The parser is needed to
distinguish ordinary active timestamps from inactive timestamps and planning
timestamps, and to recognize ranges, repeaters, comments, and archived content.

The rule will conceptually return:

```elisp
'(("timestamp") . nil)  ; add
'(nil . ("timestamp"))  ; remove
```

## Date semantics

The initial comparison should use calendar dates rather than exact wall-clock
times. A timestamp earlier today must remain eligible for a daily agenda.

The ordinary timestamp rule is therefore:

```text
timestamp date >= beginning of today
```

The first implementation should account for:

- ordinary active timestamps written with angle brackets;
- active timestamp ranges;
- repeating timestamps;
- exclusion of `SCHEDULED` and `DEADLINE` planning timestamps;
- archived and commented subtrees; and
- inactive timestamps written with square brackets.

Safe initial behavior:

- Include an ordinary active timestamp dated today or later.
- Include a range whose relevant end is today or later.
- Always retain repeating active timestamps unless their Org semantics prove
  that they have ended.
- Ignore `SCHEDULED` and `DEADLINE` timestamps; the TODO-tag workflow owns
  discovery of those files.
- Ignore inactive timestamps.
- Do not inspect TODO states. Under the supported workflow, completed
  timestamped entries use excluded planning timestamps.
- Follow the chosen policy for archived and commented entries.

The exact filter should eventually accept the agenda's requested start and end
dates rather than assuming every command displays today. This is required for
weekly, monthly, future, and custom agenda commands.

## Why save-time tagging remains useful

Timestamp relevance changes as time passes, even if the file is never edited.
Consequently, `before-save-hook` alone cannot keep the tag perfectly current.

However, time passing normally creates a false positive rather than a false
negative:

```text
future timestamp -> tagged
current timestamp -> still tagged
past timestamp -> may remain tagged until cleaned
```

The stale tag may cause an unnecessary candidate check, but it does not hide
the entry when its date arrives. This makes the save-time tag suitable as a
conservative index.

Repeating timestamps and historical agenda commands require special care: a
tag must not be removed if doing so could make a later or explicitly requested
occurrence undiscoverable.

## Agenda-time filtering

`vulpea-agenda` advises `org-agenda-files`. Extend or compose with that advice
so it:

1. Obtains the ordinary `org-agenda-files` result.
2. Queries Vulpea for notes carrying the timestamp candidate tag.
3. Partitions candidates into relevant and stale files.
4. Adds only relevant candidates to the returned file list.
5. Removes duplicate paths.

This happens before Org performs its full agenda processing, so stale files can
be excluded from the current compilation.

The implementation should cache its result during one agenda construction
because Org may call `org-agenda-files` more than once.

## Stale-tag cleanup

Filtering stale candidates and removing their persistent tags are separate
operations.

Default behavior should only filter:

- Do not modify source files while constructing an agenda.
- Let the existing `before-save-hook` remove stale tags on a later user save.

Optional aggressive cleanup may remove stale tags during agenda preparation.
It must be explicitly enabled because it edits and saves user files. It needs
the following safeguards:

- Never overwrite a buffer with unsaved user changes.
- Detect whether the package opened a buffer itself.
- Kill only buffers opened by the package.
- Prevent recursive synchronization or agenda advice.
- Expect all normal save hooks to run.
- Update the source file rather than editing Vulpea's database directly.

Opening files can also trigger opportunistic cleanup through `find-file-hook`
or `org-mode-hook`, but this is supplementary:

- the hook runs only when a new visiting buffer is created;
- an existing buffer can be reused without firing it;
- changing a tag dirties the buffer and does not update the database until the
  file is saved; and
- merely closing a window does not kill or save its buffer.

`kill-buffer-hook` exists but is not appropriate for persistent synchronization
because kill-time edits can be discarded and a buffer may remain open while
time passes.

## Initial indexing

The save hook only processes files as they are saved. Provide a one-time command
to initialize existing notes, conceptually:

```text
M-x vulpea-agenda-timestamps-reindex
```

It should:

1. Query all Vulpea note paths.
2. Parse every note.
3. Add or remove the timestamp candidate tag.
4. Save only changed files.
5. Allow Vulpea to update its database normally.
6. Report files processed, changed, skipped, and failed.

The command should be safe to rerun.

## Implementation phases

### Phase 1: timestamp analysis

- Implement pure functions for classifying Org timestamp elements.
- Implement a buffer-level candidate predicate.
- Define date-boundary and timezone behavior.
- Test ordinary, inactive, ranged, and repeating cases, plus explicit exclusion
  of `SCHEDULED` and `DEADLINE` timestamps.

### Phase 2: automatic tag maintenance

- Implement the `vulpea-auto-tag`-compatible rule.
- Add configuration for the candidate tag name.
- Verify tag addition and removal on save.

### Phase 3: agenda integration

- Query timestamp-tagged paths through Vulpea.
- Filter candidates for the requested agenda interval.
- Integrate with the `org-agenda-files` advice.
- Deduplicate ordinary, TODO-tagged, and timestamp-tagged paths.
- Add a per-agenda-run cache.

### Phase 4: migration and maintenance

- Add the one-time reindex command. (Implemented.)
- Add an explicit stale-tag cleanup command. (Implemented.)
- Consider opt-in cleanup during agenda preparation. (Deferred: agenda
  construction remains read-only.)
- Consider a timer or `midnight-hook` only as a performance enhancement, not
  as the sole correctness mechanism. (Deferred until Phase 5 profiling shows
  that automatic cleanup would materially help.)

### Phase 5: profiling and refinement

- Measure candidate-query time, timestamp-filter time, and total agenda time.
  (Implemented as opt-in per-agenda profiling.)
- Count how many files each stage eliminates. (Implemented, including protected,
  parsed, relevant, and eliminated candidate counts.)
- Determine whether persistent stale-tag cleanup materially improves speed.
  (The report provides a cleanup signal and a before/after measurement workflow.)
- Optimize only after representative measurements. (No automatic cleanup or
  timer is enabled by default; real profiles must justify that tradeoff.)

## Test strategy

Use ERT with temporary Org files and isolated dynamic bindings. Do not depend on
the user's real Org configuration or Vulpea database.

Unit tests should cover:

- timestamps before, on, and after today;
- timestamps with and without times of day;
- active and inactive timestamps;
- single timestamps and ranges;
- repeaters;
- exclusion of scheduled and deadline entries;
- confirmation that TODO state does not affect ordinary timestamp selection;
- archived and commented headings;
- files containing multiple timestamp kinds; and
- behavior at day and timezone boundaries.

Integration tests should cover:

- adding the candidate tag on save;
- removing it when the final candidate disappears;
- retaining a harmless stale tag as time advances;
- excluding stale candidates from the current agenda file list;
- preserving ordinary `org-agenda-files` entries;
- combining TODO and timestamp candidates without duplicates;
- avoiding modification of unsaved buffers; and
- safely rerunning the initial reindex command.

Performance tests should measure behavior but should not impose fragile
wall-clock limits in the normal ERT suite. Correctness tests can instead assert
that irrelevant files never reach the expensive Org Agenda processing stage.

## Decisions to make before implementation

1. Whether historical agenda commands must discover timestamps whose candidate
   tags were previously removed.
2. Whether archived subtrees are always excluded or follow user configuration.
3. Whether agenda-time persistent cleanup is supported and, if so, whether it
   is disabled by default.
4. Whether this functionality belongs in a standalone package or as an
   extension contributed to one of the existing Vulpea packages.
