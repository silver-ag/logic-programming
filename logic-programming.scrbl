#lang scribble/manual

@(require scribble/eval
          (for-label racket racket/generator parenlog web-server "main.rkt"))

@(define example-eval (make-base-eval))
@interaction-eval[#:eval example-eval
                  (require "main.rkt")]

@title{Logic Programming for Racket}

The @racket[logic-programming] library provides a prolog-like language that can be used within
racket programs. Both queries and knowledgebases are s-expressions that can be manipulated programmatically,
rather than having a single knowledgebase. The library is intended for racket programs that just need to do a bit
of logic, rather than for writing full programs in the provided language. See also the Parenlog package,
which puts less focus on programmatic modification of knowledgebases.

@section[#:tag "example"]{Example of Use}
Take the `hello world' of formal logic:

1. Socrates is a man

2. Men are mortal

3. Therefore, Socrates is mortal

We can express 1 and 2 as a knowledgebase like so:
@interaction[
 #:eval example-eval
 (define knowledgebase
   '((man socrates)
     (:- (mortal X)
         (man X))))]
Note that we can't capitalise Socrates' name because that would make him a variable. @racket[:-] might be read "if".

Now we can make queries about that information, asking questions such as "is Socrates mortal?":
@interaction[
 #:eval example-eval
 (query '(mortal socrates) knowledgebase)]
The result is a set of requirements for the query to be true, so an empty set means that it's unconditionally true.
If instead we ask "is Plato mortal?":
@interaction[
 #:eval example-eval
 (query '(mortal plato) knowledgebase)]
we get @racket[#f] - indicating not of course that Plato is provably immortal, but that given the information in
knowledgebase he can't be proven to be mortal. The distinction between provably false and unprovable is very
important in logic programming, don't forget that the question answered by @racket[query] is 'is this provable?'.

We can also ask other questions, like "who is mortal?":
@interaction[
 #:eval example-eval
 (query '(mortal X) knowledgebase)]
and "what is Socrates?" (note the use of @racket[query-all] because there's more than one answer):
@interaction[
 #:eval example-eval
 (query-all '(X socrates) knowledgebase)]

@section{Racket Reference}
@defmodule[logic-programming]

This section details the bindings provided by the library. The details of the logic language are in the section below.

@defproc[(variable? [v any/c]) boolean?]{
 Returns @racket[#t] if @racket[v] is a symbol whose first character is an uppercase letter, @racket[#f] otherwise.
 Like prolog, variables are represented as such symbols.
}

@defproc[(unify [vars (setof? ec?)] [p (not/c #f)] ...)
         (or/c (setof? ec?) #f)]{
 Returns the necessary values that @racket[variable?]s must take to render all the @racket[p]s equivalent, in
 the form of a @racket[set] of @racket[ec]s, or @racket[#f] if no variable binding could achieve that, given
 that the bindings in @racket[vars] are already fixed. Note that @racket[vars] is the sort of thing
 that both @racket[unify] and @racket[query] etc return, and that each of the @racket[p]s is a predicate
 in the logic language.
}

@defproc[(query [q (not/c #f)] [kb (listof? (not/c #f))] [trace? boolean? #f])
         (setof? ec?)]{
 Returns the necessary @racket[variable?] bindings to make @racket[q] provable given @racket[kb], or
 @racket[#f] if it can't be done. See below for the semantics of @racket[q] and @racket[kb]. If @racket[trace?]
 is true, it will print debugging information in the form "TRACE: calling <subgoal>, [<current variable bindings>]"
 for each subgoal. Note that since the logic language is turing-complete, it can't be guaranteed that
 @racket[query] will halt.
}

@defproc[(query-gen [q (not/c #f)] [kb (listof? (not/c #f))] [trace? boolean? #f])
         generator?]{
 Some queries have more than one possible solution. @racket[query-gen] works like @racket[query],
 except that it returns a generator which takes no arguments and yields each solution in turn. Once
 it runs out, it yields @racket[#f].
}

@defproc[(query-all [q (not/c #f)] [kb (listof? (not/c #f))] [trace? boolean? #f])
         (listof? (setof? ec?))]{
 Works like @racket[query-gen], except that instead of returning a generator it returns a list containing
 every possible solution at once, in the order they would be returned by @racket[query-gen]. Note that
 it's possible for a query to have infinitely many solutions, and in that case @racket[query-all] won't
 halt.
}

@defstruct[ec ([vars (listof? variable?)] [val any/c])]{
 Stands for Equivalence Class. Semantically, it represents a claim that all the members of @racket[vars]
 are equivalent to one another and that if @racket[val] is not @racket[#f] then they're also equivalent to
 @racket[val]. @racket[val] is stored separately because it's not possible for two different nonvariable
 values to be equivalent. @racket[set]s of @racket[ec]s are returned by functions like @racket[query] to
 represent the necessary equivalences to make a statement true.
}

@section{Language Reference}

The logic language provided by this library is very similar to prolog. Since it's unlikely someone
interested in using it won't have some prolog experience, it'll be easiest to describe the differences.
For use, see @secref["example"].

@subsection{syntax}
An s-expression syntax is used. Facts and Queries are written @racket['(predicate-name arg1 ... argn)], and
Rules are written @racket['(:- (predicate-name arg1 ... argn) body)], where body is a Fact (using `,'
and `;' for `and' and `or' is not possible, a Rule might look like @racket['(:- (p X) (and (q X) (r X)))]).
Don't forget to quote literal sections of this code before using it, there's no binding provided for
@italic{:-} or anything.

@subsection{defined predicates}
There are only five defined predicates (or six if you count @italic{:-}):
@itemlist[@item{@italic{and}: @racket['(and p q)] is like @italic{p,q} in prolog}
          @item{@italic{or}: @racket['(or p q)] is like @italic{p;q} in prolog}
          @item{@italic{unprovable}: equivalent to prolog's @italic{not}.
           WARNING: if you're not familiar with it, prolog's @italic{not} can be fairly unintuitive. Hopefully @racket[unprovable] better expresses what's meant by it.}
          @item{@italic{\\=}: equivalent to prolog's @italic{\=}. The double slash is because racket allows backslash escapes in symbols, so without it it'd be the same as @italic{=}}
          @item{@italic{=}: equivalent to prolog's @italic{=}. If it weren't defined by default, it could be produced by adding @racket['(= X X)] to a knowledgebase.}]
Note especially that @italic{!} is missing from this list, no cut is provided.
