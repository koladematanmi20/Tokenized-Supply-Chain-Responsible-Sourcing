;; Sourcing Standards Contract
;; Records and manages responsible procurement requirements

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-already-exists (err u202))

;; Standard categories
(define-constant category-environmental u1)
(define-constant category-labor u2)
(define-constant category-ethical u3)
(define-constant category-quality u4)

;; Data structures
(define-map standards
  { standard-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    category: uint,
    requirements: (string-ascii 1000),
    minimum-score: uint,
    created-by: principal,
    created-at: uint,
    is-active: bool
  }
)

(define-map supplier-standards
  { supplier-id: uint, standard-id: uint }
  {
    compliance-score: uint,
    last-assessed: uint,
    assessor: principal,
    notes: (string-ascii 500)
  }
)

(define-data-var next-standard-id uint u1)

;; Create a new sourcing standard
(define-public (create-standard
  (title (string-ascii 100))
  (description (string-ascii 500))
  (category uint)
  (requirements (string-ascii 1000))
  (minimum-score uint)
)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (let ((standard-id (var-get next-standard-id)))
      (map-set standards
        { standard-id: standard-id }
        {
          title: title,
          description: description,
          category: category,
          requirements: requirements,
          minimum-score: minimum-score,
          created-by: tx-sender,
          created-at: block-height,
          is-active: true
        }
      )
      (var-set next-standard-id (+ standard-id u1))
      (ok standard-id)
    )
  )
)

;; Assess supplier against a standard
(define-public (assess-supplier-standard
  (supplier-id uint)
  (standard-id uint)
  (compliance-score uint)
  (notes (string-ascii 500))
)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-some (map-get? standards { standard-id: standard-id })) err-not-found)
    (map-set supplier-standards
      { supplier-id: supplier-id, standard-id: standard-id }
      {
        compliance-score: compliance-score,
        last-assessed: block-height,
        assessor: tx-sender,
        notes: notes
      }
    )
    (ok true)
  )
)

;; Get standard details
(define-read-only (get-standard (standard-id uint))
  (map-get? standards { standard-id: standard-id })
)

;; Get supplier's compliance with a standard
(define-read-only (get-supplier-standard-compliance (supplier-id uint) (standard-id uint))
  (map-get? supplier-standards { supplier-id: supplier-id, standard-id: standard-id })
)

;; Check if supplier meets standard requirements
(define-read-only (meets-standard-requirements (supplier-id uint) (standard-id uint))
  (match (map-get? standards { standard-id: standard-id })
    standard-data
    (match (map-get? supplier-standards { supplier-id: supplier-id, standard-id: standard-id })
      compliance-data
      (>= (get compliance-score compliance-data) (get minimum-score standard-data))
      false
    )
    false
  )
)
