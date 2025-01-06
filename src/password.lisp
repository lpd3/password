;;;; password.lisp: solution to the Password Generator task.

(in-package :password)
;;; user-interface

;; Errors. clingon provides appropriate errors when the wrong type of
;; arg is supplied or when no args are supplied when they should be,
;; or when an unknown option is invoked.
;; This leaves us with three errors we need to define:
;; 1. attempting to overwrite a file when -F has not been invoked.
;; 2. providing an out-of-range length (i.e. a length less than 4 or
;; greater than 255
;; 3. providing a count less than 1

(defvar *password-max-length*
  255
  "The maximum allowed length for a password")

(defvar *password-min-length*
  4
  "The minimum allowed length for a password.")

(defvar *password-max-count*
  (1- (* 1024 1024))
  "The maximum number of passwords that can be generated per invocation")

(defvar *password-min-count*
  1
  "The minimum number of passwords that can be generated per invocation")

(define-condition file-exists-error (clingon:base-error)
  ((file
    :initarg :file
    :reader file-exists-error-file))
  (:documentation
   "Error signaled when the -F/--force has not been invoked and an 
attempt is made to save a password to a file that already exists."))

(defmethod clingon:handle-error ((err file-exists-error))
  (let ((file (file-exists-error-file err)))
    (format *error-output*
      "File ~A already exists~%" file)))

(define-condition length-out-of-range-error (clingon:base-error)
  ()
  (:documentation
   "Error signaled when a password length is specified which is out of
range."))

(defmethod clingon:handle-error ((err length-out-of-range-error))
  (declare (ignore err))
  (format *error-output*
    "Password length must be between ~D and ~D inclusive."
    *password-min-length*
    *password-max-length*))

(define-condition count-out-of-range-error (clingon:base-error)
  ()
  (:documentation
   "Error signaled when a password cpunt is out of range."))

(defmethod clingon:handle-error ((err count-out-of-range-error))
  (declare (ignore err))
  (format *error-output*
          "Password count must be between ~D and ~D inclusive"
          password-min-count
          password-max-count))

;; A general error to handle unforeseen IO errors

(define-condition file-write-error (clingon:base-error)
  ((cl-error
    :reader file-write-error-cl-error
    :initarg :cl-error
    :documentation
    "The Common Lisp error that generated this error"))
  (:report "write error"
   :documentation
   "Error signaled during unsuccessful attempts to write to a file.
See also 'file-exists-error'."))

(defmethod clingon:handle-error ((err file-write-error))
  (format *error-output*
    "~&A write error occurred: ~%~A~%"
    (file-write-error-cl-error err)))

;; User interface proper

(defun toplevel/command ()
  "The toplevel function of the user interface."
  (clingon:make-command
   :name "password"
   :description "Generate one or more random passwords and print them 
to stdout or to one or more files. If no args are supplied, passwords are
 printed to stdout. Otherwise, passwords are printed to the specified 
file(s). When specifying files, a hyphen (-) can be used to print to 
stdout"
   :version "0.1.0"
   :license "MIT"
   :authors '("Larry Devlin <lpd3@github.com>")
   :usage "[options] [file ...]"
   :options (toplevel/options)
   :handler #'toplevel/handler))

(defun toplevel/options ()
  "Defines permissable options. The help and version options are supplied
automatically by clingon."
  (list (clingon:make-option
         :integer
         :description "Number of passwords to generate"
         :short-name #\c
         :long-name "count"
         :initial-value 1
         :key :count)
        (clingon:make-option
         :integer
         :description "Password length"
         :short-name #\l
         :long-name "length"
         :initial-value 8
         :key :length)
        (clingon:make-option
         :boolean/true
         :description "Avoid ambiguous characters"
         :short-name #\A
         :long-name "avoid-ambiguous"
         :key :avoid-ambiguous-p)
        (clingon:make-option
         :boolean/true
         :description "When file paths are specified, permits silent
overwriting of already existing files. Otherwise does nothing."
         :short-name #\f
         :long-name "force"
         :key :forcep)))
   
(defun toplevel/handler (cmd)
  "Does the work of parsing and handling options and args. 
The single parameter to this function is a collection of those options
and args."
  (let ((files (clingon:command-arguments cmd))
        (count (clingon:getopt cmd :count))
        (length (clingon:getopt cmd :length))
        (avoid-ambiguous-p (clingon:getopt cmd :avoid-ambiguous-p))
        (forcep (clingon:getopt cmd :forcep)))
    (passwords
     files
     count
     length
     avoid-ambiguous-p
     forcep)))

(defun main ()
  "The entrypoint to the app."
  (let ((app (toplevel/command)))
    (clingon:run app)))

;;; Core functionality

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

;; Core functions

(defun passwords (files count length avoid-ambiguous-p forcep)
  "Generates one or more passwords. Args: 

FILES (nil or a list of 
strings): If nil, prints passwords to stdout. Otherwise, creates files 
whose paths are in the list and prints passwords to the files. A bare 
hyphen in the list signifies stdout. Defaults to nil.

COUNT (integer): The number of passwords to generate. Defaults to 1.

LENGTH (integer): The length of the passwords (defaults to 8).

AVOID-AMBIGUOUS-P (boolean): If true, avoid using ambiguous characters
in the password (default nil)

FORCEP (boolean): If true, allow already-existing files to be 
overwritten. (default nil).

Passwords will contain all ASCII graphic characters. Each password will
contain at least one uppercase letter, one lowercase letter, one digit,
and one character that is none of these.

Errors:

Signals an error if FORCEP is nil and one of the specified files 
already exists.

Signals an error if COUNT is out of range. As of version 0.1.0, the 
minimum is 1 and the maximum is 1024^2 - 1.

Signals an error if LENGTH is out of range. As of version 0.1.0, the 
minimum is 4 and the maximum is 255.

Signals an error if an attempt to write to file fails.

NOTE: if a bare hyphen appears more than once in FILES list, the 
passwords will be printed more than once to stdout. If a filename
appears more than once, the passwords will appear only once in the 
file."
  (when (not (<= *password-min-length*
                 length
                 *password-max-length*))
    (error 'length-out-of-range-error))
  (when (not (<= *password-min-count*
                 count
                 *password-max-count*))
    (error 'count-out-of-range-error))
  (let ((pwds nil))
    (dotimes (_ count)
      (push (gen-password
             length
             avoid-ambiguous-p)
            pwds))
    (if (null files)
        (print-pwds
         *standard-output*
         pwds)
        (dolist (file files)
          (cond
            ((equal file "-")
             (print-pwds
              *standard-output*
              pwds))
            ((and (not forcep)
                  (probe-file file))
             (error
              'file-exists-error
              :file file))
            (t
             (handler-case
               (with-open-file
                 (f file
                  :direction :output
                  :if-does-not-exist :create
                  :if-exists :overwrite)
                 (print-pwds
                  f
                  pwds))
               (file-error (e)
                 (error
                  'file-write-error
                  :cl-error e)))))))))

(defun print-pwds (stream pwds)
  "Given STREAM (a stream or a 
  Boolean), and PWDS, print each
  password followed by a newline
  character to STREAM, if a real
  stream is specified. If STREAM is
  otherwise non-nil, print to stdout. If 
  STREAM is nil, return the newline-separated
  passwords as Lisp strings."
  (dolist (p pwds)
    (format stream "~&~A~%" p)))

(defun gen-password (length avoid-ambiguous-p)
  "Generate a single random password of length
LENGTH. Password contains at least one uppercase letter, 
one lowercase letter, one digit and one special 
character. All characters are graphical ASCII 
characters. 

Arguments, both mandatory: LENGTH and AVOID-AMBIGUOUS-P.
The latter, if non-nil, will prevent visually ambiguous
characters from appearing in the password.

Error: Will signal an error if the length is less than 
*password-min-length*, which is 4 as of version 0.1.0."
  (let ((pwd (init-password length avoid-ambiguous-p)))
    (loop for index from *password-min-length*
          while (< index length)
          do
             (add-random-char pwd index avoid-ambiguous-p)
          finally
             (return (nshuffle pwd)))))

(defun init-password (length avoid-ambiguous-p)
  "Given LENGTH (integer) and AVOID-AMBIGUOUS-P (boolean),
  return a string of length LENGTH whose first four 
  characters are a random uppercase letter, a random
  lowercase letter, a random digit and a random special
  character. The rest of the characters are spaces. All
  characters are ASCII characters. The first four are all
  graphic characters.

  Errors: Signals an error if LENGTH is less than 4."
  (let ((char-classes (list :upper :lower :digit :special))
        (pwd (make-array length
              :element-type 'base-char
              :initial-element #\Space)))
    (loop for class in char-classes
          for index from 0
          do (add-random-char pwd index avoid-ambiguous-p class)
          finally
          (return pwd))))

(defparameter *char-sets*
  (make-array 4
    :element-type 'string
    :initial-contents (list *uppercase* *lowercase* *digit* *special*)))

(defun add-random-char (pwd index avoid-ambiguous-p &optional char-class)
  "Args:
   
   PWD: a simple vector of base characters 
   INDEX: a non-negative integer
   AVOID-AMBIGUOUS-P: a boolean
   &optional CHAR-CLASS: a symbol

   Returns: a simple vector of base characters.

   Adds a random ASCII graphical character at INDEX to
   PWD. CHAR-CLASS is a symbol and must be one of 
   nil (default), :upper, :lower, :digit, or 
   :special. The supplied symbol specifies the 
   class of the character: uppercase letter, lowercase
   letter, digit or special character. If nil or 
   not supplied, the character will be randomly
   chosen from the four classes. If AVOID-AMBIGUOUS-P is
   non-nil, visually ambiguous characters will be selected.

   Errors: An error is signaled when the index is 
   out of bounds."
  (let ((char-set (ecase char-class
                    (:upper *uppercase*)
                    (:lower *lowercase*)
                    (:digit *digit*)
                    (:special *special*)
                    ((nil) (rand-aref *char-sets*)))))
    (loop for c = (rand-aref char-set)
          while (and avoid-ambiguous-p
                     (find c *confusing*))
          finally
             (setf (aref pwd index) c)))
  pwd)

(defun rand-aref (vector)
  "Given a vector of any type, return a random element."
  (aref vector (strong-random (length vector))))

(defun nshuffle (vector)
  "Given a vector of any type, destructively shuffle it,
   and return the shuffled vector."
  (dotimes (i (length vector))
    (rotatef
     (aref vector i)
     (aref vector (strong-random (length vector)))))
  vector)

