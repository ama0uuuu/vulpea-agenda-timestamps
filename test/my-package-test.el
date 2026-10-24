;;; my-package-test.el --- Tests for My Package -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Code:

(require 'ert)
(require 'my-package)

(ert-deftest my-package-test-option-default ()
  "The example option is enabled by default."
  (should my-package-option))

(provide 'my-package-test)

;;; my-package-test.el ends here
