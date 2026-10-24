;;; vulpea-agenda-timestamps.el --- Timestamp-based Vulpea agenda filtering -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Your Name

;; Author: Your Name <you@example.com>
;; Maintainer: Your Name <you@example.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: convenience
;; URL: https://github.com/your-name/vulpea-agenda-timestamps
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
