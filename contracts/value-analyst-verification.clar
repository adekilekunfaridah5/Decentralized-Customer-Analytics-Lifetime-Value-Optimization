;; Value Analyst Verification Contract
;; Manages verification and reputation of customer value analysts

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ANALYST-EXISTS (err u101))
(define-constant ERR-ANALYST-NOT-FOUND (err u102))
(define-constant ERR-INVALID-REPUTATION (err u103))
(define-constant ERR-INSUFFICIENT-STAKE (err u104))

;; Data Variables
(define-data-var min-stake-amount uint u1000000) ;; 1 STX minimum stake
(define-data-var verification-threshold uint u75) ;; 75% accuracy threshold

;; Data Maps
(define-map analysts principal {
    verified: bool,
    reputation-score: uint,
    total-predictions: uint,
    correct-predictions: uint,
    stake-amount: uint,
    registration-block: uint
})

(define-map analyst-performance principal {
    last-30-days-accuracy: uint,
    total-value-calculated: uint,
    specialization: (string-ascii 50)
})

;; Public Functions

;; Register as a new analyst
(define-public (register-analyst (stake-amount uint) (specialization (string-ascii 50)))
    (let ((caller tx-sender))
        (asserts! (>= stake-amount (var-get min-stake-amount)) ERR-INSUFFICIENT-STAKE)
        (asserts! (is-none (map-get? analysts caller)) ERR-ANALYST-EXISTS)

        ;; Store analyst data
        (map-set analysts caller {
            verified: false,
            reputation-score: u50, ;; Start with neutral reputation
            total-predictions: u0,
            correct-predictions: u0,
            stake-amount: stake-amount,
            registration-block: block-height
        })

        (map-set analyst-performance caller {
            last-30-days-accuracy: u0,
            total-value-calculated: u0,
            specialization: specialization
        })

        (ok true)
    )
)

;; Verify an analyst (only by contract owner or verified analysts)
(define-public (verify-analyst (analyst principal))
    (let ((caller tx-sender)
          (analyst-data (unwrap! (map-get? analysts analyst) ERR-ANALYST-NOT-FOUND)))

        ;; Check authorization
        (asserts! (or (is-eq caller CONTRACT-OWNER)
                     (is-verified-analyst caller)) ERR-NOT-AUTHORIZED)

        ;; Update verification status
        (map-set analysts analyst (merge analyst-data { verified: true }))

        (ok true)
    )
)

;; Update analyst reputation based on prediction accuracy
(define-public (update-reputation (analyst principal) (was-correct bool))
    (let ((analyst-data (unwrap! (map-get? analysts analyst) ERR-ANALYST-NOT-FOUND))
          (new-total (+ (get total-predictions analyst-data) u1))
          (new-correct (if was-correct
                          (+ (get correct-predictions analyst-data) u1)
                          (get correct-predictions analyst-data))))

        ;; Calculate new reputation score (0-100 scale)
        (let ((new-reputation (if (> new-total u0)
                                 (/ (* new-correct u100) new-total)
                                 u50)))

            (map-set analysts analyst (merge analyst-data {
                total-predictions: new-total,
                correct-predictions: new-correct,
                reputation-score: new-reputation
            }))

            (ok new-reputation)
        )
    )
)

;; Read-only Functions

;; Check if an analyst is verified
(define-read-only (is-verified-analyst (analyst principal))
    (match (map-get? analysts analyst)
        analyst-data (get verified analyst-data)
        false
    )
)

;; Get analyst reputation score
(define-read-only (get-analyst-reputation (analyst principal))
    (match (map-get? analysts analyst)
        analyst-data (get reputation-score analyst-data)
        u0
    )
)

;; Get analyst details
(define-read-only (get-analyst-details (analyst principal))
    (map-get? analysts analyst)
)

;; Get analyst performance metrics
(define-read-only (get-analyst-performance (analyst principal))
    (map-get? analyst-performance analyst)
)

;; Check if analyst meets verification threshold
(define-read-only (meets-verification-threshold (analyst principal))
    (match (map-get? analysts analyst)
        analyst-data (>= (get reputation-score analyst-data) (var-get verification-threshold))
        false
    )
)

;; Get minimum stake requirement
(define-read-only (get-min-stake-amount)
    (var-get min-stake-amount)
)

;; Administrative Functions (Contract Owner Only)

;; Update minimum stake amount
(define-public (set-min-stake-amount (new-amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set min-stake-amount new-amount)
        (ok true)
    )
)

;; Update verification threshold
(define-public (set-verification-threshold (new-threshold uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (<= new-threshold u100) ERR-INVALID-REPUTATION)
        (var-set verification-threshold new-threshold)
        (ok true)
    )
)
