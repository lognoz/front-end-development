# See LICENSE file for copyright and license details.

EMACS?= emacs
BATCH= $(EMACS) -Q --batch $(LOAD)
LOAD= -L .

FILES= $(wildcard front-end-development*.el)
ELCFILES= $(FILES:.el=.elc)

$(ELCFILES): %.elc: %.el
	@$(BATCH) -f batch-byte-compile $<

all: checkdoc compile test autoload clean

compile: $(ELCFILES)

autoload:
	@for f in $(FILES); do\
		$(BATCH) --eval "(progn\
		(let ((generated-autoload-file (expand-file-name \"autoload.el\")))\
			(update-file-autoloads \""$${f}\"" t generated-autoload-file)))";\
	done

checkdoc:
	@for f in $(FILES); do\
		$(BATCH) --eval "(checkdoc-file \""$${f}\"")";\
	done

clean:
	@rm -f *~
	@rm -f \#*\#
	@rm -f *.elc
	@rm -f autoload.el

test:
	@if [ -d "test" ]; then \
		$(BATCH) --eval "(progn\
		(load \"test/front-end-development-test.el\" nil 'nomessage)\
		(ert-run-tests-batch-and-exit))"; \
	fi

version:
	@$(BATCH) --eval "(progn\
	(require 'front-end-development)\
	(front-end-development-version))"

.PHONY: all autoload checkdoc clean compile test version
