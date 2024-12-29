(in-package :cl-user)

(defpackage :password
  (:use :cl)
  (:import-from :ironclad
		:strong-random)
  (:import-from :uiop
	        :ensure-absolute-pathname
		:file-exists-p)
  (:import-from :adopt
		:make-option
		:collect
		:define-string
		:make-interface
		:parse-options-or-exit
		:print-help-and-exit
		:print-error-and-exit)
  (:shadowing-import-from :adopt
   :last)
  (:shadowing-import-from :adopt
   :exit)
  (:import-from :with-user-abort
   :with-user-abort
   :user-abort)
  (:export
   :toplevel
   *ui*))
