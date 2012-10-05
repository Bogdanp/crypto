;; Copyright 2012 Ryan Culpepper
;; Copyright 2007-2009 Dimitris Vyzovitis <vyzo at media.mit.edu>
;; 
;; This library is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Lesser General Public License as published
;; by the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;; 
;; This library is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU Lesser General Public License for more details.
;; 
;; You should have received a copy of the GNU Lesser General Public License
;; along with this library.  If not, see <http://www.gnu.org/licenses/>.

#lang racket/base
(require racket/class
         racket/dict
         rackunit
         "../private/common/functions.rkt"
         "util.rkt")
(provide test-digests
         digest-names
         digest-inputs)

(define (test-digest/in+out di in out)
  (test-case (format "~a: ~s" (send di get-name) in)
    (check-equal? (digest di in) out)
    (check-equal? (digest di (open-input-bytes in)) out)
    (let ([ctx (make-digest-ctx di)])
      (digest-update! ctx in)
      (check-equal? (digest-peek-final ctx) out)
      (check-equal? (digest-final ctx) out))
    (let* ([r 57]
           [in* (bytes-append (make-bytes r 65) in (make-bytes r 66))])
      (let ([ctx (make-digest-ctx di)]
            [dibuf (make-bytes (digest-size di))])
        (digest-update! ctx in* r (+ r (bytes-length in)))
        (digest-final! ctx dibuf 0 (bytes-length dibuf))
        (check-equal? dibuf out))
      (let ([ctx (make-digest-ctx di)])
        (for ([i (in-range r (+ r (bytes-length in)))])
          (digest-update! ctx in* i (add1 i)))
        (check-equal? (digest-final ctx) out)))))

#|
(define (test-digest/ins+outs di ins+outs)
  (test-case (format "incremental ~a" (send di get-name))
    (let ([ctx (make-digest-ctx di)]
          [in-so-far #""])
      (for ([in+out ins+outs])
        (let ([in (car in+out)] [out (cadr in+out)])
          (digest-update! ctx in)
          (set! in-so-far (bytes-append in-so-far in))
          (let ([out-so-far (digest-peek-final ctx)])
            (check-equal? out-so-far out)
            (check-equal? out-so-far (digest in-so-far))))))))
|#

(define (test-digest-impls-agree di di-base in)
  (test-digest/in+out di in (digest di-base in)))

(define (test-hmac/in+out di key in out)
  (test-case (format "HMAC ~a: ~s" (send di get-name) in)
    (check-equal? (hmac di key in) out)
    (check-equal? (hmac di key (open-input-bytes in)) out)
    (let ([ctx (make-hmac-ctx di key)])
      (digest-update! ctx in)
      (check-equal? (digest-final ctx) out))
    (let* ([r 57]
           [in* (bytes-append (make-bytes r 65) in (make-bytes r 66))])
      (let ([ctx (make-hmac-ctx di key)]
            [dibuf (make-bytes (digest-size di))])
        (digest-update! ctx in* r (+ r (bytes-length in)))
        (digest-final! ctx dibuf 0 (bytes-length dibuf))
        (check-equal? dibuf out))
      (let ([ctx (make-hmac-ctx di key)])
        (for ([i (in-range r (+ r (bytes-length in)))])
          (digest-update! ctx in* i (add1 i)))
        (check-equal? (digest-final ctx) out)))))

(define (test-hmac-impls-agree di di-base key in)
  (test-hmac/in+out di key in (hmac di-base key in)))

;; ----

(define digest-test-vectors
  '([md5
     (#""
      #"d41d8cd98f00b204e9800998ecf8427e")
     (#"abc"
      #"900150983cd24fb0d6963f7d28e17f72")
     (#"abcdef"
      #"e80b5017098950fc58aad83c8c14978e")]
    [sha1
     (#""
      #"da39a3ee5e6b4b0d3255bfef95601890afd80709")
     (#"abc"
      #"a9993e364706816aba3e25717850c26c9cd0d89d")
     (#"abcdef"
      #"1f8ac10f23c5b5bc1167bda84b833e5c057a77d2")]
    [sha256
     (#""
      #"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
     (#"abc"
      #"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
     (#"abcdef"
      #"bef57ec7f53a6d40beb640a780a639c83bc29ac8a9816f1fc6c5c6dcd93c4721")]))

(define digest-inputs
  `(#""
    #"abc"
    #"abcdef"
    #"The cat is in the box."
    ,(semirandom-bytes 10)
    ,(semirandom-bytes 100)
    ,(semirandom-bytes 1000)
    ,(semirandom-bytes 10000)))

(define digest-keys
  `(#"secret!"
    ,(semirandom-bytes/alpha 10)
    ,(semirandom-bytes/alpha 20)
    ,(semirandom-bytes/alpha 40)))

(define digest-names
  '(sha1 md5 ripemd160 sha224 sha256 sha384 sha512))

(define (test-digests factory base-factory)
  (for ([name digest-names])
    (let ([di (send factory get-digest-by-name name)]
          [di-base (send base-factory get-digest-by-name name)])
      (when (and di di-base)
        (for ([in+out (dict-ref digest-test-vectors name null)])
          (test-digest/in+out di (car in+out) (hex->bytes (cadr in+out))))
        (for ([in digest-inputs])
          (test-digest-impls-agree di di-base in))
        (for* ([key digest-keys]
               [in digest-inputs])
          (test-hmac-impls-agree di di-base key in))))))