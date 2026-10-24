;;; vulpea-agenda-timestamps-test.el --- Package tests -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'org-agenda)
(require 'vulpea-agenda-timestamps)

(defvar vulpea-agenda-tags)

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

(defun vulpea-agenda-timestamps-test--relevant-in-range-p
    (contents start-key end-key)
  "Return whether CONTENTS overlaps START-KEY through END-KEY."
  (with-temp-buffer
    (org-mode)
    (insert contents)
    (vulpea-agenda-timestamps-buffer-relevant-in-range-p
     start-key end-key)))

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

(ert-deftest vulpea-agenda-timestamps-test-timestamp-inside-range ()
  "A timestamp inside the requested agenda interval is retained."
  (should (vulpea-agenda-timestamps-test--relevant-in-range-p
           "* Event\n  <2026-10-27 Tue>\n" 20261025 20261031)))

(ert-deftest vulpea-agenda-timestamps-test-timestamp-after-range ()
  "A timestamp after the requested agenda interval is excluded."
  (should-not (vulpea-agenda-timestamps-test--relevant-in-range-p
               "* Event\n  <2026-11-01 Sun>\n" 20261025 20261031)))

(ert-deftest vulpea-agenda-timestamps-test-range-overlaps-agenda ()
  "A timestamp range crossing an agenda boundary is retained."
  (should (vulpea-agenda-timestamps-test--relevant-in-range-p
           "* Event\n  <2026-10-20 Tue>--<2026-10-26 Mon>\n"
           20261025 20261031)))

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

(ert-deftest vulpea-agenda-timestamps-test-file-relevant-p ()
  "File relevance is evaluated from a temporary Org buffer."
  (let ((file (make-temp-file "vulpea-agenda-timestamps-" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-file file
            (insert "* Event\n  <2026-10-26 Mon>\n"))
          (should (vulpea-agenda-timestamps-file-relevant-p
                   file vulpea-agenda-timestamps-test--today)))
      (delete-file file))))

(ert-deftest vulpea-agenda-timestamps-test-file-relevant-p-visiting-buffer ()
  "File relevance observes unsaved changes in an existing buffer."
  (let ((file (make-temp-file "vulpea-agenda-timestamps-" nil ".org"))
        buffer)
    (unwind-protect
        (progn
          (with-temp-file file
            (insert "* Old\n  <2026-10-20 Tue>\n"))
          (setq buffer (find-file-noselect file))
          (with-current-buffer buffer
            (goto-char (point-max))
            (insert "* Future\n  <2026-10-26 Mon>\n"))
          (should (vulpea-agenda-timestamps-file-relevant-p
                   file vulpea-agenda-timestamps-test--today)))
      (when (buffer-live-p buffer)
        (with-current-buffer buffer
          (set-buffer-modified-p nil))
        (kill-buffer buffer))
      (delete-file file))))

(ert-deftest vulpea-agenda-timestamps-test-file-error-is-conservative ()
  "An unreadable candidate remains eligible instead of disappearing."
  (cl-letf (((symbol-function 'display-warning) #'ignore))
    (should (vulpea-agenda-timestamps-file-relevant-p
             "/definitely/missing/vulpea-note.org"
             vulpea-agenda-timestamps-test--today))))

(ert-deftest vulpea-agenda-timestamps-test-filter-removes-stale-candidate ()
  "A stale file carrying only the timestamp tag is removed."
  (let ((vulpea-agenda-tags '("todo" "timestamp")))
    (cl-letf (((symbol-function 'vulpea-agenda-timestamps--tagged-paths)
               (lambda (tags)
                 (if (equal tags '("timestamp")) '("stale.org") nil)))
              ((symbol-function
                'vulpea-agenda-timestamps-file-relevant-p)
               (lambda (_path &optional _now) nil)))
      (should (equal
               (vulpea-agenda-timestamps--filter-note-paths
                '("ordinary.org" "stale.org"))
               '("ordinary.org"))))))

(ert-deftest vulpea-agenda-timestamps-test-filter-keeps-relevant-candidate ()
  "A timestamp-tagged file with a relevant timestamp is retained."
  (let ((vulpea-agenda-tags '("todo" "timestamp")))
    (cl-letf (((symbol-function 'vulpea-agenda-timestamps--tagged-paths)
               (lambda (tags)
                 (if (equal tags '("timestamp")) '("event.org") nil)))
              ((symbol-function
                'vulpea-agenda-timestamps-file-relevant-p)
               (lambda (_path &optional _now) t)))
      (should (equal
               (vulpea-agenda-timestamps--filter-note-paths '("event.org"))
               '("event.org"))))))

(ert-deftest vulpea-agenda-timestamps-test-filter-keeps-other-tag ()
  "Another configured agenda tag protects a stale timestamp file."
  (let ((vulpea-agenda-tags '("todo" "timestamp")))
    (cl-letf (((symbol-function 'vulpea-agenda-timestamps--tagged-paths)
               (lambda (tags)
                 (cond ((equal tags '("timestamp")) '("task.org"))
                       ((equal tags '("todo")) '("task.org")))))
              ((symbol-function
                'vulpea-agenda-timestamps-file-relevant-p)
               (lambda (&rest _args)
                 (ert-fail "A protected path must not be inspected"))))
      (should (equal
               (vulpea-agenda-timestamps--filter-note-paths '("task.org"))
               '("task.org"))))))

(ert-deftest vulpea-agenda-timestamps-test-filter-disabled-by-tags ()
  "Filtering is a no-op when the timestamp tag is not configured."
  (let ((vulpea-agenda-tags '("todo")))
    (cl-letf (((symbol-function 'vulpea-agenda-timestamps--tagged-paths)
               (lambda (&rest _args)
                 (ert-fail "The database must not be queried"))))
      (should (equal
               (vulpea-agenda-timestamps--filter-note-paths '("task.org"))
               '("task.org"))))))

(ert-deftest vulpea-agenda-timestamps-test-filter-advice ()
  "The advice filters paths produced by the wrapped function."
  (cl-letf (((symbol-function
              'vulpea-agenda-timestamps--filter-note-paths)
             (lambda (paths) (cdr paths))))
    (should
     (equal
      (vulpea-agenda-timestamps--filter-note-paths-advice
       (lambda (&rest _args) '("drop.org" "keep.org")) 'ignored)
      '("keep.org")))))

(ert-deftest vulpea-agenda-timestamps-test-filter-uses-agenda-interval ()
  "Filtering passes the current agenda interval to file inspection."
  (let ((vulpea-agenda-tags '("timestamp"))
        (vulpea-agenda-timestamps--agenda-interval
         '(20261025 . 20261031)))
    (cl-letf (((symbol-function 'vulpea-agenda-timestamps--tagged-paths)
               (lambda (_tags) '("event.org")))
              ((symbol-function
                'vulpea-agenda-timestamps-file-relevant-in-range-p)
               (lambda (path start-key end-key)
                 (should (equal path "event.org"))
                 (should (= start-key 20261025))
                 (should (= end-key 20261031))
                 t)))
      (should (equal
               (vulpea-agenda-timestamps--filter-note-paths '("event.org"))
               '("event.org"))))))

(ert-deftest vulpea-agenda-timestamps-test-agenda-run-cache ()
  "Repeated filtering in one agenda run reuses queries and parsing."
  (let ((vulpea-agenda-tags '("timestamp"))
        (vulpea-agenda-timestamps--agenda-interval
         '(20261025 . 20261031))
        (vulpea-agenda-timestamps--agenda-cache
         (make-hash-table :test #'equal))
        (query-count 0)
        (inspection-count 0))
    (cl-letf (((symbol-function 'vulpea-db-query-by-tags-some)
               (lambda (_tags)
                 (cl-incf query-count)
                 '(note)))
              ((symbol-function 'require)
               (lambda (&rest _args) t))
              ((symbol-function 'vulpea-note-path)
               (lambda (_note) "event.org"))
              ((symbol-function
                'vulpea-agenda-timestamps-file-relevant-in-range-p)
               (lambda (&rest _args)
                 (cl-incf inspection-count)
                 t)))
      (dotimes (_ 2)
        (should (equal
                 (vulpea-agenda-timestamps--filter-note-paths '("event.org"))
                 '("event.org"))))
      (should (= query-count 1))
      (should (= inspection-count 1)))))

(ert-deftest vulpea-agenda-timestamps-test-agenda-list-interval ()
  "Agenda arguments produce an inclusive calendar-date interval."
  (let ((org-agenda-overriding-arguments nil)
        (org-agenda-start-day nil)
        (org-agenda-start-on-weekday nil))
    (should (equal
             (vulpea-agenda-timestamps--agenda-list-interval
              nil "2026-10-25" 7)
             '(20261025 . 20261031)))))

(ert-deftest vulpea-agenda-timestamps-test-agenda-list-advice-binds-state ()
  "Agenda advice binds its interval and cache for the wrapped call."
  (let ((org-agenda-overriding-arguments nil)
        (org-agenda-start-day nil)
        (org-agenda-start-on-weekday nil))
    (should
     (vulpea-agenda-timestamps--agenda-list-advice
      (lambda (&rest _args)
        (and (equal vulpea-agenda-timestamps--agenda-interval
                    '(20261025 . 20261031))
             (hash-table-p vulpea-agenda-timestamps--agenda-cache)))
      nil "2026-10-25" 7 nil))))

(provide 'vulpea-agenda-timestamps-test)

;;; vulpea-agenda-timestamps-test.el ends here
