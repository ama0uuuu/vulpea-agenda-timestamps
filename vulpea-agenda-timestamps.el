;;; vulpea-agenda-timestamps.el --- Timestamp tags for Vulpea notes -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Sunao Kaneko

;; Author: Sunao Kaneko <sunao.kaneko@protonmail.com>
;; Maintainer: Sunao Kaneko <sunao.kaneko@protonmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.2") (vulpea "2.5.0")
;;                    (vulpea-auto-tag "0.1"))
;; Keywords: outlines, calendar
;; URL: https://github.com/ama0uuuu/vulpea-agenda-timestamps
;; SPDX-License-Identifier: GPL-3.0-or-later

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Maintain a Vulpea file tag for notes containing relevant ordinary active
;; timestamps, with explicit reindex and stale-tag cleanup commands.

;;; Code:

(require 'org)
(require 'org-element)
(require 'seq)
(require 'subr-x)

(declare-function vulpea-db-query-by-tags-some "vulpea-db-query" (tags))
(declare-function vulpea-db-query "vulpea-db-query" (&optional predicate))
(declare-function vulpea-buffer-prop-get-all "vulpea-buffer" (name))
(declare-function vulpea-buffer-prop-remove-all "vulpea-buffer" (name))
(declare-function vulpea-buffer-prop-set "vulpea-buffer" (name value))
(declare-function vulpea-note-path "vulpea-note" (note))

(defvar vulpea-agenda-timestamps--maintenance-running nil
  "Non-nil while a reindex or cleanup command is processing files.")

(defgroup vulpea-agenda-timestamps nil
  "Timestamp tag maintenance for Vulpea notes."
  :group 'org
  :prefix "vulpea-agenda-timestamps-")

(defcustom vulpea-agenda-timestamps-tag "timestamp"
  "Vulpea tag for notes containing relevant ordinary active timestamps."
  :type 'string
  :group 'vulpea-agenda-timestamps)

(defun vulpea-agenda-timestamps--date-key (year month day)
  "Return a sortable integer date key for YEAR, MONTH, and DAY."
  (+ (* year 10000) (* month 100) day))

(defun vulpea-agenda-timestamps--today-key (&optional now)
  "Return the local calendar-date key for NOW.
NOW has the same representation accepted by `decode-time' and defaults to the
current time."
  (let ((decoded (decode-time now)))
    (vulpea-agenda-timestamps--date-key
     (nth 5 decoded) (nth 4 decoded) (nth 3 decoded))))

(defun vulpea-agenda-timestamps--timestamp-end-key (timestamp)
  "Return TIMESTAMP's ending calendar-date key."
  (vulpea-agenda-timestamps--date-key
   (or (org-element-property :year-end timestamp)
       (org-element-property :year-start timestamp))
   (or (org-element-property :month-end timestamp)
       (org-element-property :month-start timestamp))
   (or (org-element-property :day-end timestamp)
       (org-element-property :day-start timestamp))))

(defun vulpea-agenda-timestamps--timestamp-start-key (timestamp)
  "Return TIMESTAMP's starting calendar-date key."
  (vulpea-agenda-timestamps--date-key
   (org-element-property :year-start timestamp)
   (org-element-property :month-start timestamp)
   (org-element-property :day-start timestamp)))

(defun vulpea-agenda-timestamps--timestamp-in-range-p
    (timestamp start-key end-key)
  "Return non-nil when TIMESTAMP overlaps START-KEY through END-KEY.
The bounds are inclusive sortable calendar-date keys.  Repeating active
timestamps are retained conservatively regardless of their base date."
  (and (memq (org-element-property :type timestamp)
             '(active active-range))
       (or (org-element-property :repeater-type timestamp)
           (and (<= (vulpea-agenda-timestamps--timestamp-start-key timestamp)
                    end-key)
                (>= (vulpea-agenda-timestamps--timestamp-end-key timestamp)
                    start-key)))))

(defun vulpea-agenda-timestamps--timestamp-relevant-p (timestamp today-key)
  "Return non-nil when TIMESTAMP is relevant on or after TODAY-KEY.
TIMESTAMP must be an Org timestamp object.  TODAY-KEY is the sortable integer
format returned by `vulpea-agenda-timestamps--today-key'.  Repeating active
timestamps are retained regardless of their base date."
  (vulpea-agenda-timestamps--timestamp-in-range-p
   timestamp today-key most-positive-fixnum))

(defun vulpea-agenda-timestamps-buffer-relevant-p (&optional now)
  "Return non-nil if the current Org buffer has a relevant timestamp.
Only ordinary active timestamps are considered.  Org represents `SCHEDULED'
and `DEADLINE' values as properties of planning elements, so they are not
visited as ordinary timestamp objects.  NOW defaults to the current time and
is available primarily for deterministic tests."
  (let ((today-key (vulpea-agenda-timestamps--today-key now)))
    (org-element-map (org-element-parse-buffer) 'timestamp
      (lambda (timestamp)
        (vulpea-agenda-timestamps--timestamp-relevant-p timestamp today-key))
      nil t)))

(defun vulpea-agenda-timestamps--tagged-paths (tags)
  "Return unique paths of Vulpea notes having any of TAGS."
  (when tags
    (require 'vulpea-db-query)
    (seq-uniq
     (mapcar #'vulpea-note-path
             (vulpea-db-query-by-tags-some tags)))))

(defun vulpea-agenda-timestamps--all-note-paths ()
  "Return unique paths for all notes currently indexed by Vulpea."
  (require 'vulpea-db-query)
  (seq-uniq (mapcar #'vulpea-note-path (vulpea-db-query nil))))

(defun vulpea-agenda-timestamps--buffer-file-tags ()
  "Return all file-level tags in the current buffer."
  (require 'vulpea-buffer)
  (seq-uniq
   (apply #'append
          (mapcar (lambda (value) (split-string value "[ :]" t))
                  (vulpea-buffer-prop-get-all "filetags")))))

(defun vulpea-agenda-timestamps--write-buffer-file-tags (tags)
  "Replace the current buffer's file-level tags with TAGS."
  (require 'vulpea-buffer)
  (vulpea-buffer-prop-remove-all "filetags")
  (when tags
    (vulpea-buffer-prop-set
     "filetags" (concat ":" (string-join (seq-uniq tags) ":") ":"))))

(defun vulpea-agenda-timestamps--set-buffer-tag (present)
  "Ensure the current file-level timestamp tag is PRESENT.
Return non-nil when the buffer was changed."
  (let* ((tag vulpea-agenda-timestamps-tag)
         (tags (vulpea-agenda-timestamps--buffer-file-tags))
         (has-tag (member tag tags)))
    (cond
     ((and present (not has-tag))
      (vulpea-agenda-timestamps--write-buffer-file-tags
       (append tags (list tag)))
      t)
     ((and (not present) has-tag)
      (vulpea-agenda-timestamps--write-buffer-file-tags
       (seq-remove (lambda (item) (string= item tag)) tags))
      t)
     (nil))))

(defun vulpea-agenda-timestamps--synchronize-file (path &optional remove-only)
  "Synchronize the timestamp tag in PATH and return its outcome.
The outcome is one of `changed', `unchanged', or `skipped'.  A required edit
is skipped when PATH already has unsaved changes.  Buffers opened here are
closed after success; buffers that were already open are left open.  When
REMOVE-ONLY is non-nil, remove a stale tag but never add a missing tag."
  (let* ((existing-buffer (find-buffer-visiting path))
         (buffer (or existing-buffer (find-file-noselect path)))
         (opened-here (not existing-buffer))
         outcome)
    (unwind-protect
        (with-current-buffer buffer
          (save-restriction
            (widen)
            (let* ((relevant (vulpea-agenda-timestamps-buffer-relevant-p))
                   (tagged
                    (member vulpea-agenda-timestamps-tag
                            (vulpea-agenda-timestamps--buffer-file-tags))))
              (setq outcome
                    (cond
                     ((and remove-only relevant) 'unchanged)
                     ((eq (not (null relevant)) (not (null tagged)))
                      'unchanged)
                     ((buffer-modified-p) 'skipped)
                     ((vulpea-agenda-timestamps--set-buffer-tag relevant)
                      (save-buffer)
                      'changed)
                     (t 'unchanged))))))
      (when (and opened-here
                 (buffer-live-p buffer)
                 (not (buffer-modified-p buffer)))
        (kill-buffer buffer)))
    outcome))

(defun vulpea-agenda-timestamps--run-maintenance
    (paths operation &optional remove-only)
  "Synchronize PATHS and report counts for OPERATION.
OPERATION is a short string used in the completion message.  Return a plist
containing `:processed', `:changed', `:skipped', and `:failed' counts.  Pass
REMOVE-ONLY through to `vulpea-agenda-timestamps--synchronize-file'."
  (if vulpea-agenda-timestamps--maintenance-running
      (user-error "Vulpea agenda timestamp maintenance is already running")
    (let ((vulpea-agenda-timestamps--maintenance-running t)
          (processed 0)
          (changed 0)
          (skipped 0)
          (failed 0))
      (dolist (path (seq-uniq paths))
        (setq processed (1+ processed))
        (condition-case error-data
            (pcase (vulpea-agenda-timestamps--synchronize-file
                    path remove-only)
              ('changed (setq changed (1+ changed)))
              ('skipped (setq skipped (1+ skipped))))
          (error
           (setq failed (1+ failed))
           (display-warning
            'vulpea-agenda-timestamps
            (format "Could not process %s: %s"
                    path (error-message-string error-data))))))
      (let ((result (list :processed processed :changed changed
                          :skipped skipped :failed failed)))
        (message "Vulpea timestamp %s: %d processed, %d changed, %d skipped, %d failed"
                 operation processed changed skipped failed)
        result))))

;;;###autoload
(defun vulpea-agenda-timestamps-reindex ()
  "Synchronize the timestamp tag across all indexed Vulpea files.
The command is safe to rerun.  It saves only files whose tag changes and skips
required edits in buffers with unsaved user changes."
  (interactive)
  (vulpea-agenda-timestamps--run-maintenance
   (vulpea-agenda-timestamps--all-note-paths) "reindex"))

;;;###autoload
(defun vulpea-agenda-timestamps-cleanup-stale-tags ()
  "Remove stale timestamp tags from indexed Vulpea files.
Only files currently carrying `vulpea-agenda-timestamps-tag' are inspected.
Relevant files and repeaters keep the tag.  The command saves only actual tag
changes and skips required edits in buffers with unsaved user changes."
  (interactive)
  (vulpea-agenda-timestamps--run-maintenance
   (vulpea-agenda-timestamps--tagged-paths
    (list vulpea-agenda-timestamps-tag))
   "cleanup" t))

;;;###autoload
(defun vulpea-agenda-timestamps-auto-tag-rule ()
  "Return tag changes suitable for `vulpea-auto-tag-rules'.
The return value is a cons cell whose car lists tags to add and whose cdr lists
tags to remove.  Add `vulpea-agenda-timestamps-tag' when the current buffer has
a relevant ordinary active timestamp; otherwise remove it."
  (if (vulpea-agenda-timestamps-buffer-relevant-p)
      (cons (list vulpea-agenda-timestamps-tag) nil)
    (cons nil (list vulpea-agenda-timestamps-tag))))

(defun vulpea-agenda-timestamps-version ()
  "Display the installed package version."
  (interactive)
  (message "vulpea-agenda-timestamps 0.1.0"))

(provide 'vulpea-agenda-timestamps)

;;; vulpea-agenda-timestamps.el ends here
