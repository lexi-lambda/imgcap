#lang racket/base

(require data/maybe
         (only-in markdown parse-markdown)
         net/url
         racket/contract
         racket/list
         racket/match
         txexpr)

(provide
 (contract-out
  [sanitize-html (xexpr? . -> . (maybe/c xexpr?))]
  [sanitize-markdown (string? . -> . xexpr?)]))

;; ---------------------------------------------------------------------------------------------------

(define-logger sanitizer)

(define (sanitize-html xexpr)
  (match xexpr
    [(? txexpr? (app txexpr->values tag attrs elems))
     (case tag
       [(script style)
        (log-sanitizer-debug "stripping element ~v" tag)
        nothing]
       [(div span p h1 h2 h3 h4 h5 h6 ul ol li dl dt dd
         i b u em strong a img code pre blockquote hr br)
        (just (txexpr tag (filter (valid-attribute? tag) attrs)
                      (map-maybe sanitize-html elems)))]
       [else
        (log-sanitizer-debug "replacing element ~v" tag)
        (just (txexpr 'div '() (map-maybe sanitize-html elems)))])]
    [other (just other)]))

(define (valid-attribute? tag)
  (define (strip-attr/log attr)
    (log-sanitizer-debug "stripping attribute ~v" attr)
    #f)

  (case tag
    [(a)
     (λ (attr)
       (case (first attr)
         [(href) (valid-url? (second attr))]
         [else (strip-attr/log attr)]))]
    [(img)
     (λ (attr)
       (case (first attr)
         [(src) (valid-url? (second attr))]
         [else (strip-attr/log attr)]))]
    [else strip-attr/log]))

(define (valid-url? href-url)
  (let* ([url (string->url href-url)]
         [scheme (url-scheme url)]
         [result (and (string? scheme)
                      (or (string-ci=? scheme "http")
                          (string-ci=? scheme "https")))])
    (unless result
      (log-sanitizer-debug "stripping invalid url ~v" url))
    result))

;; ---------------------------------------------------------------------------------------------------

(define (sanitize-markdown str)
  (from-just! (sanitize-html `(div ,@(parse-markdown str)))))

;; ---------------------------------------------------------------------------------------------------

(module+ test
  (require rackunit)

  (define (purify-markdown str)
    (xexpr->string (sanitize-markdown str)))

  (check-equal? (purify-markdown #<<MD
';alert(String.fromCharCode(88,83,83))//';alert(String.fromCharCode(88,83,83))//";
alert(String.fromCharCode(88,83,83))//";alert(String.fromCharCode(88,83,83))//--
></SCRIPT>">'><SCRIPT>alert(String.fromCharCode(88,83,83))</SCRIPT>
MD
                                 )
                #<<HTML
<div><p>&rsquo;;alert(String.fromCharCode(88,83,83))//&rsquo;;alert(String.fromCharCode(88,83,83))//"; alert(String.fromCharCode(88,83,83))//";alert(String.fromCharCode(88,83,83))//&mdash; &gt;"&gt;&rsquo;&gt;</p></div>
HTML
                )

  (check-equal? (purify-markdown #<<MD
'';!--"<XSS>=&{()}
MD
                                 )
                #<<HTML
<div><p>&rsquo;&rsquo;;!&mdash;"=&amp;{()}</p></div>
HTML
                )

  (check-equal? (purify-markdown #<<MD
<SCRIPT SRC="http://xss.rocks/xss.js"></SCRIPT>
MD
                                 )
                #<<HTML
<div></div>
HTML
                )

  (check-equal? (purify-markdown #<<MD
<A HREF="javascript:document.location='http://www.google.com/'">XSS</A>
MD
                                 )
                #<<HTML
<div><p><a>XSS</a></p></div>
HTML
                ))
