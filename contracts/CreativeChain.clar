;; Constants
(define-constant CREATIVITY_TOKEN_RESERVE u1800000)
(define-constant BASE_CREATION_REWARD u18)
(define-constant INSPIRATION_BONUS u6)
(define-constant MAX_INSPIRATION_LEVEL u12)
(define-constant ERR_INVALID_CREATION u1)
(define-constant ERR_NO_CREATIVITY_TOKENS u2)
(define-constant ERR_RESERVE_EXHAUSTED u3)
(define-constant BLOCKS_PER_CREATIVE_CYCLE u960)
(define-constant PASSION_MULTIPLIER u4)
(define-constant MIN_PASSION_DURATION u768)
(define-constant PASSION_EXIT_PENALTY u18)

;; Data Variables
(define-data-var total-creativity-tokens-minted uint u0)
(define-data-var total-creative-works uint u0)
(define-data-var creative-director principal tx-sender)

;; Data Maps
(define-map creator-works principal uint)
(define-map creator-creativity-tokens principal uint)
(define-map creation-session-start principal uint)
(define-map creator-inspiration principal uint)
(define-map creator-last-creation principal uint)
(define-map creator-passionate-tokens principal uint)
(define-map creator-passion-start-block principal uint)

;; Public Functions

(define-public (begin-creative-session (complexity uint))
  (let
    (
      (creator tx-sender)
    )
    (asserts! (> complexity u0) (err ERR_INVALID_CREATION))
    (map-set creation-session-start creator burn-block-height)
    (ok true)
  )
)

(define-public (complete-creative-work (complexity uint))
  (let
    (
      (creator tx-sender)
      (start-block (default-to u0 (map-get? creation-session-start creator)))
      (blocks-creating (- burn-block-height start-block))
      (last-creation-block (default-to u0 (map-get? creator-last-creation creator)))
      (inspiration-level (default-to u0 (map-get? creator-inspiration creator)))
      (capped-inspiration (if (<= inspiration-level MAX_INSPIRATION_LEVEL) inspiration-level MAX_INSPIRATION_LEVEL))
      (reward-amount (+ BASE_CREATION_REWARD (* capped-inspiration INSPIRATION_BONUS)))
    )
    (asserts! (and (> start-block u0) (>= blocks-creating complexity)) (err ERR_INVALID_CREATION))
    (map-set creator-works creator (+ (default-to u0 (map-get? creator-works creator)) u1))
    (map-set creator-creativity-tokens creator (+ (default-to u0 (map-get? creator-creativity-tokens creator)) reward-amount))
    (if (< (- burn-block-height last-creation-block) BLOCKS_PER_CREATIVE_CYCLE)
      (map-set creator-inspiration creator (+ inspiration-level u1))
      (map-set creator-inspiration creator u1)
    )
    (map-set creator-last-creation creator burn-block-height)
    (var-set total-creative-works (+ (var-get total-creative-works) u1))
    (var-set total-creativity-tokens-minted (+ (var-get total-creativity-tokens-minted) reward-amount))
    (asserts! (<= (var-get total-creativity-tokens-minted) CREATIVITY_TOKEN_RESERVE) (err ERR_RESERVE_EXHAUSTED))
    (ok reward-amount)
  )
)

(define-public (harvest-creativity-rewards)
  (let
    (
      (creator tx-sender)
      (token-balance (default-to u0 (map-get? creator-creativity-tokens creator)))
    )
    (asserts! (> token-balance u0) (err ERR_NO_CREATIVITY_TOKENS))
    (map-set creator-creativity-tokens creator u0)
    (ok token-balance)
  )
)

;; Passion Features

(define-public (invest-passionate-tokens (amount uint))
  (let
    (
      (creator tx-sender)
    )
    (asserts! (> amount u0) (err ERR_INVALID_CREATION))
    (asserts! (>= (var-get total-creativity-tokens-minted) amount) (err ERR_RESERVE_EXHAUSTED))
    (map-set creator-passionate-tokens creator amount)
    (map-set creator-passion-start-block creator burn-block-height)
    (var-set total-creativity-tokens-minted (- (var-get total-creativity-tokens-minted) amount))
    (ok amount)
  )
)

(define-public (retrieve-passionate-tokens)
  (let
    (
      (creator tx-sender)
      (passionate-amount (default-to u0 (map-get? creator-passionate-tokens creator)))
      (passion-start-block (default-to u0 (map-get? creator-passion-start-block creator)))
      (blocks-passionate (- burn-block-height passion-start-block))
      (penalty (if (< blocks-passionate MIN_PASSION_DURATION) (/ (* passionate-amount PASSION_EXIT_PENALTY) u100) u0))
      (final-amount (- passionate-amount penalty))
    )
    (asserts! (> passionate-amount u0) (err ERR_NO_CREATIVITY_TOKENS))
    (map-set creator-passionate-tokens creator u0)
    (map-set creator-passion-start-block creator u0)
    (var-set total-creativity-tokens-minted (+ (var-get total-creativity-tokens-minted) final-amount))
    (ok final-amount)
  )
)

;; Read-Only Functions

(define-read-only (get-creative-work-count (user principal))
  (default-to u0 (map-get? creator-works user))
)

(define-read-only (get-creativity-token-balance (user principal))
  (default-to u0 (map-get? creator-creativity-tokens user))
)

(define-read-only (get-inspiration-level (user principal))
  (default-to u0 (map-get? creator-inspiration user))
)

(define-read-only (get-creative-platform-metrics)
  {
    total-creative-works: (var-get total-creative-works),
    total-creativity-tokens-minted: (var-get total-creativity-tokens-minted)
  }
)

;; Private Functions

(define-private (is-creative-director)
  (is-eq tx-sender (var-get creative-director))
)
