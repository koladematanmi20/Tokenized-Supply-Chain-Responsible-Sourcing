;; Audit Verification Contract
;; Validates compliance assessments and audit results

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u300))
(define-constant err-not-found (err u301))
(define-constant err-unauthorized (err u302))

;; Audit status types
(define-constant audit-scheduled u0)
(define-constant audit-in-progress u1)
(define-constant audit-completed u2)
(define-constant audit-failed u3)

;; Data structures
(define-map audits
  { audit-id: uint }
  {
    supplier-id: uint,
    auditor: principal,
    audit-type: (string-ascii 50),
    scheduled-date: uint,
    completion-date: uint,
    status: uint,
    overall-score: uint,
    findings: (string-ascii 1000),
    recommendations: (string-ascii 1000)
  }
)


(define-map audit-criteria
  { audit-id: uint, criteria-id: uint }
  {
    criteria-name: (string-ascii 100),
    score: uint,
    max-score: uint,
    notes: (string-ascii 300)
  }
)

(define-map authorized-auditors
  { auditor: principal }
  { is-authorized: bool, specialization: (string-ascii 100) }
)

(define-data-var next-audit-id uint u1)

;; Authorize an auditor
(define-public (authorize-auditor (auditor principal) (specialization (string-ascii 100)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set authorized-auditors
      { auditor: auditor }
      { is-authorized: true, specialization: specialization }
    )
    (ok true)
  )
)

;; Schedule an audit
(define-public (schedule-audit
  (supplier-id uint)
  (auditor principal)
  (audit-type (string-ascii 50))
  (scheduled-date uint)
)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (default-to false (get is-authorized (map-get? authorized-auditors { auditor: auditor }))) err-unauthorized)
    (let ((audit-id (var-get next-audit-id)))
      (map-set audits
        { audit-id: audit-id }
        {
          supplier-id: supplier-id,
          auditor: auditor,
          audit-type: audit-type,
          scheduled-date: scheduled-date,
          completion-date: u0,
          status: audit-scheduled,
          overall-score: u0,
          findings: "",
          recommendations: ""
        }
      )
      (var-set next-audit-id (+ audit-id u1))
      (ok audit-id)
    )
  )
)

;; Complete an audit
(define-public (complete-audit
  (audit-id uint)
  (overall-score uint)
  (findings (string-ascii 1000))
  (recommendations (string-ascii 1000))
)
  (match (map-get? audits { audit-id: audit-id })
    audit-data
    (begin
      (asserts! (is-eq tx-sender (get auditor audit-data)) err-unauthorized)
      (map-set audits
        { audit-id: audit-id }
        (merge audit-data {
          completion-date: block-height,
          status: audit-completed,
          overall-score: overall-score,
          findings: findings,
          recommendations: recommendations
        })
      )
      (ok true)
    )
    err-not-found
  )
)

;; Add audit criteria score
(define-public (add-audit-criteria
  (audit-id uint)
  (criteria-id uint)
  (criteria-name (string-ascii 100))
  (score uint)
  (max-score uint)
  (notes (string-ascii 300))
)
  (match (map-get? audits { audit-id: audit-id })
    audit-data
    (begin
      (asserts! (is-eq tx-sender (get auditor audit-data)) err-unauthorized)
      (map-set audit-criteria
        { audit-id: audit-id, criteria-id: criteria-id }
        {
          criteria-name: criteria-name,
          score: score,
          max-score: max-score,
          notes: notes
        }
      )
      (ok true)
    )
    err-not-found
  )
)

;; Get audit details
(define-read-only (get-audit (audit-id uint))
  (map-get? audits { audit-id: audit-id })
)

;; Get audit criteria
(define-read-only (get-audit-criteria (audit-id uint) (criteria-id uint))
  (map-get? audit-criteria { audit-id: audit-id, criteria-id: criteria-id })
)

;; Check if auditor is authorized
(define-read-only (is-auditor-authorized (auditor principal))
  (default-to false (get is-authorized (map-get? authorized-auditors { auditor: auditor })))
)
