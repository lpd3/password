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

(setf fiveam:*num-trials* 10
      fiveam:*max-trials* 15)

(fiveam:test shuffle-works
 "Test the shuffle function. Does not test for randomness."
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
  ;; make sure there is some balance
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

(setf fiveam:*num-trials* 100
      fiveam:*max-trials* 150)

(fiveam:test gen-password-test
  "Test the gen-password function"
  (fiveam:for-all ((length (fiveam:gen-integer :min *password-min-length*
                                               :max *password-max-length*))
                   (avoid-ambiguous-number
                    (fiveam:gen-integer)))
    (let ((avoid-ambiguous-p (oddp avoid-ambiguous-number)))
      (fiveam:finishes
        (gen-password length avoid-ambiguous-p)))))

(fiveam:test print-pwds-works
  (error "Fix this test so that the contents of 
    printing to stdout and file are visible")
  "Tests the print-pwds function"
  (let ((pwds nil))
    (dotimes (8 10)
      (push (gen-password 10 nil) pwds))
    (fiveam:finishes
      (print-pwds t pwds))
    (uiop:with-temporary-file
        (:stream tf
         :direction :io
         :prefix "test-temp-")
      (fiveam:finishes (print-pwds tf pwds))
      (format t "~%~%Contents of file:~%~%")
      (format t "~A~%"
        (uiop:slurp-stream-string tf)))))

(fiveam:test passwords-generation
  "Tests that passwords generates lists of
  passwords successfully"
                                        ; files, count, length, aap, fp
  (fiveam:for-all  ((count (fiveam:gen-integer :min 1 :max 100))
                    (length (fiveam:gen-integer :min 4 :max 255))
                    (avoid-number (fiveam:gen-integer))
                    (force-number (fiveam:gen-integer)))
    (let ((files nil)
          (avoid-ambiguous-p (oddp avoid-number))
          (forcep (oddp force-number)))
      (fiveam:is (listp (passwords files count length avoid-ambiguous-p forcep))))))
