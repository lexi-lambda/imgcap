#lang curly-fn racket/base

(require (prefix-in env: "environment.rkt")

         json
         net/url
         racket/format
         racket/list
         racket/runtime-path
         web-server/dispatch
         web-server/http/xexpr
         web-server/servlet-env
         "lib/sanitize.rkt"
         "lib/xexpr.rkt")

(define imgur-headers
  (list (format "Authorization: Client-ID ~a" env:imgur-client-id)
        "Accept: application/json"))

(define (imgur-get-album album-id)
  (hash-ref (read-json
             (get-pure-port
              (string->url (format "https://api.imgur.com/3/album/~a" album-id))
              imgur-headers))
            'data))

(define (json-null-or val default)
  (if (eq? (json-null) val) default val))

(define (show-album req album-id)
  (let* ([album (imgur-get-album album-id)]
         [title (json-null-or (hash-ref album 'title) #f)])
    (response/xexpr
     #:preamble #"<!DOCTYPE html>"
     `(html
       (head (title ,(~a (if title (~a title " | ") "")
                         "imgcap"))
             (link [[rel "stylesheet"] [href "/assets/styles/main.css"]]))
       (body
        (div [[class "album"]]
             ,@(for/list ([image (in-list (hash-ref album 'images))])
                 `(div [[class "album--image"]]
                       (div [[class "album--image_image"]]
                            (img [[src ,(hash-ref image 'link)]]))
                       (div [[class "album--image_description"]]
                            (div [[class "image-description"]]
                                 ,(let ([description (json-null-or (hash-ref image 'description) "")])
                                    (map process-xexpr (sanitize-markdown description)))))))))))))

(define-values [server-dispatch server-url]
  (dispatch-rules
   [("album" (string-arg)) show-album]))

;; ---------------------------------------------------------------------------------------------------

(define-runtime-path public-path "public")

(serve/servlet server-dispatch
               #:port env:port
               #:launch-browser? #f
               #:listen-ip #f
               #:servlet-regexp #rx""
               #:extra-files-paths (list public-path))
