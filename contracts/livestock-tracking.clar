;; Livestock Identity & Ownership Registry Smart Contract
;; Implements comprehensive livestock tracking with ownership, health records, and transfer functionality
;; Uses Clarity v3 with proper error handling and data types

;; Constants and Error Codes
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_INPUT (err u103))
(define-constant ERR_TRANSFER_FAILED (err u104))
(define-constant ERR_NOT_OWNER (err u105))

;; Data Variables
(define-data-var next-livestock-id uint u1)
(define-data-var contract-uri (string-ascii 256) "https://livestock-registry.com")

;; Maps for livestock data
(define-map livestock-registry
  uint
  {
    animal-type: (string-ascii 50),
    breed: (string-ascii 50),
    birth-date: uint,
    gender: (string-ascii 10),
    weight: uint,
    location: (string-ascii 100),
    parent-ids: (optional {
      sire: uint,
      dam: uint,
    }),
    registration-date: uint,
    status: (string-ascii 20),
  }
)

(define-map livestock-ownership
  uint
  principal
)

(define-map health-records
  {
    livestock-id: uint,
    record-id: uint,
  }
  {
    veterinarian: principal,
    treatment-type: (string-ascii 100),
    treatment-date: uint,
    notes: (string-ascii 500),
    next-checkup: (optional uint),
  }
)

(define-map livestock-health-count
  uint
  uint
)

;; Transfer history tracking
(define-map transfer-history
  {
    livestock-id: uint,
    transfer-id: uint,
  }
  {
    from-owner: principal,
    to-owner: principal,
    transfer-date: uint,
    transfer-price: (optional uint),
    transfer-reason: (string-ascii 200),
  }
)

(define-map livestock-transfer-count
  uint
  uint
)

;; NFT Implementation
(define-non-fungible-token livestock uint)

;; Read-only functions for NFT-like functionality
(define-read-only (get-last-token-id)
  (ok (- (var-get next-livestock-id) u1))
)

(define-read-only (get-token-uri (livestock-id uint))
  (ok (some (var-get contract-uri)))
)

(define-read-only (get-owner (livestock-id uint))
  (ok (nft-get-owner? livestock livestock-id))
)

;; Core Functions

;; Register new livestock
(define-public (register-livestock
    (animal-type (string-ascii 50))
    (breed (string-ascii 50))
    (birth-date uint)
    (gender (string-ascii 10))
    (weight uint)
    (location (string-ascii 100))
    (parent-ids (optional {
      sire: uint,
      dam: uint,
    }))
  )
  (let (
      (livestock-id (var-get next-livestock-id))
      (current-block-height stacks-block-height)
    )
    ;; Validate inputs
    (asserts! (> (len animal-type) u0) ERR_INVALID_INPUT)
    (asserts! (> (len breed) u0) ERR_INVALID_INPUT)
    (asserts! (> weight u0) ERR_INVALID_INPUT)
    (asserts!
      (or
        (is-eq gender "male")
        (is-eq gender "female")
        (is-eq gender "unknown")
      )
      ERR_INVALID_INPUT
    )

    ;; Register livestock data
    (map-set livestock-registry livestock-id {
      animal-type: animal-type,
      breed: breed,
      birth-date: birth-date,
      gender: gender,
      weight: weight,
      location: location,
      parent-ids: parent-ids,
      registration-date: current-block-height,
      status: "active",
    })

    ;; Mint NFT to sender
    (try! (nft-mint? livestock livestock-id tx-sender))
    (map-set livestock-ownership livestock-id tx-sender)

    ;; Initialize counters
    (map-set livestock-health-count livestock-id u0)
    (map-set livestock-transfer-count livestock-id u0)

    ;; Increment livestock ID counter
    (var-set next-livestock-id (+ livestock-id u1))

    (ok livestock-id)
  )
)

;; Transfer livestock ownership
(define-public (transfer-livestock
    (livestock-id uint)
    (new-owner principal)
    (transfer-price (optional uint))
    (transfer-reason (string-ascii 200))
  )
  (let (
      (current-owner (unwrap! (nft-get-owner? livestock livestock-id) ERR_NOT_FOUND))
      (transfer-count (default-to u0 (map-get? livestock-transfer-count livestock-id)))
    )
    ;; Verify sender is current owner
    (asserts! (is-eq tx-sender current-owner) ERR_NOT_OWNER)
    (asserts! (not (is-eq current-owner new-owner)) ERR_INVALID_INPUT)

    ;; Transfer NFT
    (try! (nft-transfer? livestock livestock-id current-owner new-owner))
    (map-set livestock-ownership livestock-id new-owner)

    ;; Record transfer history
    (map-set transfer-history {
      livestock-id: livestock-id,
      transfer-id: transfer-count,
    } {
      from-owner: current-owner,
      to-owner: new-owner,
      transfer-date: stacks-block-height,
      transfer-price: transfer-price,
      transfer-reason: transfer-reason,
    })

    ;; Update transfer counter
    (map-set livestock-transfer-count livestock-id (+ transfer-count u1))

    (ok true)
  )
)

