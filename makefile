LISP=ecl
build:
	$(LISP) --eval '(asdf:load-system :password)' --eval '(ql:quickload :password)' --eval '(asdf:make :password)' --eval '(uiop:quit)'
