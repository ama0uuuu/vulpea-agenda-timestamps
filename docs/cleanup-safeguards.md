# Safeguards for Explicit Stale-Tag Cleanup

## Purpose

The explicit cleanup command scans notes carrying the package-owned timestamp
tag, identifies tags that are no longer needed, and removes them from the
corresponding Org files.

Because this is a bulk operation that may edit and save many user files, its
default behavior must be conservative, reviewable, and recoverable.

## User workflow

Use a two-step workflow:

```text
Run cleanup preview
    |
    v
Scan candidate files without modifying them
    |
    v
Display proposed changes and skipped files
    |
    v
User explicitly confirms application
    |
    v
Apply changes one file at a time
    |
    v
Display final results
```

Prefer separate commands rather than multiple hidden prefix-argument modes:

```elisp
PACKAGE-cleanup-preview
PACKAGE-cleanup-apply
PACKAGE-reindex
```

- `PACKAGE-cleanup-preview` never writes files.
- `PACKAGE-cleanup-apply` previews, requests confirmation, and then applies
  approved changes.
- `PACKAGE-reindex` performs a broader initial or repair scan.

## Required safeguards

### Modify only the package-owned tag

Remove only the tag named by the package's configuration variable. Preserve all
unrelated file tags.

Do not replace the complete tag list using a previously captured value. Another
hook or user edit may have changed that list since it was read.

### Revalidate immediately before editing

Do not modify a file solely because an earlier scan classified it as stale.
Immediately before removal:

1. Read the current contents.
2. Parse the Org buffer again.
3. Confirm that the package tag is still present.
4. Confirm that the timestamp predicate still considers it stale.
5. Skip the file if parsing fails or the result is ambiguous.

The default policy should prefer leaving an unnecessary tag over removing a tag
that might be needed.

### Protect unsaved buffers

Before processing a path, check whether it already has a visiting buffer. If
that buffer is modified, do not edit or save it.

```elisp
(let ((buffer (find-buffer-visiting file)))
  (when (and buffer (buffer-modified-p buffer))
    ;; Skip and record the reason.
    ))
```

Report the file as skipped so the user can review or save it and rerun cleanup.
Never overwrite unsaved user work.

### Track buffer ownership

Record whether a buffer existed before cleanup:

```elisp
(let* ((existing-buffer (find-buffer-visiting file))
       (buffer (or existing-buffer (find-file-noselect file)))
       (opened-by-cleanup (null existing-buffer)))
  ...)
```

- Leave pre-existing buffers open.
- Kill only buffers opened by the cleanup command.
- Do not kill a cleanup-created buffer if saving failed or it remains modified.
- Use `unwind-protect` so ownership cleanup also runs after an error.

### Save normally

Use normal Emacs editing functions and `save-buffer`. This allows ordinary
backup behavior, save hooks, Vulpea synchronization, and conflict detection to
run.

Do not:

- write files directly with `write-region`;
- edit Vulpea's database instead of the source note;
- disable every save hook; or
- overwrite a file that changed on disk without resolving the conflict.

The Org file remains the source of truth. Vulpea should learn about the change
through its normal indexing path.

### Prevent recursion

Saving invokes `before-save-hook`, including automatic tag rules. Protect the
cleanup command from recursively starting itself:

```elisp
(defvar PACKAGE--cleanup-in-progress nil)

(unless PACKAGE--cleanup-in-progress
  (let ((PACKAGE--cleanup-in-progress t))
    ...))
```

Automatic tag synchronization should be idempotent: reevaluating a tag during
the save must produce the same final state.

Do not suppress unrelated hooks merely to avoid recursion.

### Process files independently

For each candidate:

1. Validate the path and buffer state.
2. Reevaluate timestamp relevance.
3. Edit only the owned tag.
4. Save the file.
5. Confirm success.
6. Record the result.
7. Continue to the next file.

One failure must not terminate the entire cleanup. Catch errors at the per-file
boundary and include them in the final report.

Use `atomic-change-group` around the in-buffer edit when practical so an error
before saving restores the buffer text. Once a file has been saved, recovery
depends on Emacs backups or version control.

### Validate path scope

Before visiting a candidate, verify that it is:

- a regular Org file;
- within the configured Vulpea notes directory;
- readable and writable;
- not a remote file unless remote operation is explicitly supported; and
- not unexpectedly redirected through a symbolic link.

Canonicalize paths before checking directory containment. Treat missing,
malformed, out-of-scope, or read-only paths as skipped rather than trying to
repair them automatically.

### Preserve supported agenda semantics

Define "stale" explicitly. A timestamp before today may still matter to:

- historical agenda commands;
- repeating timestamps;
- timestamp ranges; or
- custom agenda behavior.

`SCHEDULED` and `DEADLINE` timestamps are outside this cleanup command's scope.
They are handled by the separate TODO-tag workflow and must neither retain nor
lose the package-owned ordinary-timestamp tag. The cleanup predicate does not
inspect TODO states; the supported workflow assumes completed timestamped
entries use those excluded planning forms.

Safe defaults are:

- remove the tag only when the result is unambiguous;
- retain repeating and otherwise ambiguous ordinary timestamp entries;
- ignore `SCHEDULED` and `DEADLINE` timestamps when deciding whether the
  ordinary-timestamp tag is needed;
- document whether historical agenda discovery is supported; and
- prefer a false positive, which costs performance, over a false negative,
  which hides an agenda entry.

If the package deliberately optimizes only present and future agendas, the
preview must make that policy visible before removing tags required solely for
historical views.

### Confirm the operation

Before applying a nonempty cleanup plan, display the number of affected files
and request confirmation with `yes-or-no-p` or an equivalent explicit action in
the preview buffer.

The confirmation should identify the exact configured notes directory and tag.
An empty plan should exit without prompting.

### Produce an audit report

The preview and final result should categorize every candidate, for example:

```text
Changed:                    14
Unchanged:                  38
Skipped - unsaved buffer:    2
Skipped - read-only:         1
Skipped - ambiguous:         3
Failed:                      1
```

Each item should include:

- a link to the source file;
- its proposed or completed action;
- the reason for skipping or failure; and
- the error message when an operation failed.

Keep the preview data separate from application state. Revalidate each file
during application rather than trusting the preview snapshot.

## Suggested result states

Use explicit internal result states so reporting and tests do not depend on
human-readable strings:

```elisp
'changed
'unchanged
'skipped-modified
'skipped-read-only
'skipped-out-of-scope
'skipped-ambiguous
'failed
```

A result record should contain at least the canonical path, state, reason, and
original error object when applicable.

## Test requirements

ERT coverage should verify that cleanup:

- never changes files during preview;
- requires confirmation before applying changes;
- removes only the configured tag;
- revalidates after preview and before modification;
- skips buffers with unsaved changes;
- leaves pre-existing buffers alive;
- kills only clean buffers it opened itself;
- preserves a cleanup-created buffer after a save failure;
- continues after a per-file error;
- rejects paths outside the configured notes directory;
- handles missing and read-only files safely;
- prevents recursive cleanup;
- permits normal save hooks to run;
- retains ambiguous timestamp cases; and
- reports every changed, unchanged, skipped, and failed file.

Tests should use temporary directories, temporary Org files, and isolated
dynamic bindings. They must never operate on the user's real Vulpea directory
or database.
