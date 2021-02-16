# logic programming for racket
This is a library for racket that allows logic programming in a prolog-like language inside more general programs - knowledgebases are first-class objects
that can be programmatically manipulated in racket, and then you make queries against them.

### language
The language is, I believe, different from prolog in only three ways:
* s-expression syntax, so instead of `p(X) :- q(X)` you write `(:- (p X) (q X))`
* no cut (`!`) is available
* only five builtin predicates are available: `and`, `or` and `=` which behave as expected, `unprovable` which is equivalent to prolog's `not` and `\\=` which is equivalent to prolog's `\=` (because racket allows backslashes as escapes in symbols)

Full documentation is provided by `logic-programming.scrbl`.
