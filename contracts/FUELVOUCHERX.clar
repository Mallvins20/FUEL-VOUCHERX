;; =========================================================
;; FuelVoucherX
;; Smart Fuel Voucher Distribution Contract
;; Network: Stacks
;; Language: Clarity
;; Version: 1.0
;; =========================================================

;; -------------------------
;; Error Codes
;; -------------------------
(define-constant ERR-NOT-ADMIN (err u100))
(define-constant ERR-NOT-RECIPIENT (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-EXPIRED (err u103))
(define-constant ERR-REDEEMED (err u104))
(define-constant ERR-INVALID-AMOUNT (err u105))

;; -------------------------
;; Admin (Contract Owner)
;; -------------------------
(define-data-var admin principal tx-sender)

;; -------------------------
;; Voucher Counter
;; -------------------------
(define-data-var voucher-counter uint u0)

;; -------------------------
;; Voucher Storage
;; -------------------------
(define-map fuel-vouchers
  uint
  {
    recipient: principal,
    amount: uint,
    expiry: uint,
    redeemed: bool
  }
)

;; =========================================================
;; READ-ONLY FUNCTIONS
;; =========================================================

;; Get admin
(define-read-only (get-admin)
  (var-get admin)
)

;; Get voucher details
(define-read-only (get-voucher (voucher-id uint))
  (map-get? fuel-vouchers voucher-id)
)

;; Check if voucher is expired
(define-read-only (is-expired (voucher-id uint))
  (match (map-get? fuel-vouchers voucher-id)
    voucher
      (< (get expiry voucher) stacks-block-height)
    false
  )
)

;; =========================================================
;; PUBLIC FUNCTIONS
;; =========================================================

;; -------------------------
;; Issue Fuel Voucher
;; -------------------------
(define-public (issue-voucher
  (recipient principal)
  (amount uint)
  (expiry uint)
)
  (begin
    ;; Only admin can issue
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-ADMIN)

    ;; Amount must be valid
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)

    ;; Create new voucher ID
    (let ((new-id (+ (var-get voucher-counter) u1)))
      (map-set fuel-vouchers new-id {
        recipient: recipient,
        amount: amount,
        expiry: expiry,
        redeemed: false
      })
      (var-set voucher-counter new-id)
      (ok new-id)
    )
  )
)

;; -------------------------
;; Redeem Fuel Voucher
;; -------------------------
(define-public (redeem-voucher (voucher-id uint))
  (match (map-get? fuel-vouchers voucher-id)
    voucher
      (begin
        ;; Only assigned recipient can redeem
        (asserts!
          (is-eq tx-sender (get recipient voucher))
          ERR-NOT-RECIPIENT
        )

        ;; Must not be redeemed
        (asserts!
          (not (get redeemed voucher))
          ERR-REDEEMED
        )

        ;; Must not be expired
        (asserts!
          (>= (get expiry voucher) stacks-block-height)
          ERR-EXPIRED
        )

        ;; Mark as redeemed
        (map-set fuel-vouchers voucher-id
          (merge voucher { redeemed: true })
        )

        ;; Return redeemed fuel value
        (ok (get amount voucher))
      )
    ERR-NOT-FOUND
  )
)

;; -------------------------
;; Change Admin (Optional)
;; -------------------------
(define-public (change-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-ADMIN)
    (var-set admin new-admin)
    (ok true)
  )
)
