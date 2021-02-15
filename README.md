# logic programming for racket
This is a library for racket that allows logic programming in a prolog-like language inside more general programs - knowledgebases are first-class objects
that can be programmatically manipulated in racket, and then you make queries against them.

### language
The language is, I believe, different from prolog in only three ways:
* s-expression syntax, so instead of `p(X) :- q(X)` you write `(:- (p X) (q X))`
* no cut (`!`) is available
* only five builtin predicates are available: `and`, `or` and `=` which behave as expected, `unprovable` which is equivalet to prolog's `not` and `\\=` which is equivalent to prolog's `\=` (because racket allows backslashes as escapes in symbols)

### use
The library provides two functions and a struct:
* `(variable? v)` returns `#t` if v is a symbol whose first character is an uppercase letter, `#f` otherwise
* `(query q kb [generator? #f] [trace? #f])` attempts to prove predicate `q` on knowledgebase `kb`, where `q` is a quoted s-exp representing a predicate and `kb` is a quoted s-exp representing a list of predicates and conditionals, like so: `(query '(p X) '((:- (p X) (q X)) (q a)))`.
The optional argument `generator?` specifies whether `query` should return the first set of variable unifications it finds to satisfy the query (or #f if there aren't any) or a generator that returns each possible such set in turn.
`trace?` specifies whether to print information about each subgoal during the query process.
* The struct `(ec vars val)` (for equivalence class) holds a list of symbols which are variable names that are equivalent to each other (`ec-vars`) and an s-exp (or #f) which is the value those variables hold if applicable.
For instance, the result of the example query given above would be `(set (ec '(X) 'a))`

Full documentation will soon be included in a scrbl
