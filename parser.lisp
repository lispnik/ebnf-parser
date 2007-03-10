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
(defun match-n (n f string &key (start 0))
  (if (> n 0)
      (multiple-value-bind (end value) (funcall f string :start start)
        (when end
          (multiple-value-bind (e v) (match-n (1- n) f string :start end)
            (when e
              (if (car v)
                  (values e (cons value v))
                  (values e (list value)))))))
      start))

(defun kleene* (f string &key (start 0))
  (multiple-value-bind (end value) (funcall f string :start start)
    (if end
        (multiple-value-bind (e v) (kleene* f string :start end)
          (values e (cons value v)))
        start)))

(defun kleene+ (f string &key (start 0))
  "<rule>+ == <rule> <rule>*"
  (multiple-value-bind (end value) (funcall f string :start start)
    (if end
        (multiple-value-bind (e v) (kleene* f string :start end)
          (values e (cons value v)))
        nil)))

;;
;; Construction macros
;;

;; Provide a clean interface to rules expressed as either function names or macros
(defmacro grammar-call (x)
  (cond ((null x) (error "Cannot execute nil."))
        ((symbolp x) `(,x string :start start))
        ((listp x) x)
        (t (error "Cannot call ~S" x))))

(defmacro grammar-wrap (x)
  (cond ((null x) (error "Cannot execute nil."))
        ((symbolp x) (list 'quote x))
        ((listp x) `(lambda (string &key (start 0)) ,x))
        (t (error "Cannot call ~S" x))))

(defmacro grammar-string (str)
  `(when (starts-with string ,str :start start)
    (values (+ start ,(length str)) ,str)))

(defmacro grammar-optional (x)
  `(multiple-value-bind (end value) (grammar-call ,x)
    (if end
        (values end value)
        start)))

(defmacro grammar-and (first &rest rest)
  (if (null rest)
      `(grammar-call ,first)
      `(multiple-value-bind (end value) (grammar-call ,first)
        (when end
          (let ((start end))
          (multiple-value-bind (e v) (grammar-and ,@rest)
            (when e
              (if (listp v)
                  (values e (cons value v))
                  (values e (list value v))))))))))


(defmacro grammar-or (first &rest rest)
  (if (null rest)
      `(grammar-call ,first)
      `(multiple-value-bind (end value) (grammar-call ,first)
        (if end
            (values end value)
            (grammar-or ,@rest)))))

(defmacro grammar-n* (n x)
  `(match-n ,n (grammar-wrap ,x) string :start start))

(defmacro grammar-* (x)
  `(kleene* (grammar-wrap ,x) string :start start))

(defmacro grammar-exception (x y)
  "a syntactic-exception; x but not also y"
  `(multiple-value-bind (end value) (grammar-call ,x)
    (when end
      (multiple-value-bind (e v) (grammar-call ,y)
        (declare (ignore v))
        (when (not e)
          (values end value))))))

;;
;; Value-changing mechanism
;;
(defmacro grammar-func (x f)
  "Apply f to the value of x"
  `(multiple-value-bind (end value) (grammar-call ,x)
    (when end
      (values end (,f value)))))


;; Simple tests
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

(defmacro grammar-rule (name &rest body)
  `(defun ,name (string &key (start 0))
    ,@body))

(grammar-rule parse-test
  (grammar-func
   (grammar-* (grammar-string "a"))
   (lambda (x) (format nil "~{~A~}" x))))

(grammar-rule parse-test
  (grammar-func
   (grammar-and (grammar-* (grammar-string "a"))
                (grammar-string "b"))
   (lambda (list)
     (destructuring-bind (x y) list
       (format nil "~{~A~}, ~A" x y))))))

;; Example from ISO EBNF spec, section 5.7
(grammar-rule aa
  (grammar-string "A"))

(grammar-rule bb
  (grammar-and
   (grammar-n* 3 aa)
   (grammar-string "B")))

(grammar-rule cc
  (grammar-and
   (grammar-n* 3 (grammar-optional aa))
   (grammar-string "C")))

(grammar-rule dd
  (grammar-and
   (grammar-* aa)
   (grammar-string "D")))

(grammar-rule ee
  (grammar-and
   aa
   (grammar-* aa)
   (grammar-string "E")))

(grammar-rule ff
  (grammar-and
   (grammar-n* 3 aa)
   (grammar-n* 3 (grammar-optional aa))
   (grammar-string "F")))

(grammar-rule gg
  (grammar-and
   (grammar-n* 3 (grammar-* aa))
   (grammar-string "D")))

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