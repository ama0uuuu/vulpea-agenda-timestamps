;;; my-package.el --- Short package description -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Your Name

;; Author: Your Name <you@example.com>
;; Maintainer: Your Name <you@example.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: convenience
;; URL: https://github.com/your-name/my-package
;; SPDX-License-Identifier: GPL-3.0-or-later

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Describe what the package does and give a minimal usage example here.

;;; Code:

(defgroup my-package nil
  "Customization group for My Package."
  :group 'convenience
  :prefix "my-package-")

(defcustom my-package-option t
  "Example user option."
  :type 'boolean
  :group 'my-package)

(defun my-package-command ()
  "Run an example interactive command."
  (interactive)
  (message "My Package is working"))

(provide 'my-package)

;;; my-package.el ends here
