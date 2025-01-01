(defsystem "password"
  :homepage "https://github.com/lpd3/password"
  :version "0.1.0"
  :mailto "lpd3@github.com"
  :serial t
  :components ((:file "src/package")
	       (:file "src/password"))
  :description "Password generator. One of the rosettacode challenges. This version is written with the hopes that a stand-alone shell script can be generated."
  :author "Laurence Devlin")
