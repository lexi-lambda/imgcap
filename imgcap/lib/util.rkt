#lang curly-fn racket/base

(require (for-syntax racket/base
                     syntax/parse)
         data/maybe
         racket/match
         web-server/http/request-structs)

(provide form-bindings)

(define try-bytes->string/utf-8
  #{exn->maybe exn:fail:contract? bytes->string/utf-8})

(begin-for-syntax
  (define-syntax-class form-binding
    #:attributes [match-clause]
    #:literals [binding:file]
    [pattern (~and match-clause (binding:file _ ...))]
    [pattern [key str-pat]
             #:attr match-clause #'(binding:form key (app try-bytes->string/utf-8 (just str-pat)))]))

(define-match-expander form-bindings
  (syntax-parser
    [(_ binding:form-binding ...)
     #'(list-no-order binding.match-clause ...)]))
