#lang curly-fn racket/base

(require (prefix-in env: "environment.rkt")

         json
         net/url
         racket/format
         racket/match
         racket/runtime-path
         web-server/dispatch
         web-server/http/redirect
         web-server/http/request-structs
         web-server/servlet-env
         "lib/response.rkt"
         "lib/sanitize.rkt"
         "lib/util.rkt"
         "lib/xexpr.rkt")

(define imgur-headers
  (list (format "Authorization: Client-ID ~a" env:imgur-client-id)
        "Accept: application/json"))

(define (imgur-get-album album-id)
  (let ([response (read-json
                   (get-pure-port
                    (string->url (format "https://api.imgur.com/3/album/~a" album-id))
                    imgur-headers))])
    (match response
      [(hash-table ['status 200] ['data album] [_ _] ...)
       album]
      [(hash-table ['status 404] [_ _] ...)
       #f])))

(define (json-null-or val default)
  (if (eq? (json-null) val) default val))

(define (index req)
  (response/page
   #:title "Home"
   #:head `[(link [[rel "stylesheet"] [href "/assets/styles/index.css"]])]
   `(div [[class "page-index"]]
         (h1 "imgcap")
         (form [[method "post"] [action ,(server-url goto-album)]]
               (label [[for "album-id"]] "imgur album id: ")
               (input [[type "text"] [id "album-id"] [name "album-id"]])
               (button [[type "submit"]] "Go")))))

(define (goto-album req)
  (match (request-bindings/raw req)
    [(form-bindings [#"album-id" album-id])
     (redirect-to (server-url show-album album-id))]))

(define (show-album req album-id)
  (let ([album (imgur-get-album album-id)])
    (cond
      [album
       (define-values [images descriptions]
         (for/lists [images descriptions]
           ([image (in-list (hash-ref album 'images))])
           (values `(div [[class "album--image"]
                          [width ,(~a (hash-ref image 'width))]
                          [height ,(~a (hash-ref image 'height))]]
                         (div [[class "album--shade"]])
                         (img [[src ,(hash-ref image 'link)]]))
                   `(div [[class "album--description"]]
                         (div [[class "album--shade"]])
                         (div [[class "image-description"]]
                              ,(let ([description (json-null-or (hash-ref image 'description) "")])
                                 (map process-xexpr (sanitize-markdown description))))))))
       (response/page
        #:title (json-null-or (hash-ref album 'title) #f)
        #:head `[(meta [[name "viewport"]
                        [content ,(~a "width=device-width, initial-scale=1, "
                                      "maximum-scale=1, user-scalable=no")]])
                 (link [[rel "stylesheet"] [href "/assets/styles/album.css"]])
                 (script [[src "https://code.jquery.com/jquery-3.1.1.slim.min.js"]])
                 (script [[src "/assets/scripts/album.js"]])]
        `(div [[class "album"]]
              (div [[class "album--images"]] ,@images)
              (div [[class "album--descriptions"]] ,@descriptions)))]
      [else (not-found req #:title "Album Not Found")])))

(define (not-found req #:title [title "Not Found"])
  (response/page
   #:code 404
   #:message "Not Found"
   #:title title
   `(div (h1 ,title))))

(define-values [server-dispatch server-url]
  (dispatch-rules
   [("") index]
   [("goto-album") #:method "post" goto-album]
   [("album" (string-arg)) show-album]))

;; ---------------------------------------------------------------------------------------------------

(define-runtime-path public-path "public")

(serve/servlet server-dispatch
               #:port env:port
               #:launch-browser? #f
               #:listen-ip #f
               #:servlet-regexp #rx""
               #:extra-files-paths (list public-path)
               #:file-not-found-responder not-found)
