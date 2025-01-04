(in-package :password-tests)

(fiveam:def-suite password-test-suite
  :description
  "Suite containing all tests for the `password` app")

(fiveam:in-suite password-test-suite)

(fiveam:def-suite core-functionality-test-suite
  :in password-test-suite
  :description
  "Contains tests covering password generation and printing.")

(fiveam:in-suite core-functionality-test-suite)

(fiveam:test shuffle-works
 "Test the shuffle function. Does not test for randomness."
  (setf fiveam:*num-trials* 10
        fiveam:*max-trials* 15)
  (fiveam:for-all ((ran-string
                    (fiveam:gen-string
                     :length (fiveam:gen-integer :min 4 :max 255)
                     :elements (fiveam:gen-character
                                :code (fiveam:gen-integer
                                       :min 36 :max 126)))))
    (do* ((original ran-string copy)
          (copy #1=(copy-array original) #1#)
          (count 0 (1+ count))
          (equalp-count 0))
         ((= count 10) (fiveam:is (<= (/ equalp-count 10) 1/3)))
      (nshuffle copy)
      (fiveam:is (equalp (frequencies original)
                         (frequencies copy)))
      (when (equalp original copy)
        (incf equalp-count)))))

(fiveam:test rand-aref-works
  "Tests the rand-aref function. Does not test randomness."
  ;; Using a test string and a test vector containing keywords,
  ;; Collect a bag of 100 items from each, by repeatedly calling
  ;; rand-aref.
  (let ((test-string "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef\
ghijklmnopqrstuvwxyz0123456789-=,'.;()&^%$#@_+:><}{@?")
        (test-vector #(:one :two :three :four))
        (char-bag nil)
        (symbol-bag nil))
    (dotimes (_ 100)
      (push (rand-aref test-string) char-bag)
      (push (rand-aref test-vector) symbol-bag))
    ;; Check to make sure that all the elements in each
    ;; bag can be found in the source vector.
    (fiveam:is
     (every #'(lambda (c)
                (find c test-string))
            char-bag))
    (fiveam:is
     (every #'(lambda (s)
                (find s test-vector))
            symbol-bag))
    ;; Check to make sure the bags don't have way too
    ;; many of any particular character
    (labels ((balanced-p (bag threshold)
               (let ((freq (frequencies bag)))
                 (maphash #'(lambda (k v)
                              (declare (ignore k))
                              (when (> v threshold)
                                (return-from balanced-p nil)))
                          freq)
                 t)))
      (fiveam:is (balanced-p char-bag (* (/ 100 (length test-string))
                                         10)))
      (fiveam:is (balanced-p symbol-bag 40)))))

