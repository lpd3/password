;;;; password.lisp: solution to the Password Generator task.


;; Gather dependencies.

(in-package :password)

;; Program constant

(defconstant +version+
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
	     '(#\! #\" #\# #\%
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
    '(#\1 #\l #\I
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
    :accessor arg
    :initarg :arg
    :type t))
  (:report
   #'(lambda (condition stream)
       (let ((arg (arg condition)))
	 (format stream
		 "Unintelligible length: ~S (~A)"
		 arg (type-of arg))
	 :documentation
	 "Error signated when the wrong data type
    is used as an argument for the -l/--length 
    option."))))

(define-condition length-out-of-range (user-error)
  ((arg
    :accessor arg
    :initarg :arg
    :type integer))
  (:report
   #'(lambda (condition stream)
       (format stream
	 "Password length must be between 4 and 255 inclusive, not ~D"
	 (arg condition)))
   :documentation
   "Error signaled when user supplies a password length less than 4 or
    more than 255"))

(define-condition no-file-specified (user-error) ()
  (:report
   "The -f/--files option requires one or more filenames (strings), but none were specified"
   :documentation
   "Error signaled when the user specifies the -f or --files option, 
    but no filenames are supplied."))

(define-condition no-count-specified (user-error) ()
  (:report
   "The -c/--count option requires an integer argument, but none was supplied."
   :documentation
   "Error signaled when the user specifies the -c or --count option,
    but no count was specified."))

(define-condition unintelligible-count (user-error)
  ((arg
    :accessor arg
    :initarg :arg
    :type t))
  (:report
   #'(lambda (condition stream)
       (let ((arg (arg condition)))
	 (format stream
	   "Unknown count: ~S (~A)"
	   arg (type-of arg))))
   :documentation
   "Error signaled when the user supplies
    the wrong type for the -c/--count
    option."))

(define-condition zero-count (user-error) ()
  (:report
   "A count of 0 is not permitted."
   :documentation
   "Error signaled when the user supplies 0
    for the -c/--count option"))

(define-condition file-exists (user-error)
  ((path
    :accessor path
    :initarg :path
    :type string))
  (:report
   #'(lambda (condition stream)
       (let ((path (path condition)))
	 (format stream
	   "File ~A exists"
	   (ensure-absolute-pathname
	    path))))
   :documentation
   "Error signaled when the -f/--file
    option is used and the -F/--force 
    option is not used and the supplied
    pathname points to a file that 
    already exists."))

;; Program functionality.
;; `run` is the entry-point to the core
;; functionality of the program. 

(defun run (files)
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

(defparameter *option-help*
  (make-option 'help
    :help "Display the help message and exit."
    :long "help"
    :short #\h
    :reduce (constantly t))
  "The -h/--help option.")

(defparameter *option-version*
  (make-option 'version
    :help "Show version info and quit."
    :long "version"
    :short #\v
    :reduce (constantly t)))

(defparameter *option-count*
  (make-option 'count
    :parameter "COUNT: POSITIVE INTEGER"
    :help "Specify the number of passwords
           to generate (default: 1)"
    :long "count"
    :short #\c
    :reduce #'last))

(defparameter *option-length*
  (make-option 'length
    :parameter "LENGTH: INTEGER n, 4 <= n <= 255"
    :help "Specify a length in characters for the 
password, which must be between 4 ane 255. 
(default 8)"
    :parameter "INTEGER"
    :long "length"
    :short #\l
    :reduce #'last))

(defparameter *option-files*
  (make-option 'files
		     :parameter "FILES: STRING..."
		     :help "Save password(s) to one or more files
(a hyphen sends the passwords to stdout). If one or more files already exists, fails with an 
with an error message. To overwrite files, invoke 
invoke this utility with both -f/--file and -F/--force."
		     :long "file"
		     :short #\f
		     :initial-value (list )
		     :reduce #'collect))

(defparameter *option-force*
  (make-option 'force
		     :help "Only meaningful when used with -f/--file. 
If one or more files already exists, overwrite them."
		     :long "force"
		     :short #\F
                     :reduce (constantly t)))

(defparameter *option-avoid-confusing*
  (make-option 'avoid-confusing
		     :help "Do not use the numeral one, 
lowercase L, uppercase i, the numeral
zero, uppercase o, or lowercase o in the
password."
		     :long "avoid-confusing"
		     :short #\C
		     :reduce (constantly t)))

(define-string *help-string*
    "This utility generates one or more strong passwords
     and prints all of them to stdout or places all of them
     in one or more files. Passwords will 
     contain at least one of each of 
     1. uppercase letters 2. lowercase letters
     3. decimal digits 4. special characters.
     All characters are graphic ASCII 
     characters.~@
     ~@
     If no options or arguments are supplied, a single 
     password consisting of 8 characters is printed to
     stdout. Options allow specifying the length of the
     password(s), the number of passwords generated,
     one or more files to which the passwords will be 
     written and avoiding ambiguous characters in 
     the passwords.")

;;; Toplevel interface

(defmacro exit-on-ctrl-c (&body body)
  "Helper macro to enable the utility
   to exit gracefully when the user
   types CTRL-c"
  `(handler-case (with-user-abort (progn ,@body))
     (user-abort () (exit 130))))

(defun configure (options)
  (let ((count (gethash 'count options))
	(length (gethash 'length options))
	(files (gethash 'files options)))
    (when count
      (cond
	((eq count t)
	 (error 'no-count-specified))
	((notevery #'digit-char-p count)
	 (error 'unintelligible-count :arg (second count)))
	(t
	 (let ((number (parse-integer count)))
	   (if (zerop number)
	       (error 'zero-count)
	       (setf *pwd-count* number))))))
    (when length
      (cond
	((eq length t)
	 (error 'no-length-specified))
	((notevery #'digit-char-p length)
	 (error 'unintelligible-length :arg (second length)))
        (t
	 (let ((number (parse-integer length)))
	   (if (or (< number 4) (> number 255))
	       (error 'length-out-of-range :arg number)
	       (setf *pwd-length* number))))))
    (when files
      (when (eq files t)
	    (error 'no-files-specified)))
    (when (gethash 'force options)
      (setf *force-p* t))
    (when (gethash 'avoid-confusing options)
      (setf *avoid-confusing-p* t))))

(defparameter *ui*
  (make-interface
   :name "password"
   :usage "[OPTIONS] [FILE...]"
   :summary "Generate one or more random passwords
             and print them to stdout and/or to 
             one or more files"
   :help *help-string*
   :contents
   (list
    *option-help*
    *option-version*
    *option-files*
    *option-force*
    *option-avoid-confusing*
    *option-length*)))

(defun toplevel ()
  ;; missing code to
  ;; turn off the debugger
  ;; I don't know how to do
  ;; that in ECL
  (exit-on-ctrl-c
   (multiple-value-bind
	 (arguments options)
         (parse-options-or-exit *ui*)
     (declare (ignore arguments))
     (handler-case
	 (cond
	   ((gethash 'help options)
	    (print-help-and-exit *ui*))
	   ((gethash 'version options)
	    (format t "password version ~A" +version+)
	    (exit))
	   (t
	    (configure options)
	    (let ((files (gethash 'files options)))
	      (if files
		  (run files)
		  (run (list "-"))))))
       (user-error (e)
	 (print-error-and-exit e))))))








  