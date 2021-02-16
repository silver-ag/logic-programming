#lang racket

(require racket/generator)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Equivalence Class Struct
;;;;

(struct ec
  (eqvs ;; set of sets of variables
   val) ;; nonvariable value or #f
  #:transparent)

;;;;;;;;;;;;;;;;
;; Unification
;;;;

(define (unify vars . preds)
  ;; return
  (define (unify-pair p1 p2 vars)
    (cond
      [(equal? p1 p2) vars]
      [(or (variable? p1) (variable? p2)) (vars-add vars p1 p2)]
      [(and (list? p1) (list? p2)
            (= (length p1) (length p2)))
       (foldl (λ (pp1 pp2 vacc)
                (if vacc
                    (unify-pair pp1 pp2 vacc)
                    #f))
              vars
              p1 p2)]
      [else #f]))
  (if (< (length preds) 2)
      (set)
      (let [[result
             (second (foldl
                      (λ (p pvacc)
                        (if (first pvacc)
                            (list p (unify-pair p (first pvacc) (second pvacc)))
                            '(#f #f)))
                      (list (first preds) vars)
                      (rest preds)))]]
        ;(if result (apply set result) #f))))
        result)))

(define (variable? v)
  ;; symbol beginning with a capital letter
  (and (symbol? v)
       (char-upper-case? (first (string->list (symbol->string v))))))

;;;;;;;;;;;;
;; Queries
;;;;

(define (satisfy pred kb [generator? #f] [trace? #f])
  ;; return variable bindings required for pred to be true on kb or #f if none exist
  (define unique-suffix-gen ;; make a new one each query so we don't build up to really long suffixes over long runs
    (generator () (define (next-num n)
                    (yield (string-append "-" (number->string n)))
                    (next-num (+ n 1)))
               (next-num 0)))
  (define (query-internal pred kb vars)
    (if trace? (display (format "TRACE: calling ~a, [~a]\n" pred vars)) (void))
    (case (and (list? pred) (first pred))
      [(and)
       (let-values [[(attempt1 continuation1) (query-internal (second pred) kb vars)]]
         (if attempt1
             (let-values [[(attempt2 continuation2) (query-internal (third pred) kb attempt1)]]
               (if attempt2
                   ;(let [[result (vars-merge attempt1 attempt2)]]
                   ;  (if result
                         (values attempt2 continuation2)
                    ;     (continuation1 #f #f)))
                   (continuation1 #f #f)))
             (values #f #f)))]
      [(or) (let-values [[(attempt1 continuation1) (query-internal (second pred) kb vars)]]
              (if attempt1
                  (values attempt1 continuation1)
                  (query-internal (third pred) kb vars)))]
      [(unprovable) ;; this is prolog not, so be careful
       (let-values [[(attempt continuation) (query-internal (second pred) kb vars)]]
         (if attempt
             (values #f #f)
             (values vars continuation)))]
      [(\\=) ;; does not unify
       (let [[attempt (unify vars (second pred) (third pred))]]
         (if attempt
             (values #f #f)
             (let/cc fail-continuation (values vars fail-continuation))))]
      [(=) ;; unifies
       (let [[attempt (unify vars (second pred) (third pred))]]
         (if attempt
             (let/cc continuation (values attempt continuation))
             (values #f #f)))]
      [else
       (if (equal? pred 'true)
           (let/cc k (values vars k))
           (let-values [[(new-vars new-pred unification-continuation)
                         (get-unification pred
                                          (map (λ (i) (make-unique i (unique-suffix-gen))) kb)
                                          vars)]]
             (if new-vars
                 (let-values [[(next-query continuation) (query-internal new-pred kb new-vars)]]
                   (if next-query (values next-query continuation) (unification-continuation #f #f)))
                 (values #f #f))))]))
  (if generator?
      (generator () (call-with-continuation-prompt ;; prompt isolates the effects of rewinding to only stuff inside it
                     (λ ()
                       (let-values [[(answer continuation) (query-internal pred kb (set))]]
                         (yield (process-relevant-vars pred answer))
                         (if continuation
                             (continuation #f #f)
                             #f)))))
      (let-values [[(answer continuation) (query-internal pred kb (set))]]
        (process-relevant-vars pred answer))))

(define (get-unification stmnt kb vars)
  ;; find a unification between stmnt and a member of kb (dealing with :- implications)
  ;; return new vars required, next pred (true if not :-) [unimplemented: and a continuation]
  (if (empty? kb)
      (values #f #f #f)
      (let*-values [[(target) (if (and (list? (first kb)) ;; make unconditional options conditional on 'true
                                     (equal? (first (first kb)) ':-))
                                (first kb)
                                `(:- ,(first kb) true))]
                    [(continuation attempt) (let/cc k (values k (unify vars stmnt (second target))))]]
        (if attempt
            (values attempt (third target) continuation)
            (get-unification stmnt (rest kb) vars)))))

(define (make-unique stmnt suffix)
  ;; return the statement with all variables given prefixes in the form -# where # is a number not used before this run
  (cond
    [(list? stmnt) (map (λ (s) (make-unique s suffix)) stmnt)]
    [(variable? stmnt)
     (string->symbol (string-append (symbol->string stmnt)
                                    suffix))]
    [else stmnt]))

(define (process-relevant-vars stmnt vars)
  (define (replace-vars vars pred)
    (cond
      [(list? pred) (map (curry replace-vars vars) pred)]
      [(variable? pred)
       (let [[find (filter (λ (x) (member pred (ec-eqvs x))) vars)]]
         (if (empty? find)
             pred
             (replace-vars vars (ec-val (first find)))))]
      [else pred]))
  (if vars
      (let [[relevant (filter variable? (flatten stmnt))]]
        (apply set
               (filter (λ (x) (> (length (ec-eqvs x)) (if (ec-val x) 0 1))) ;; if no nonvariable value discard single-variable classes
                       (map (λ (v)
                              (ec (filter (λ (x) (member x relevant))
                                          (ec-eqvs v))
                                  (replace-vars vars (ec-val v))))
                            (set->list vars)))))
      #f))

(define (query q kb [trace? #f])
  ;; get one valid solution, or #f
  (satisfy q kb #f trace?))

(define (query-gen q kb [trace? #f])
  ;; produce a generator that gets valid solutions and #f once it runs out
  (satisfy q kb #t trace?))

(define (query-all q kb [trace? #f])
  ;; get a list of valid solutions. doesn't halt if there are infinitely many
  (define (get-all g acc)
    (let [[next (g)]]
      (if next
          (get-all g (cons next acc))
          acc)))
  (let [[gen (satisfy q kb #t trace?)]]
    (reverse (get-all gen '()))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Vars Stored as Sets of Equivalence Classes
;;;;

(define (vars-add vars . ps)
  (let*-values [[(variables nonvariables) (partition variable? ps)]
                [(joined not-joined)
                          (partition (λ (v)
                                       (or (not (set-empty? (set-intersect (ec-eqvs v) variables)))
                                           (set-member? nonvariables (ec-val v))))
                                  (set->list vars))]
                [(all-nonvariables) (remove-duplicates (append nonvariables (filter-map ec-val joined)))]
                [(val-unification) (apply unify (cons vars all-nonvariables))]]
    (if val-unification
        (if (equal? (list->set (vars-merge vars val-unification)) (list->set vars))
            (set-add
             not-joined
             (ec (apply set-union (cons variables (map ec-eqvs joined)))
                 (if (empty? all-nonvariables) #f (first all-nonvariables))))
            (apply vars-add (cons (vars-merge vars val-unification) ps))) ;; recurse if any information is gained by unifying nonvariables
        #f)))


(define (vars-merge v1 v2)
  (if (and v1 v2)
      (foldl (λ (v vacc) (apply vars-add `(,vacc ,@(if (ec-val v) (list (ec-val v)) '()) ;; don't put #f in if that's the val
                                                 ,@(ec-eqvs v))))
             (set->list v1) (set->list v2))
      #f))

;;;;;;;;;;;;;
;; Provides
;;;;

(provide query
         query-gen
         query-all
         unify
         variable?
         (struct-out ec))

;; testing

(define (peek label x)
  (display (format "~a: ~a\n" label x))
  x)

;; (unify (list (ec '(X) '(c y z))) '(c A B) 'X)