;;; vulpea-agenda-timestamps-test.el --- Package tests -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Code:

(require 'ert)
(require 'vulpea-agenda-timestamps)

(ert-deftest vulpea-agenda-timestamps-test-default-tag ()
  "The default candidate tag is `timestamp'."
  (should (equal vulpea-agenda-timestamps-tag "timestamp")))

(provide 'vulpea-agenda-timestamps-test)

;;; vulpea-agenda-timestamps-test.el ends here
