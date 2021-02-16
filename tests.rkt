#lang racket

;; tests for the logic-programming system

(require rackunit "main.rkt" racket/generator)

;; basics

(define (basic-tests)
  (display "making basic tests of the unification system...\n")
  (check-equal? (query-all 'X '((:- a false) (:- b c)))
                '()
                "no unifications")
  (check-equal? (query-all 'X '(a (b c) (:- d e) (f G)))
                (list
                 (set (ec '(X) 'a))
                 (set (ec '(X) '(b c)))
                 (set (ec '(X) '(f G-3))))
                "single-level unifications")
  (check-equal? (query-all '(p X) '((:- (p Y) (q Y)) (:- (q Z) (r Z)) (r W)))
                (list (set))
                "multi-level unification with no bindings in the end")
  (check-equal? (query-all '(p X) '((:- (p Y) (q Y)) (:- (q Z) (r Z)) (r a)))
                (list (set (ec '(X) 'a)))
                "multi-level unification")
  (check-equal? (query-all '(test X) '((:- (test (a X)) (= X b))))
                (list (set (ec '(X) '(a b))))
                "complex unification on antecedent side")
  (check-equal? (query-all '(p V W X Y Z) '((:- (p A A A B B) (q B)) (q a)))
                (list (set (ec '(Z Y) 'a) (ec '(W V X) #f)))
                "unification of more than two values"))

;; special predicates

(define (special-predicate-tests)
  (display "making tests of special predicates 'and', 'or', 'unprovable' and '\\\\='...\n")
  (check-equal? (query-all '(and (a X) (b Y)) '((a c) (b d) (b e)))
                (list
                 (set (ec '(Y) 'd) (ec '(X) 'c))
                 (set (ec '(Y) 'e) (ec '(X) 'c)))
                "simple use of and")
  (check-equal? (query-all '(or (a X) (b Y)) '((a c) (b d) (b e)))
                (list
                 (set (ec '(X) 'c))
                 (set (ec '(Y) 'd))
                 (set (ec '(Y) 'e)))
                "simple use of or")
  (check-equal? (query-all '(unprovable a) '(a))
                '()
                "simple unprovable failure")
  (check-equal? (query-all '(unprovable b) '(a))
                (list (set))
                "simple unprovable success")
  (check-equal? (query-all '(and (= a X) (unprovable (= b X))) '())
                (list (set (ec '(X) 'a)))
                "order-dependant unprovable success")
  (check-equal? (query-all '(and (unprovable (= b X)) (= a X)) '())
                '()
                "order-dependant unprovable failure")
  (check-equal? (query-all '(and (= a X) (\\= b X)) '())
                (list (set (ec '(X) 'a)))
                "order-dependant \\\\= success")
  (check-equal? (query-all '(and (\\= b X) (= a X)) '())
                '()
                "order-dependant \\\\= failure")
  (check-equal? (query-all '(or (and (a X) (or (b Y) (c Y))) (and (d Z) (e W)))
                           '((a a) (b b) (c c) (d d) (e e)))
                (list
                 (set (ec '(Y) 'b) (ec '(X) 'a))
                 (set (ec '(Y) 'c) (ec '(X) 'a))
                 (set (ec '(W) 'e) (ec '(Z) 'd)))
                "nested 'and' and 'or'"))

;; try some actual programs

(define (program-tests)
  (display "trying some actual simple programs...\n")
  (check-equal? (query-all '(member (c x (c y (c z empty))) X)
                           '((member (c H T) H)
                             (:- (member (c H T) X) (member T X))))
                (list
                 (set (ec '(X) 'x))
                 (set (ec '(X) 'y))
                 (set (ec '(X) 'z)))
                "member")
  (check-equal? (query-all '(plus (s (s (s z))) (s z) X)
                           '((plus X z X)
                             (:- (plus X (s Y) Z)
                                 (plus (s X) Y Z))))
                (list (set (ec '(X) '(s (s (s (s z)))))))
                "church addition")
  (check-equal? (query '(plus (s (s z)) X (s (s (s (s (s z)))))) ;; only query once because this naive version loops forever if it can't find any more options
                           '((plus X z X)
                             (:- (plus X (s Y) Z)
                                 (plus (s X) Y Z))))
                (set (ec '(X) '(s (s (s z)))))
                "church subtraction"))

;; run tests

(basic-tests)
(special-predicate-tests)
(program-tests)