;; Supplier Verification Contract
;; Validates and manages vendor information

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))

;; Supplier status types
(define-constant status-pending u0)
(define-constant status-verified u1)
(define-constant status-suspended u2)
(define-constant status-rejected u3)

;; Data structures
(define-map suppliers
  { supplier-id: uint }
  {
    name: (string-ascii 100),
    contact-info: (string-ascii 200),
    verification-status: uint,
    verified-by: principal,
    verification-date: uint,
    compliance-score: uint
  }
)

(define-map supplier-principals
  { supplier: principal }
  { supplier-id: uint }
)

(define-data-var next-supplier-id uint u1)

;; Register a new supplier
(define-public (register-supplier (name (string-ascii 100)) (contact-info (string-ascii 200)))
  (let ((supplier-id (var-get next-supplier-id)))
    (asserts! (is-none (map-get? supplier-principals { supplier: tx-sender })) err-already-exists)
    (map-set suppliers
      { supplier-id: supplier-id }
      {
        name: name,
        contact-info: contact-info,
        verification-status: status-pending,
        verified-by: contract-owner,
        verification-date: u0,
        compliance-score: u0
      }
    )
    (map-set supplier-principals { supplier: tx-sender } { supplier-id: supplier-id })
    (var-set next-supplier-id (+ supplier-id u1))
    (ok supplier-id)
  )
)

;; Verify a supplier (owner only)
(define-public (verify-supplier (supplier-id uint) (compliance-score uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (match (map-get? suppliers { supplier-id: supplier-id })
      supplier-data
      (begin
        (map-set suppliers
          { supplier-id: supplier-id }
          (merge supplier-data {
            verification-status: status-verified,
            verified-by: tx-sender,
            verification-date: block-height,
            compliance-score: compliance-score
          })
        )
        (ok true)
      )
      err-not-found
    )
  )
)

;; Get supplier information
(define-read-only (get-supplier (supplier-id uint))
  (map-get? suppliers { supplier-id: supplier-id })
)

;; Get supplier ID by principal
(define-read-only (get-supplier-id (supplier principal))
  (map-get? supplier-principals { supplier: supplier })
)

;; Check if supplier is verified
(define-read-only (is-supplier-verified (supplier-id uint))
  (match (map-get? suppliers { supplier-id: supplier-id })
    supplier-data
    (is-eq (get verification-status supplier-data) status-verified)
    false
  )
)
