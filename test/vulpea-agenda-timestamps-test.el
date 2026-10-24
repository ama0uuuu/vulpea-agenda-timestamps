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

(ert-deftest vulpea-agenda-timestamps-test-filter-uses-future-relevance ()
  "Filtering retains a file with timestamps beyond the displayed span."
  (let ((vulpea-agenda-tags '("timestamp")))
    (cl-letf (((symbol-function 'vulpea-agenda-timestamps--tagged-paths)
               (lambda (_tags) '("event.org")))
              ((symbol-function 'vulpea-agenda-timestamps-file-relevant-p)
               (lambda (path &optional _now)
                 (should (equal path "event.org"))
                 t)))
      (should (equal
               (vulpea-agenda-timestamps--filter-note-paths '("event.org"))
               '("event.org"))))))

(ert-deftest vulpea-agenda-timestamps-test-agenda-run-cache ()
  "Repeated filtering in one agenda run reuses queries and parsing."
  (let ((vulpea-agenda-tags '("timestamp"))
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
              ((symbol-function 'vulpea-agenda-timestamps-file-relevant-p)
               (lambda (&rest _args)
                 (cl-incf inspection-count)
                 t)))
      (dotimes (_ 2)
        (should (equal
                 (vulpea-agenda-timestamps--filter-note-paths '("event.org"))
                 '("event.org"))))
      (should (= query-count 1))
      (should (= inspection-count 1)))))

(ert-deftest vulpea-agenda-timestamps-test-agenda-list-advice-binds-state ()
  "Agenda advice binds its cache for the wrapped call."
  (should
   (vulpea-agenda-timestamps--agenda-list-advice
    (lambda (&rest _args)
      (hash-table-p vulpea-agenda-timestamps--agenda-cache))
    nil "2026-10-25" 7 nil)))

(ert-deftest vulpea-agenda-timestamps-test-profile-counts-filter-stages ()
  "Profiling counts candidates retained and eliminated by each stage."
  (let ((vulpea-agenda-tags '("todo" "timestamp"))
        (vulpea-agenda-timestamps--agenda-cache
         (make-hash-table :test #'equal))
        (vulpea-agenda-timestamps--profile-data (list :future-from 20261025)))
    (cl-letf (((symbol-function 'vulpea-agenda-timestamps--tagged-paths)
               (lambda (tags)
                 (if (equal tags '("timestamp"))
                     '("protected.org" "keep.org" "drop.org")
                   '("protected.org"))))
              ((symbol-function 'vulpea-agenda-timestamps-file-relevant-p)
               (lambda (path &rest _args) (equal path "keep.org"))))
      (should
       (equal
        (vulpea-agenda-timestamps--filter-note-paths
         '("ordinary.org" "protected.org" "keep.org" "drop.org"))
        '("ordinary.org" "protected.org" "keep.org")))
      (should (= (plist-get vulpea-agenda-timestamps--profile-data
                            :timestamp-candidates)
                 3))
      (should (= (plist-get vulpea-agenda-timestamps--profile-data
                            :protected-paths)
                 1))
      (should (= (plist-get vulpea-agenda-timestamps--profile-data
                            :parsed-files)
                 2))
      (should (= (plist-get vulpea-agenda-timestamps--profile-data
                            :relevant-paths)
                 1))
      (should (= (plist-get vulpea-agenda-timestamps--profile-data
                            :eliminated-paths)
                 1)))))

(ert-deftest vulpea-agenda-timestamps-test-profile-records-completed-agenda ()
  "Agenda advice publishes timing data after a profiled run."
  (let ((vulpea-agenda-timestamps-profiling-mode t)
        (vulpea-agenda-timestamps-last-profile nil)
        (org-agenda-overriding-arguments nil)
        (org-agenda-start-day nil)
        (org-agenda-start-on-weekday nil))
    (should
     (eq (vulpea-agenda-timestamps--agenda-list-advice
          (lambda (&rest _args)
            (vulpea-agenda-timestamps--profile-add :input-paths 2)
            'agenda-result)
          nil "2026-10-25" 7 nil)
         'agenda-result))
    (should (numberp
             (plist-get vulpea-agenda-timestamps-last-profile :future-from)))
    (should (= (plist-get vulpea-agenda-timestamps-last-profile :input-paths)
               2))
    (should (numberp
             (plist-get vulpea-agenda-timestamps-last-profile
                        :total-seconds)))))

(ert-deftest vulpea-agenda-timestamps-test-profile-report-format ()
  "Profile reports expose timings, counts, and a cleanup signal."
  (let ((report
         (vulpea-agenda-timestamps--format-profile
          '(:future-from 20261025
            :total-seconds 1.0 :query-seconds 0.1 :query-count 2
            :filter-seconds 0.2 :filter-calls 1 :parse-seconds 0.1
            :parsed-files 4 :input-paths 10 :timestamp-candidates 5
            :protected-paths 1 :inspected-paths 4 :relevant-paths 2
            :eliminated-paths 2 :output-paths 8))))
    (should (string-match-p "Relevance: today and future" report))
    (should-not (string-match-p "Interval:" report))
    (should (string-match-p "Eliminated candidates: 2 (40.0%)" report))
    (should (string-match-p "compare another profile" report))))

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
  "Tag synchronization removes only the candidate tag."
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
  "Remove-only synchronization does not add a missing candidate tag."
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
