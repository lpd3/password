(eval-when (:compile-toplevel
	    :load-toplevel
	    :execute)
  (dolist (s (list :uiop :with-user-abort :adopt :ironclad))
    (ql:quickload s)))

(defsystem "password"
  :homepage "https://github.com/lpd3/password"
  :version "0.1.0"
  :mailto "lpd3@github.com"
  :depends-on (:uiop
	       :with-user-abort
	       :adopt
	       :ironclad)
  :serial t
  :components ((:file "src/package")
	       (:file "src/password"))
;  :entry-point "password:toplevel"
;  :build-operation "program-op"
;  :build-pathname "bin/password"
  :description "Password generator. One of the rosettacode challenges. This version is written with the hopes that a stand-alone shell script can be generated."
  :author "Laurence Devlin")
