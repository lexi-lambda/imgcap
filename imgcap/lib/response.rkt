#lang racket/base

(require (prefix-in env: "../environment.rkt")
         racket/contract
         racket/format
         web-server/http/response-structs
         web-server/http/xexpr
         xml)

(provide
 (contract-out
  [response/page ([xexpr?]
                  [#:title (or/c string? #f)
                   #:head (listof xexpr?)]
                  . ->* . response?)]))

(define google-analytics-js #<<JS
  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
  })(window,document,'script','https://www.google-analytics.com/analytics.js','ga');

  ga('create', '~a', 'auto');
  ga('require', 'linkid');
  ga('send', 'pageview');
JS
  )

(define (response/page xexpr
                       #:title [title #f]
                       #:head [head '()])
  (response/xexpr
   #:preamble #"<!DOCTYPE html>"
   `(html (head (title ,(if title (~a title " | imgcap") "imgcap"))
                ,@head
                ,@(if env:google-analytics-tracking-id
                      `((script ,(format google-analytics-js env:google-analytics-tracking-id)))
                      '()))
          (body ,xexpr))))
