;;; vulpea-agenda-timestamps.el --- Timestamp-based Vulpea agenda filtering -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Sunao Kaneko

;; Author: Sunao Kaneko <sunao.kaneko@protonmail.com>
;; Maintainer: Sunao Kaneko <sunao.kaneko@protonmail.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.2"))
;; Keywords: outlines, calendar
;; URL: https://github.com/ama0uuuu/vulpea-agenda-timestamps
;; SPDX-License-Identifier: GPL-3.0-or-later

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Reduce the number of Org files scanned for an agenda by using Vulpea's tag
;; index to discover notes containing relevant ordinary active timestamps.

;;; Code:

(require 'org)
(require 'org-element)

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

(defun vulpea-agenda-timestamps--timestamp-relevant-p (timestamp today-key)
  "Return non-nil when TIMESTAMP is relevant on or after TODAY-KEY.
TIMESTAMP must be an Org timestamp object.  TODAY-KEY is the sortable integer
format returned by `vulpea-agenda-timestamps--today-key'.  Repeating active
timestamps are retained regardless of their base date."
  (and (memq (org-element-property :type timestamp)
             '(active active-range))
       (or (org-element-property :repeater-type timestamp)
           (>= (vulpea-agenda-timestamps--timestamp-end-key timestamp)
               today-key))))

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

(defun vulpea-agenda-timestamps-version ()
  "Display the installed package version."
  (interactive)
  (message "vulpea-agenda-timestamps 0.1.0"))

(provide 'vulpea-agenda-timestamps)

;;; vulpea-agenda-timestamps.el ends here
