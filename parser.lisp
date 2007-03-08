;; A simple top-down, backtracking parser
;; Modelled after EBNF notation

(defun starts-with (string prefix &key (start 0))
  "Does 'string' begin with 'prefix'?"
  (let ((end (+ start (length prefix)))
        (l (length string)))
    (if (> end l)
        nil
        (string= prefix string :start2 start :end2 end))))

;; return a list of the children
;; return the end of the last child
(defun kleene* (f string &key (start 0))
  (multiple-value-bind (end value) (funcall f string :start start)
    (if end
        (multiple-value-bind (e v) (kleene* f string :start end)
          (values e (cons value v)))
        (values start nil))))

(defun kleene+ (f string &key (start 0))
  "<rule>+ == <rule> <rule>*"
  (multiple-value-bind (end value) (funcall f string :start start)
    (if end
        (multiple-value-bind (e v) (kleene* f string :start end)
          (values e (cons value v)))
        nil)))

;; Construction macros
(defmacro grammar-string (str)
  `(when (starts-with string ,str :start start)
    (values (+ start ,(length str)) ,str)))

(defmacro grammar-and (first &rest rest)
  (if (null rest)
      first
      `(multiple-value-bind (end value) ,first
        (when end
          (let ((start end))
          (multiple-value-bind (e v) (grammar-and ,@rest)
            (when e
              (if (listp v)
                  (values e (cons value v))
                  (values e (list value v))))))))))


(defmacro grammar-or (first &rest rest)
  (if (null rest)
      first
      `(multiple-value-bind (end value) ,first
        (if end
            (values end value)
            (grammar-or ,@rest)))))


(defmacro grammar-* (x)
  (cond
    ((null x) nil)
    ((symbolp x) `(kleene* ',x string :start start))
    ((listp x)
     (let ((f (gensym)))
       `(let ((,f (lambda (string &key (start 0))
                   ,x)))
         (kleene* ,f string :start start))))
    (t (error (format nil "grammar-* cannot process ~S" x)))))

(defmacro grammar-exception (x y)
  "a syntactic-exception; x but not also y"
  `(multiple-value-bind (end value) ,x
    (when end
      (multiple-value-bind (e v) ,y
        (declare (ignore v))
        (when (not e)
          (values end value))))))

(defun parse-test (string &key (start 0))
  "match := 'a' | 'b'"
  (grammar-or
   (grammar-string "a")
   (grammar-string "b")))

;; This is ambiguous; for now, 'a'* always matches...
(defun parse-test (string &key (start 0))
  "match := 'a'* | 'b'"
  (grammar-or
   (grammar-* (grammar-string "a"))
   (grammar-string "b")))

(defun parse-test (string &key (start 0))
  "match := 'a', 'b'"
  (grammar-and
   (grammar-string "a")
   (grammar-string "b")))

(defun parse-test (string &key (start 0))
  "match = {('a' | 'b' | 'c') - 'b'}"
  (grammar-*
   (grammar-exception
    (grammar-or (grammar-string "a")
                (grammar-string "b")
                (grammar-string "c"))
    (grammar-string "b"))))

;; Simple grammar
(defun parse-token (string &key (start 0))
  "token := 'a' | 'b'"
  (grammar-or
   (grammar-string "a")
   (grammar-string "b")))

(defun parse-list (string &key (start 0))
  "list := '(', {token}, ')'"
  (grammar-and
   (grammar-string "(")
   (grammar-* parse-token)
   (grammar-string ")")))

;; Example from ISO EBNF spec, section 5.8
(defun letter (string &key (start 0))
  (grammar-or
   (grammar-string "A")
   (grammar-string "B")
   (grammar-string "C")
   (grammar-string "D")
   (grammar-string "E")
   (grammar-string "F")
   (grammar-string "G")
   (grammar-string "H")
   (grammar-string "I")
   (grammar-string "J")
   (grammar-string "K")
   (grammar-string "L")
   (grammar-string "M")
   (grammar-string "N")
   (grammar-string "O")
   (grammar-string "P")
   (grammar-string "Q")
   (grammar-string "R")
   (grammar-string "S")
   (grammar-string "T")
   (grammar-string "U")
   (grammar-string "V")
   (grammar-string "W")
   (grammar-string "X")
   (grammar-string "Y")
   (grammar-string "Z")))

(defun vowel (string &key (start 0))
  (grammar-or
   (grammar-string "A")
   (grammar-string "E")
   (grammar-string "I")
   (grammar-string "O")
   (grammar-string "U")))

(defun consonant (string &key (start 0))
  (grammar-exception
   (letter string :start start)
   (vowel string :start start)))

(defun ee (string &key (start 0))
  (grammar-and
   (grammar-exception (grammar-* (grammar-string "A"))
                      nil)
   (grammar-string "E")))


;;;; Special conditions

;; Flag whether to ignore whitespace between tokens
(defparameter *grammar-no-white* nil)

;; List of restricted keywords
(defparameter *grammar-keywords* (make-hash-table :test #'equal))