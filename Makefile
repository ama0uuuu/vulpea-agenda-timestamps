EMACS ?= emacs
ELISP := vulpea-agenda-timestamps.el

.PHONY: all test compile checkdoc clean

all: test compile

test:
	$(EMACS) -Q --batch -L . -L test -l test/run-tests.el

compile:
	$(EMACS) -Q --batch -L . --eval \
	  '(setq byte-compile-error-on-warn t)' \
	  -f batch-byte-compile $(ELISP)

checkdoc:
	$(EMACS) -Q --batch -L . --eval \
	  '(progn (require '\''checkdoc) (checkdoc-file "$(ELISP)"))'

clean:
	$(RM) *.elc test/*.elc
