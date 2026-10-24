;;; vulpea-agenda-timestamps-test.el --- Package tests -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'vulpea-agenda-timestamps)

(defconst vulpea-agenda-timestamps-test--today
  (encode-time 0 0 12 25 10 2026)
  "A fixed local time used by date-sensitive tests.")

(defun vulpea-agenda-timestamps-test--relevant-p (contents)
  "Return the timestamp relevance of Org CONTENTS on the test date."
  (with-temp-buffer
    (org-mode)
    (insert contents)
    (vulpea-agenda-timestamps-buffer-relevant-p
     vulpea-agenda-timestamps-test--today)))

(ert-deftest vulpea-agenda-timestamps-test-default-tag ()
  "The default candidate tag is `timestamp'."
  (should (equal vulpea-agenda-timestamps-tag "timestamp")))

(ert-deftest vulpea-agenda-timestamps-test-active-timestamp-today ()
  "An ordinary active timestamp today is relevant."
  (should (vulpea-agenda-timestamps-test--relevant-p
           "* Event\n  <2026-10-25 Sun>\n")))

(ert-deftest vulpea-agenda-timestamps-test-active-timestamp-in-future ()
  "An ordinary future active timestamp is relevant."
  (should (vulpea-agenda-timestamps-test--relevant-p
           "* Event\n  <2026-10-26 Mon 10:00>\n")))

(ert-deftest vulpea-agenda-timestamps-test-past-timestamp ()
  "An ordinary past timestamp is not relevant."
  (should-not (vulpea-agenda-timestamps-test--relevant-p
               "* Event\n  <2026-10-24 Sat>\n")))

(ert-deftest vulpea-agenda-timestamps-test-inactive-timestamp ()
  "An inactive timestamp is not relevant."
  (should-not (vulpea-agenda-timestamps-test--relevant-p
               "* Note\n  [2026-10-26 Mon]\n")))

(ert-deftest vulpea-agenda-timestamps-test-scheduled-timestamp ()
  "A SCHEDULED planning timestamp is outside the package scope."
  (should-not (vulpea-agenda-timestamps-test--relevant-p
               "* TODO Task\n  SCHEDULED: <2026-10-26 Mon>\n")))

(ert-deftest vulpea-agenda-timestamps-test-deadline-timestamp ()
  "A DEADLINE planning timestamp is outside the package scope."
  (should-not (vulpea-agenda-timestamps-test--relevant-p
               "* TODO Task\n  DEADLINE: <2026-10-26 Mon>\n")))

(ert-deftest vulpea-agenda-timestamps-test-active-range ()
  "A range remains relevant through its ending date."
  (should (vulpea-agenda-timestamps-test--relevant-p
           "* Event\n  <2026-10-20 Tue>--<2026-10-25 Sun>\n")))

(ert-deftest vulpea-agenda-timestamps-test-expired-active-range ()
  "A range ending before today is not relevant."
  (should-not (vulpea-agenda-timestamps-test--relevant-p
               "* Event\n  <2026-10-20 Tue>--<2026-10-24 Sat>\n")))

(ert-deftest vulpea-agenda-timestamps-test-past-repeater ()
  "A repeating active timestamp remains conservatively relevant."
  (should (vulpea-agenda-timestamps-test--relevant-p
           "* Event\n  <2026-10-18 Sun +1w>\n")))

(ert-deftest vulpea-agenda-timestamps-test-todo-state-ignored ()
  "TODO state does not affect an ordinary timestamp."
  (should (vulpea-agenda-timestamps-test--relevant-p
           "* DONE Event\n  <2026-10-26 Mon>\n")))

(ert-deftest vulpea-agenda-timestamps-test-any-relevant-timestamp ()
  "A file is relevant when at least one ordinary timestamp qualifies."
  (should (vulpea-agenda-timestamps-test--relevant-p
           (concat "* Old\n  <2026-10-20 Tue>\n"
                   "* Future\n  <2026-11-01 Sun>\n"))))

(ert-deftest vulpea-agenda-timestamps-test-auto-tag-rule-adds-tag ()
  "The automatic tagging rule adds the tag for a relevant buffer."
  (cl-letf (((symbol-function
              'vulpea-agenda-timestamps-buffer-relevant-p)
             (lambda (&optional _now) t)))
    (should (equal (vulpea-agenda-timestamps-auto-tag-rule)
                   '(("timestamp") . nil)))))

(ert-deftest vulpea-agenda-timestamps-test-auto-tag-rule-removes-tag ()
  "The automatic tagging rule removes the tag for an irrelevant buffer."
  (cl-letf (((symbol-function
              'vulpea-agenda-timestamps-buffer-relevant-p)
             (lambda (&optional _now) nil)))
    (should (equal (vulpea-agenda-timestamps-auto-tag-rule)
                   '(nil . ("timestamp"))))))

(ert-deftest vulpea-agenda-timestamps-test-auto-tag-rule-custom-tag ()
  "The automatic tagging rule respects the configured tag name."
  (let ((vulpea-agenda-timestamps-tag "calendar"))
    (cl-letf (((symbol-function
                'vulpea-agenda-timestamps-buffer-relevant-p)
               (lambda (&optional _now) t)))
      (should (equal (vulpea-agenda-timestamps-auto-tag-rule)
                     '(("calendar") . nil))))))

(provide 'vulpea-agenda-timestamps-test)

;;; vulpea-agenda-timestamps-test.el ends here
