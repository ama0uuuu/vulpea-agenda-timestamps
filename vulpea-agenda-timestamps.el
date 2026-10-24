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

(defgroup vulpea-agenda-timestamps nil
  "Timestamp-based agenda file selection for Vulpea."
  :group 'org
  :prefix "vulpea-agenda-timestamps-")

(defcustom vulpea-agenda-timestamps-tag "timestamp"
  "Vulpea tag for notes containing relevant ordinary active timestamps."
  :type 'string
  :group 'vulpea-agenda-timestamps)

(defun vulpea-agenda-timestamps-version ()
  "Display the installed package version."
  (interactive)
  (message "vulpea-agenda-timestamps 0.1.0"))

(provide 'vulpea-agenda-timestamps)

;;; vulpea-agenda-timestamps.el ends here