;; Add health record
(define-public (add-health-record
    (livestock-id uint)
    (veterinarian principal)
    (treatment-type (string-ascii 100))
    (notes (string-ascii 500))
    (next-checkup (optional uint))
  )
  (let (
      (owner (unwrap! (map-get? livestock-ownership livestock-id) ERR_NOT_FOUND))
      (health-count (default-to u0 (map-get? livestock-health-count livestock-id)))
    )
    ;; Verify sender is owner or veterinarian
    (asserts! (or (is-eq tx-sender owner) (is-eq tx-sender veterinarian))
      ERR_UNAUTHORIZED
    )
    (asserts! (> (len treatment-type) u0) ERR_INVALID_INPUT)

    ;; Add health record
    (map-set health-records {
      livestock-id: livestock-id,
      record-id: health-count,
    } {
      veterinarian: veterinarian,
      treatment-type: treatment-type,
      treatment-date: stacks-block-height,
      notes: notes,
      next-checkup: next-checkup,
    })

    ;; Update health record counter
    (map-set livestock-health-count livestock-id (+ health-count u1))

    (ok health-count)
  )
)

;; Update livestock status
(define-public (update-livestock-status
    (livestock-id uint)
    (new-status (string-ascii 20))
  )
  (let (
      (owner (unwrap! (map-get? livestock-ownership livestock-id) ERR_NOT_FOUND))
      (livestock-data (unwrap! (map-get? livestock-registry livestock-id) ERR_NOT_FOUND))
    )
    ;; Verify sender is owner
    (asserts! (is-eq tx-sender owner) ERR_NOT_OWNER)
    (asserts! (> (len new-status) u0) ERR_INVALID_INPUT)

    ;; Update livestock status
    (map-set livestock-registry livestock-id
      (merge livestock-data { status: new-status })
    )

    (ok true)
  )
)

;; Read-only functions

(define-read-only (get-livestock-details (livestock-id uint))
  (map-get? livestock-registry livestock-id)
)

(define-read-only (get-livestock-owner (livestock-id uint))
  (map-get? livestock-ownership livestock-id)
)

(define-read-only (get-health-record
    (livestock-id uint)
    (record-id uint)
  )
  (map-get? health-records {
    livestock-id: livestock-id,
    record-id: record-id,
  })
)

(define-read-only (get-health-record-count (livestock-id uint))
  (default-to u0 (map-get? livestock-health-count livestock-id))
)

(define-read-only (get-transfer-record
    (livestock-id uint)
    (transfer-id uint)
  )
  (map-get? transfer-history {
    livestock-id: livestock-id,
    transfer-id: transfer-id,
  })
)

(define-read-only (get-transfer-count (livestock-id uint))
  (default-to u0 (map-get? livestock-transfer-count livestock-id))
)

(define-read-only (get-next-livestock-id)
  (var-get next-livestock-id)
)

;; Admin functions (contract owner only)

(define-public (set-contract-uri (new-uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set contract-uri new-uri)
    (ok true)
  )
)

(define-public (emergency-status-update
    (livestock-id uint)
    (new-status (string-ascii 20))
    (reason (string-ascii 200))
  )
  (let ((livestock-data (unwrap! (map-get? livestock-registry livestock-id) ERR_NOT_FOUND)))
    ;; Only contract owner can make emergency updates
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> (len new-status) u0) ERR_INVALID_INPUT)
    (asserts! (> (len reason) u0) ERR_INVALID_INPUT)

    ;; Update status
    (map-set livestock-registry livestock-id
      (merge livestock-data { status: new-status })
    )

    ;; Log emergency update as health record
    (try! (add-health-record livestock-id CONTRACT_OWNER
      (concat "EMERGENCY_UPDATE: " new-status) reason none
    ))

    (ok true)
  )
)

(define-map attr-values
  {
    id: uint,
    owner: principal,
    key: (string-utf8 64),
  }
  (string-utf8 256)
)

(define-map attr-counts
  { id: uint }
  uint
)

(define-map attr-index
  {
    id: uint,
    index: uint,
  }
  {
    owner: principal,
    key: (string-utf8 64),
  }
)

(define-public (set-attribute
    (id uint)
    (key (string-utf8 64))
    (value (string-utf8 256))
  )
  (let ((existing (map-get? attr-values {
      id: id,
      owner: tx-sender,
      key: key,
    })))
    (if (is-some existing)
      (begin
        (map-set attr-values {
          id: id,
          owner: tx-sender,
          key: key,
        }
          value
        )
        (ok true)
      )
      (let ((count (default-to u0 (map-get? attr-counts { id: id }))))
        (begin
          (map-set attr-values {
            id: id,
            owner: tx-sender,
            key: key,
          }
            value
          )
          (map-set attr-index {
            id: id,
            index: count,
          } {
            owner: tx-sender,
            key: key,
          })
          (map-set attr-counts { id: id } (+ count u1))
          (ok true)
        )
      )
    )
  )
)

(define-read-only (get-attribute
    (id uint)
    (owner principal)
    (key (string-utf8 64))
  )
  (map-get? attr-values {
    id: id,
    owner: owner,
    key: key,
  })
)

(define-read-only (get-attribute-count (id uint))
  (default-to u0 (map-get? attr-counts { id: id }))
)

(define-read-only (get-attribute-key
    (id uint)
    (index uint)
  )
  (map-get? attr-index {
    id: id,
    index: index,
  })
)
