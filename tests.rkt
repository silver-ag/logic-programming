#lang racket

;; tests for the logic-programming system

(require rackunit "main-new.rkt" racket/generator)

;; basics

(define (basic-tests)
  (display "making basic tests of the unification system...\n")
  (check-equal? (query-all 'X '((:- a false) (:- b c)))
                '()
                "no unifications")
  (check-equal? (query-all 'X '(a (b c) (:- d e) (f G)))
                (list
                 (list (ec '(X) 'a))
                 (list (ec '(X) '(b c)))
                 (list (ec '(X) '(f G-3))))
                "single-level unifications")
  (check-equal? (query-all '(p X) '((:- (p Y) (q Y)) (:- (q Z) (r Z)) (r W)))
                '(())
                "multi-level unification with no bindings in the end")
  (check-equal? (query-all '(p X) '((:- (p Y) (q Y)) (:- (q Z) (r Z)) (r a)))
                (list (list (ec '(X) 'a)))
                "multi-level unification")
  (check-equal? (query-all '(test X) '((:- (test (a X)) (= X b))))
                (list (list (ec '(X) '(a b))))
                "complex unification on antecedent side")
  (check-equal? (query-all '(p V W X Y Z) '((:- (p A A A B B) (q B)) (q a)))
                (list (list (ec '(Z Y) 'a) (ec '(W V X) #f)))
                "unification of more than two values"))

;; special predicates

(define (special-predicate-tests)
  (display "making tests of special predicates 'and', 'or', 'unprovable' and '\\\\='...\n")
  (check-equal? (query-all '(and (a X) (b Y)) '((a c) (b d) (b e)))
                (list
                 (list (ec '(Y) 'd) (ec '(X) 'c))
                 (list (ec '(Y) 'e) (ec '(X) 'c)))
                "simple use of and")
  (check-equal? (query-all '(or (a X) (b Y)) '((a c) (b d) (b e)))
                (list
                 (list (ec '(X) 'c))
                 (list (ec '(Y) 'd))
                 (list (ec '(Y) 'e)))
                "simple use of or")
  (check-equal? (query-all '(unprovable a) '(a))
                '()
                "simple unprovable failure")
  (check-equal? (query-all '(unprovable b) '(a))
                '(())
                "simple unprovable success")
  (check-equal? (query-all '(and (= a X) (unprovable (= b X))) '())
                (list (list (ec '(X) 'a)))
                "order-dependant unprovable success")
  (check-equal? (query-all '(and (unprovable (= b X)) (= a X)) '())
                '()
                "order-dependant unprovable failure")
  (check-equal? (query-all '(and (= a X) (\\= b X)) '())
                (list (list (ec '(X) 'a)))
                "order-dependant \\\\= success")
  (check-equal? (query-all '(and (\\= b X) (= a X)) '())
                '()
                "order-dependant \\\\= failure")
  (check-equal? (query-all '(or (and (a X) (or (b Y) (c Y))) (and (d Z) (e W)))
                           '((a a) (b b) (c c) (d d) (e e)))
                (list
                 (list (ec '(Y) 'b) (ec '(X) 'a))
                 (list (ec '(Y) 'c) (ec '(X) 'a))
                 (list (ec '(W) 'e) (ec '(Z) 'd)))
                "nested 'and' and 'or'"))

;; try some actual programs

(define (program-tests)
  (display "trying some actual simple programs...\n")
  (check-equal? (query-all '(member (c x (c y (c z empty))) X)
                           '((member (c H T) H)
                             (:- (member (c H T) X) (member T X))))
                (list
                 (list (ec '(X) 'x))
                 (list (ec '(X) 'y))
                 (list (ec '(X) 'z)))
                "member"))

;; useful utility

(define (query-all q kb)
  (define (get-all g acc)
    (let [[next (g)]]
      (if next
          (get-all g (cons next acc))
          acc)))
  (let [[gen (query q kb #t)]]
    (reverse (get-all gen '()))))

;; run tests

(basic-tests)
(special-predicate-tests)
(program-tests)