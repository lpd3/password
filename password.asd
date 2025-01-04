(defsystem "password"
  :name "password"
  :homepage "https://github.com/lpd3/password"
  :version "0.1.0"
  :license "MIT"
  :mailto "lpd3@github.com"
  :depends-on (:clingon :ironclad)
  :serial t
  :components ((:file "src/package")
	       (:file "src/password"))
  :description "Password generator. One of the rosettacode challenges. This version is written with the hopes that a stand-alone shell script can be generated."
  :author "Laurence Devlin"
  :build-operation "program-op"
  :build-pathname "./bin/password"
  :entry-point "password:main"
  :in-order-to ((test-op (test-op "password/test"))))

(defsystem password/tests
  :name "password/test"
  :depends-on (:password :clingon :fiveam :alexandria :serapeum)
  :serial t
  :components
  ((:file tests/package)
   (:file tests/tests))
  :perform (test-op (o s)
             (uiop:symbol-call :fiveam '#:run!
               (uiop:find-symbol* '#:password-test-suite
                                  :password-test))))
