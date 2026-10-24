;;; run-tests.el --- Batch test runner -*- lexical-binding: t; -*-

;;; Commentary:

;; Run from the repository root with:
;;
;;   emacs -Q --batch -L . -L test -l test/run-tests.el

;;; Code:

(require 'ert)

(let ((test-directory
       (file-name-directory (or load-file-name buffer-file-name))))
  (dolist (file (directory-files test-directory t "-test\\.el\\'"))
    (load file nil nil)))

(ert-run-tests-batch-and-exit)

;;; run-tests.el ends here
