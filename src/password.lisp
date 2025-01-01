;;;; password.lisp: solution to the Password Generator task.

(in-package :password)

;; Program constant

(defvar *version*
  "0.1.0"
  "Version number of this
  program.")

;; Configuration parameters

(defparameter *pwd-count*
  1
  "The number of passwords to
   create")

(defparameter *pwd-length*
  8
  "The length, in characters,
   of each password.")

(defparameter *force-p*
  nil
  "Should already-existing files
   be overwritten?")

(defparameter *avoid-confusing-p*
  nil
  "Should visually ambiguous characters
   be avoided during password construction?")

;; Character-class parameters

(defparameter *lowercase*
  "abcdefghijklmnopqrstuvwxyz"
  "The lowercase letters.")

(defparameter *uppercase*
  "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  "The uppercase letters.")

(defparameter *digit*
  "0123456789"
  "The decimal digits")

(defparameter *special*
  (make-array 29
             :element-type 'base-char
	     :initial-contents
	      (list #\! #\" #\# #\%
	       #\& #\' #\( #\)
	       #\* #\+ #\, #\-
	       #\. #\/ #\: #\;
	       #\< #\= #\> #\?
	       #\@ #\[ #\] #\^
	       #\_ #\{ #\| #\}
	       #\~ ))
  "The special characters specified
   by the task. Defined via the 
   `defarray` macro simply to 
   increase readability of the 
   collection of characters. The
   end result is the same: a base-string.")

(defparameter *confusing*
  (make-array 6
    :element-type 'base-char
    :initial-contents
     (list #\1 #\l #\I
      #\0 #\O #\o))
  "Characters in the collection
   that may easily be visually
   confused with each other.")

;; User errors. We want code-based errors to
;; crash the program, as usual. Errors that
;; result from user mishandling of the utility
;; should simply print an error message and
;; return the user to the main shell process.

(define-condition user-error (error) ()
  (:documentation
   "Parent error type for all errors
   signaled as a result of user misuse
   of the program."))

(define-condition no-length-specified (user-error) ()
  (:report
   "-l/--length requires a length (integer), but none was specified."
   :documentation
   "Error signaled when the user supplies the -l or --length option 
    without an associated length."))

(define-condition unintelligle-length (user-error)
  ((arg
    :accessor unintelligible-length-arg
    :initarg :arg
    :type t))
  (:report
   (lambda (condition stream)
     (let ((arg (unintelligible-length-arg condition)))
       (format stream
	 "Unintelligible length: ~S (~A)"
	 arg (type-of arg))))))

(define-condition length-out-of-range (user-error)
  ((arg
    :accessor length-out-of-range-arg
    :initarg :arg
    :type integer))
  (:report
    (lambda (condition stream)
      (format stream
	 "Password length must be between 4 and 255 inclusive, not ~D"
	 (length-out-of-range-arg condition)))))

(define-condition no-file-specified (user-error) ()
  (:report
   "The -f/--files option requires one or more filenames (strings), but none were specified"))

(define-condition no-count-specified (user-error) ()
  (:report
   "The -c/--count option requires an integer argument, but none was supplied."))

(define-condition unintelligible-count (user-error)
  ((arg
    :accessor unintelligible-count-arg
    :initarg :arg
    :type t))
  (:report
    (lambda (condition stream)
       (let ((arg (unintelligible-count-arg condition)))
	 (format stream
	   "Unknown count: ~S (~A)"
	   arg (type-of arg))))))

(define-condition zero-count (user-error) ()
  (:report
   "A count of 0 is not permitted."))

(define-condition file-exists (user-error)
  ((path
    :accessor file-exists-path
    :initarg :path
    :type string))
  (:report
    (lambda (condition stream)
       (let ((path (file-exists-path condition)))
	 (format stream
	   "File ~A exists"
	   (ensure-absolute-pathname
	    path))))))

;; Program functionality.
;; `run` is the entry-point to the core
;; functionality of the program. 

(defun main (files)
  "Entry point of core functionality.
   Takes a list of strings, either
   pathnames or a hyphen. Generates passwords
   as specified by global parameters and writes them
   to the specified file or to stdout if a 
   hyphen is found."
  (let ((pwds (password)))
    (dolist (f files)
      (cond
	((string= f "-")
	 (dolist (p pwds)
	   (format t "~&~A~%" p)))
	(t
	 (when
	     (and
	      (file-exists-p f)
	      (not *force-p*))
	   (error
	    (make-condition 'file-exists :path f)))
         (with-open-file (fp f
			  :direction :output
			  :if-exists :overwrite
			  :if-does-not-exist :create)
	   (dolist (p pwds)
	     (format fp "~&~A~%" p)))))))
  (values))

(defun password ()
  "Generates a list of passwords according to
   global parameters"
  (loop for _ from 0 below *pwd-count*
	for pwd = (gen-password)
	collect pwd))

(defun gen-password ()
  "Generate a single password according to
   global variables"
  (let ((pwd (init-pwd)))
    (when (> *pwd-length* 4)
      (loop for i from 4 below *pwd-length*
	    do
	    (setf (char pwd i)
	          (rand-char))))
    (shuffle pwd)))

(defun init-pwd ()
  "Create a new base-string of length `length`,
   and whose first four elements are characters
   randomly selected from each of the four 
   character classes and the rest set to
   a space character. If `avoid-confusing-p`
   is non-nil, visually ambivalent characters
   will be excluded from the first 4 positions.
   Returns the initialized password. Uses
   global parameters"
  (let ((pwd (make-array
	      *pwd-length*
              :element-type 'base-char
	      :initial-element #\Space)))
    (setf
     (char pwd 0) (rand-char :upper)
     (char pwd 1) (rand-char :lower)
     (char pwd 2) (rand-char :digit)
     (char pwd 3) (rand-char :punc))
    pwd))

(defun rand-char (&optional class)
  "Generates and returns a random graphic
   ASCII character and returns 
   The optional arg `class`
   can be used to specify a particular 
   character class. Permitted values are
   :upper (uppercase letter), :lower 
   (lowercase letter), :digit (decimal digit)
   :punc (punctuation/special character)
   or nil (the default), in which case the
   character will be randomly chosen from
   the classes."
  (let* ((class
	   (if class
	       class
	       (random-aref #(:upper :lower :digit :punc))))
	 (chars
	   (ecase class
	     (:upper *uppercase*)
	     (:lower *lowercase*)
	     (:digit *digit*)
	     (:punc *special*)))
	 (char (random-aref chars)))
    (loop while (and *avoid-confusing-p*
		     (find char *confusing*))
	  do (setf char (random-aref chars))
	  finally
	  (return-from rand-char char))))

(defun random-aref (array)
  "Given an array, returns a random element.
   Randomization is strong."
  (let ((index (strong-random (length array))))
    (aref array index)))

(defun shuffle (array)
  "Given an array, return the array 
   shuffled in a random order. 
   Destroys original array. Randomization
   is strong."
  (dotimes (i (length array) array)
    (let ((j (strong-random (length array))))
      (rotatef (aref array i) (aref array j)))))

;;; User interface
