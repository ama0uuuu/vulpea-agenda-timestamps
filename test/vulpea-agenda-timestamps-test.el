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
  "The default managed tag is `timestamp'."
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

(ert-deftest vulpea-agenda-timestamps-test-set-buffer-tag-adds ()
  "Tag synchronization preserves existing tags while adding the candidate."
  (let ((tags '("todo")))
    (cl-letf (((symbol-function
                'vulpea-agenda-timestamps--buffer-file-tags)
               (lambda () tags))
              ((symbol-function
                'vulpea-agenda-timestamps--write-buffer-file-tags)
               (lambda (new-tags) (setq tags new-tags))))
      (should (vulpea-agenda-timestamps--set-buffer-tag t))
      (should (equal tags '("todo" "timestamp")))
      (should-not (vulpea-agenda-timestamps--set-buffer-tag t)))))

(ert-deftest vulpea-agenda-timestamps-test-set-buffer-tag-removes ()
  "Tag synchronization removes only the managed timestamp tag."
  (let ((tags '("todo" "timestamp" "project")))
    (cl-letf (((symbol-function
                'vulpea-agenda-timestamps--buffer-file-tags)
               (lambda () tags))
              ((symbol-function
                'vulpea-agenda-timestamps--write-buffer-file-tags)
               (lambda (new-tags) (setq tags new-tags))))
      (should (vulpea-agenda-timestamps--set-buffer-tag nil))
      (should (equal tags '("todo" "project")))
      (should-not (vulpea-agenda-timestamps--set-buffer-tag nil)))))

(ert-deftest vulpea-agenda-timestamps-test-synchronize-skips-unsaved-buffer ()
  "A required tag edit does not overwrite an unsaved visiting buffer."
  (let ((file (make-temp-file "vulpea-agenda-timestamps-" nil ".org"))
        buffer)
    (unwind-protect
        (progn
          (with-temp-file file (insert "* Event\n"))
          (setq buffer (find-file-noselect file))
          (with-current-buffer buffer
            (goto-char (point-max))
            (insert "Unsaved\n"))
          (cl-letf (((symbol-function
                      'vulpea-agenda-timestamps-buffer-relevant-p)
                     (lambda (&optional _now) t))
                    ((symbol-function
                      'vulpea-agenda-timestamps--buffer-file-tags)
                     (lambda () nil))
                    ((symbol-function
                      'vulpea-agenda-timestamps--set-buffer-tag)
                     (lambda (_present)
                       (ert-fail "Unsaved buffer must not be edited"))))
            (should (eq (vulpea-agenda-timestamps--synchronize-file file)
                        'skipped))))
      (when (buffer-live-p buffer)
        (with-current-buffer buffer (set-buffer-modified-p nil))
        (kill-buffer buffer))
      (delete-file file))))

(ert-deftest vulpea-agenda-timestamps-test-cleanup-never-adds-tag ()
  "Remove-only synchronization does not add a missing timestamp tag."
  (let ((file (make-temp-file "vulpea-agenda-timestamps-" nil ".org")))
    (unwind-protect
        (cl-letf (((symbol-function
                    'vulpea-agenda-timestamps-buffer-relevant-p)
                   (lambda (&optional _now) t))
                  ((symbol-function
                    'vulpea-agenda-timestamps--buffer-file-tags)
                   (lambda () nil))
                  ((symbol-function
                    'vulpea-agenda-timestamps--set-buffer-tag)
                   (lambda (_present)
                     (ert-fail "Cleanup must not add tags"))))
          (should (eq (vulpea-agenda-timestamps--synchronize-file file t)
                      'unchanged)))
      (delete-file file))))

(ert-deftest vulpea-agenda-timestamps-test-synchronize-saves-and-closes ()
  "A changed file is saved and a command-opened buffer is closed."
  (let ((file (make-temp-file "vulpea-agenda-timestamps-" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-file file (insert "* Event\n"))
          (cl-letf (((symbol-function
                      'vulpea-agenda-timestamps-buffer-relevant-p)
                     (lambda (&optional _now) t))
                    ((symbol-function
                      'vulpea-agenda-timestamps--buffer-file-tags)
                     (lambda () nil))
                    ((symbol-function
                      'vulpea-agenda-timestamps--set-buffer-tag)
                     (lambda (_present)
                       (goto-char (point-max))
                       (insert "changed\n")
                       t)))
            (should (eq (vulpea-agenda-timestamps--synchronize-file file)
                        'changed)))
          (should-not (find-buffer-visiting file))
          (with-temp-buffer
            (insert-file-contents file)
            (should (string-match-p "changed" (buffer-string)))))
      (when-let* ((buffer (find-buffer-visiting file)))
        (with-current-buffer buffer (set-buffer-modified-p nil))
        (kill-buffer buffer))
      (delete-file file))))

(ert-deftest vulpea-agenda-timestamps-test-maintenance-counts-outcomes ()
  "Maintenance reports changed, skipped, failed, and deduplicated paths."
  (cl-letf (((symbol-function
              'vulpea-agenda-timestamps--synchronize-file)
             (lambda (path &optional _remove-only)
               (pcase path
                 ("changed.org" 'changed)
                 ("skipped.org" 'skipped)
                 (_ (error "broken")))))
            ((symbol-function 'display-warning) #'ignore)
            ((symbol-function 'message) #'ignore))
    (should (equal
             (vulpea-agenda-timestamps--run-maintenance
              '("changed.org" "changed.org" "skipped.org" "failed.org")
              "test")
             '(:processed 3 :changed 1 :skipped 1 :failed 1)))))

(ert-deftest vulpea-agenda-timestamps-test-reindex-uses-all-paths ()
  "Reindex synchronizes every unique indexed note path."
  (cl-letf (((symbol-function 'vulpea-agenda-timestamps--all-note-paths)
             (lambda () '("one.org" "two.org")))
            ((symbol-function 'vulpea-agenda-timestamps--run-maintenance)
             (lambda (paths operation &optional remove-only)
               (list paths operation remove-only))))
    (should (equal (vulpea-agenda-timestamps-reindex)
                   '(("one.org" "two.org") "reindex" nil)))))

(ert-deftest vulpea-agenda-timestamps-test-cleanup-uses-tagged-paths ()
  "Cleanup examines timestamp candidates in remove-only mode."
  (cl-letf (((symbol-function 'vulpea-agenda-timestamps--tagged-paths)
             (lambda (tags)
               (should (equal tags '("timestamp")))
               '("candidate.org")))
            ((symbol-function 'vulpea-agenda-timestamps--run-maintenance)
             (lambda (paths operation &optional remove-only)
               (list paths operation remove-only))))
    (should (equal (vulpea-agenda-timestamps-cleanup-stale-tags)
                   '(("candidate.org") "cleanup" t)))))

(provide 'vulpea-agenda-timestamps-test)

;;; vulpea-agenda-timestamps-test.el ends here
