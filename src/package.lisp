(in-package :cl-user)

(defpackage :password
  (:use :cl)
  (:import-from :ironclad
                :strong-random)
  (:import-from :clingon)
  (:export :main))
