;;; vulpea-agenda-timestamps.el --- Timestamp-based Vulpea agenda filtering -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Sunao Kaneko

;; Author: Sunao Kaneko <sunao.kaneko@protonmail.com>
;; Maintainer: Sunao Kaneko <sunao.kaneko@protonmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.2") (vulpea "2.5.0")
;;                    (vulpea-agenda "0.1") (vulpea-auto-tag "0.1"))
;; Keywords: outlines, calendar
;; URL: https://github.com/ama0uuuu/vulpea-agenda-timestamps
;; SPDX-License-Identifier: GPL-3.0-or-later

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Reduce the number of Org files scanned for an agenda by using Vulpea's tag
;; index to discover notes containing relevant ordinary active timestamps.

;;; Code:

(require 'org)
(require 'org-agenda)
(require 'org-element)
(require 'seq)
(require 'subr-x)

(declare-function vulpea-db-query-by-tags-some "vulpea-db-query" (tags))
(declare-function vulpea-db-query "vulpea-db-query" (&optional predicate))
(declare-function vulpea-buffer-prop-get-all "vulpea-buffer" (name))
(declare-function vulpea-buffer-prop-remove-all "vulpea-buffer" (name))
(declare-function vulpea-buffer-prop-set "vulpea-buffer" (name value))
(declare-function vulpea-note-path "vulpea-note" (note))

(defvar vulpea-agenda-tags)

(defvar vulpea-agenda-timestamps--agenda-interval nil
  "Inclusive agenda interval as a cons of sortable date keys.")

(defvar vulpea-agenda-timestamps--agenda-cache nil
  "Memoization table dynamically bound during one agenda construction.")

(defvar vulpea-agenda-timestamps--maintenance-running nil
  "Non-nil while a reindex or cleanup command is processing files.")

(defgroup vulpea-agenda-timestamps nil
  "Timestamp-based agenda file selection for Vulpea."
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

(defun vulpea-agenda-timestamps-buffer-relevant-in-range-p
    (start-key end-key)
  "Return non-nil if an active timestamp overlaps START-KEY through END-KEY."
  (org-element-map (org-element-parse-buffer) 'timestamp
    (lambda (timestamp)
      (vulpea-agenda-timestamps--timestamp-in-range-p
       timestamp start-key end-key))
    nil t))

(defun vulpea-agenda-timestamps-buffer-relevant-p (&optional now)
  "Return non-nil if the current Org buffer has a relevant timestamp.
Only ordinary active timestamps are considered.  Org represents `SCHEDULED'
and `DEADLINE' values as properties of planning elements, so they are not
visited as ordinary timestamp objects.  NOW defaults to the current time and
is available primarily for deterministic tests."
  (vulpea-agenda-timestamps-buffer-relevant-in-range-p
   (vulpea-agenda-timestamps--today-key now) most-positive-fixnum))

(defun vulpea-agenda-timestamps--inspect-file (path predicate)
  "Call PREDICATE in PATH's current or temporary Org buffer."
  (let ((buffer (find-buffer-visiting path)))
    (if buffer
        (with-current-buffer buffer
          (save-restriction
            (widen)
            (funcall predicate)))
      (with-temp-buffer
        (insert-file-contents path)
        (delay-mode-hooks (org-mode))
        (funcall predicate)))))

(defun vulpea-agenda-timestamps-file-relevant-p (path &optional now)
  "Return non-nil when the Org file at PATH has a relevant timestamp.
Use the current contents of an existing visiting buffer.  Otherwise read PATH
into a temporary Org buffer without running mode hooks.  NOW is forwarded to
`vulpea-agenda-timestamps-buffer-relevant-p'.  Retain the file conservatively
and display a warning if it cannot be inspected."
  (condition-case error-data
      (vulpea-agenda-timestamps--inspect-file
       path (lambda () (vulpea-agenda-timestamps-buffer-relevant-p now)))
    (error
     (display-warning
      'vulpea-agenda-timestamps
      (format "Could not inspect %s; retaining it: %s"
              path (error-message-string error-data)))
     t)))

(defun vulpea-agenda-timestamps-file-relevant-in-range-p
    (path start-key end-key)
  "Return non-nil when PATH has a timestamp in START-KEY through END-KEY.
Retain PATH conservatively and display a warning if it cannot be inspected."
  (condition-case error-data
      (vulpea-agenda-timestamps--inspect-file
       path
       (lambda ()
         (vulpea-agenda-timestamps-buffer-relevant-in-range-p
          start-key end-key)))
    (error
     (display-warning
      'vulpea-agenda-timestamps
      (format "Could not inspect %s; retaining it: %s"
              path (error-message-string error-data)))
     t)))

(defun vulpea-agenda-timestamps--memoize (key function)
  "Return cached value for KEY, or call and cache FUNCTION.
Only cache when `vulpea-agenda-timestamps--agenda-cache' is dynamically bound
to a hash table."
  (if (not (hash-table-p vulpea-agenda-timestamps--agenda-cache))
      (funcall function)
    (let ((missing (make-symbol "missing")))
      (let ((value (gethash key vulpea-agenda-timestamps--agenda-cache missing)))
        (if (eq value missing)
            (let ((computed (funcall function)))
              (puthash key computed vulpea-agenda-timestamps--agenda-cache)
              computed)
          value)))))

(defun vulpea-agenda-timestamps--tagged-paths (tags)
  "Return unique paths of Vulpea notes having any of TAGS."
  (when tags
    (vulpea-agenda-timestamps--memoize
     (list 'tagged-paths tags)
     (lambda ()
       (require 'vulpea-db-query)
       (seq-uniq
        (mapcar #'vulpea-note-path
                (vulpea-db-query-by-tags-some tags)))))))

(defun vulpea-agenda-timestamps--other-agenda-tags ()
  "Return configured Vulpea agenda tags other than the timestamp tag."
  (seq-remove
   (lambda (tag) (string= tag vulpea-agenda-timestamps-tag))
   vulpea-agenda-tags))

(defun vulpea-agenda-timestamps--filter-note-paths (paths)
  "Filter stale timestamp-only files from Vulpea agenda PATHS.
Files carrying another tag from `vulpea-agenda-tags' are retained without
timestamp inspection.  PATHS not carrying the configured timestamp tag are
also retained."
  (if (not (member vulpea-agenda-timestamps-tag vulpea-agenda-tags))
      paths
    (let ((timestamp-paths
           (vulpea-agenda-timestamps--tagged-paths
            (list vulpea-agenda-timestamps-tag)))
          (other-paths
           (vulpea-agenda-timestamps--tagged-paths
            (vulpea-agenda-timestamps--other-agenda-tags))))
      (seq-filter
       (lambda (path)
         (or (not (member path timestamp-paths))
             (member path other-paths)
             (vulpea-agenda-timestamps--memoize
              (list 'file-relevant path
                    vulpea-agenda-timestamps--agenda-interval)
              (lambda ()
                (if vulpea-agenda-timestamps--agenda-interval
                    (vulpea-agenda-timestamps-file-relevant-in-range-p
                     path
                     (car vulpea-agenda-timestamps--agenda-interval)
                     (cdr vulpea-agenda-timestamps--agenda-interval))
                  (vulpea-agenda-timestamps-file-relevant-p path))))))
       paths))))

(defun vulpea-agenda-timestamps--absolute-day-key (absolute-day)
  "Convert Gregorian ABSOLUTE-DAY to a sortable calendar-date key."
  (pcase-let ((`(,month ,day ,year)
               (calendar-gregorian-from-absolute absolute-day)))
    (vulpea-agenda-timestamps--date-key year month day)))

(defun vulpea-agenda-timestamps--agenda-list-interval
    (arg start-day span)
  "Return the inclusive interval requested by agenda list arguments.
ARG, START-DAY, and SPAN follow `org-agenda-list'."
  (when org-agenda-overriding-arguments
    (setq arg (car org-agenda-overriding-arguments)
          start-day (nth 1 org-agenda-overriding-arguments)
          span (nth 2 org-agenda-overriding-arguments)))
  (when (and (integerp arg) (> arg 0))
    (setq span arg))
  (setq start-day (or start-day org-agenda-start-day))
  (when (stringp start-day)
    (setq start-day (time-to-days (org-read-date nil t start-day))))
  (let* ((span (org-agenda-ndays-to-span (or span org-agenda-span)))
         (start-day (or start-day (org-today)))
         (days (org-agenda-span-to-ndays span start-day))
         (weekday (and (memq days '(7 14)) org-agenda-start-on-weekday))
         (start (if (not weekday)
                    start-day
                  (let* ((actual (calendar-day-of-week
                                  (calendar-gregorian-from-absolute start-day)))
                         (difference (- actual weekday)))
                    (- start-day
                       (+ (if (< difference 0) 7 0) difference))))))
    (cons (vulpea-agenda-timestamps--absolute-day-key start)
          (vulpea-agenda-timestamps--absolute-day-key
           (+ start days -1)))))

(defun vulpea-agenda-timestamps--agenda-list-advice
    (original-function &optional arg start-day span with-hour)
  "Call ORIGINAL-FUNCTION with a run-local interval and cache.
ARG, START-DAY, SPAN, and WITH-HOUR are the arguments of `org-agenda-list'."
  (let ((vulpea-agenda-timestamps--agenda-interval
         (vulpea-agenda-timestamps--agenda-list-interval
          arg start-day span))
        (vulpea-agenda-timestamps--agenda-cache
         (make-hash-table :test #'equal)))
    (funcall original-function arg start-day span with-hour)))

(defun vulpea-agenda-timestamps--filter-note-paths-advice
    (original-function &rest args)
  "Filter paths returned by ORIGINAL-FUNCTION called with ARGS."
  (vulpea-agenda-timestamps--filter-note-paths
   (apply original-function args)))

;;;###autoload
(define-minor-mode vulpea-agenda-timestamps-mode
  "Filter stale timestamp-only notes from `vulpea-agenda' results."
  :global t
  :group 'vulpea-agenda-timestamps
  (if vulpea-agenda-timestamps-mode
      (progn
        (require 'vulpea-agenda)
        (advice-add 'vulpea-agenda--get-note-paths :around
                    #'vulpea-agenda-timestamps--filter-note-paths-advice)
        (advice-add 'org-agenda-list :around
                    #'vulpea-agenda-timestamps--agenda-list-advice))
    (advice-remove 'vulpea-agenda--get-note-paths
                   #'vulpea-agenda-timestamps--filter-note-paths-advice)
    (advice-remove 'org-agenda-list
                   #'vulpea-agenda-timestamps--agenda-list-advice)))

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
  "Ensure the current file-level candidate tag is PRESENT.
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
  "Synchronize the candidate tag in PATH and return its outcome.
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
  "Synchronize the timestamp candidate tag across all indexed Vulpea files.
The command is safe to rerun.  It saves only files whose tag changes and skips
required edits in buffers with unsaved user changes."
  (interactive)
  (vulpea-agenda-timestamps--run-maintenance
   (vulpea-agenda-timestamps--all-note-paths) "reindex"))

;;;###autoload
(defun vulpea-agenda-timestamps-cleanup-stale-tags ()
  "Remove stale timestamp candidate tags from indexed Vulpea files.
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