(fiveam:test add-random-char-works
  "Tests the add-random-character function"
  ;; Make sure each of the character classes are handled properly
  (let* ((upper-vector
           (make-array 10
             :element-type 'base-char
             :initial-element #\Space))
         (lower-vector #4=(copy-array upper-vector))
         (digit-vector #4#)
         (special-vector #4#))
    (dotimes (i 10)
      (add-random-char upper-vector i nil :upper)
      (add-random-char lower-vector i nil :lower)
      (add-random-char digit-vector i nil :digit)
      (add-random-char special-vector i nil :special))
    (fiveam:is (every #'(lambda (c)
                          (find c *uppercase*))
                      upper-vector))
    (fiveam:is (every #'(lambda (c)
                          (find c *lowercase*))
                      lower-vector))
    (fiveam:is (every #'(lambda (c)
                          (find c *digit*))
                      digit-vector))
    (fiveam:is (every #'(lambda (c)
                          (find c *special*))
                      special-vector)))

  ;; check out the avoid-ambiguous-p and
  ;; make sure there is some ba&lance
  (let ((vector (make-array 100
                             :element-type 'base-char
                             :initial-element #\Space)))
    (dotimes (i 100)
      (add-random-char vector i t))
    (fiveam:is (notany #'(lambda (c)
                           (find c *confusing*))
                       vector))
    (fiveam:is (every #'(lambda (f)
                          (<= f 10))
                      (hash-table-values
                       (frequencies vector))))))

(fiveam:test init-password-works
 "Tests the init-password function."
 (let ((init-a (init-password 100 nil))
       (init-b (init-password 100 nil)))
   (dotimes (i 4)
     (fiveam:is (find (aref init-a i) (aref *char-sets* i))))
   (fiveam:is (not (equalp init-a init-b)))
   (loop for i from 4 below 100
         do
         (fiveam:is (char= (char init-a i) #\Space)))
   (let ((init-c (init-password 10 t)))
     (dotimes (i 4)
       (fiveam:is-false (find (aref init-c i) *confusing*))))))

(fiveam:test gen-password-test
  "Test the gen-password function"
  (setf fiveam:*num-trials* 10
        fiveam:*max-trials* 15)
  (fiveam:for-all ((length (fiveam:gen-integer :min *password-min-length*
                                               :max *password-max-length*))
                   (avoid-ambiguous-number
                    (fiveam:gen-integer)))
    (let ((avoid-ambiguous-p (oddp avoid-ambiguous-number)))

      (fiveam:finishes
        (format t "~&GEN-PASSWORD output~%~A~%"
                (gen-password length avoid-ambiguous-p))))))

(fiveam:test print-pwds-works
  (let ((pwds nil))
    (dotimes (_ 10)
      (push (gen-password 10 nil) pwds))
    (fiveam:finishes
      (uiop:format! t "~&PRINT-PWDS to terminal:~%")
      (print-pwds *standard-output* pwds))

    (uiop:with-temporary-file
        (:stream tf
         :pathname pn
         :direction :io)
      (fiveam:finishes
        (print-pwds tf pwds))
      :close-stream
      (with-open-file
          (f pn
             :direction :input
             :if-does-not-exist :error)
        (uiop:format! t "~&PRINT-PWDS file content:~%")
        (let ((contents
                (uiop:slurp-stream-string f)))
          (uiop:format! t "~&~A~%~%" contents))))))

(fiveam:test passwords-generation
  "Tests that passwords generates lists of
  passwords successfully, and prints
  them to stdout, given a files arg
  of nil or a list containing a string that
  is a hyphen."
;args: files, count, length, aap, fp
  (let ((fileses '(nil ("-")))
       (counts '(1 2 3))
       (lengths '(4 5 6))
       (aaps '(nil t))
       (forcep nil))
   (dolist (avoid-ambiguous-p aaps)
     (dolist (length lengths)
       (dolist (count counts)
         (dolist (files fileses)
           (format t "~&(passwords ~A ~A ~A ~A nil:~%"
                   files count length avoid-ambiguous-p forcep)
           (fiveam:finishes (passwords files count length avoid-ambiguous-p forcep))
           (terpri)))))))

(fiveam:test passwords-file-handling-works
  (uiop:with-temporary-file
      (:stream s1
       :pathname p1
       :direction :io)
    (uiop:with-temporary-file
        (:stream s2
         :pathname p2
         :direction :io)
      (uiop:with-temporary-file
          (:stream s3
           :pathname p3
           :direction :io)
        (fiveam:finishes
          (passwords
           `(,p1 ,p2 ,p3)
           10
           10
           nil
           t))
        (file-position s1 :start)
        (file-position s2 :start)
        (file-position s3 :start)
        (let ((slrp1
                (uiop:slurp-stream-string s1))
              (slrp2
                (uiop:slurp-stream-string s2))
              (slrp3
                (uiop:slurp-stream-string s3)))
          (fiveam:is
           (string= slrp1 slrp2))
          (fiveam:is
           (string= slrp2 slrp3)))))))

(fiveam:test passwords-does-not-write-over-files-without-forcep
  (with-open-file
      (f (ensure-directories-exist
          "tmp/i-exist.tmp")
       :direction :output
       :if-does-not-exist :create
       :if-exists :overwrite)
    (princ "Howdy" f))
  (fiveam:signals
    file-exists-error
    (passwords
     '("tmp/i-exist.tmp")
     1
     4
     nil
     nil))
  (uiop:run-program "rm -rf tmp"
   :error-output t))

(fiveam:test passwords-writes-over-file-with-forcep
  "Tests that files are overwritten when forcep
   is non-nil"
  (with-open-file
      (f (ensure-directories-exist
          "tmp/i-exist.tmp")
       :direction :output
       :if-does-not-exist :create
       :if-exists :overwrite)
    (princ "Howdy" f))
  (fiveam:finishes
    (passwords
     '("tmp/i-exist.tmp")
     10
     10
     nil
     t))
  (let ((file-contents
          (uiop:read-file-string "tmp/i-exist.tmp")))
    (fiveam:is
     (> (length file-contents) (1+ (length "Howdy")))))
  (uiop:run-program "rm -rf tmp"
                    :error-output t))

(fiveam:test passwords-signals-count-out-of-range-error
  (fiveam:signals
    count-out-of-range-error
    (passwords
     nil
     (1- *password-min-count*)
     4
     nil
     nil))
  (fiveam:signals
    count-out-of-range-error
    (passwords
     nil
     (1+ *password-max-count*)
     4
     nil
     nil)))

(fiveam:test passwords-signals-length-out-of-range-error
  (fiveam:signals
    length-out-of-range-error
    (passwords
     nil
     1
     (1- *password-min-length*)
     nil
     nil))
  (fiveam:signals
    length-out-of-range-error
    (passwords
     nil
     1
     (1+ *password-max-length*)
     nil
     nil)))

(fiveam:test passwords-signals-file-write-error
  (uiop:run-program "mkdir tmp" :error-output t)
  (uiop:run-program "sudo chmod 1000 tmp") ; all permissions denied for everyone,  
  (fiveam:signals                          ; and sticky bit set.
    file-write-error
    (passwords
     '("tmp/file-inaccessible.txt")
     1
     4
     nil
     nil) 
    (uiop:run-program "sudo rm -rf tmp")))    
