;; Livestock Identity & Ownership Registry

(define-data-var last-livestock-id uint u0)

(define-map livestock-registry
    { id: uint }
    {
        owner: principal,
        species: (string-ascii 20),
        breed: (string-ascii 30),
        birth-date: uint,
        nfc-chip-id: (string-ascii 64),
        registered-at: uint,
    }
)

(define-map livestock-health-records
    {
        livestock-id: uint,
        record-id: uint,
    }
    {
        vet-principal: principal,
        treatment-date: uint,
        treatment-type: (string-ascii 50),
        notes: (string-utf8 500),
        recorded-at: uint,
    }
)

(define-map livestock-ownership-history
    {
        livestock-id: uint,
        transfer-id: uint,
    }
    {
        from: principal,
        to: principal,
        transfer-date: uint,
        price: uint,
        notes: (string-utf8 200),
    }
)

(define-map livestock-health-last-record-id
    { livestock-id: uint }
    { last-record-id: uint }
)

(define-map livestock-ownership-last-transfer-id
    { livestock-id: uint }
    { last-transfer-id: uint }
)

(define-read-only (get-livestock (id uint))
    (map-get? livestock-registry { id: id })
)

(define-read-only (get-livestock-health-record
        (livestock-id uint)
        (record-id uint)
    )
    (map-get? livestock-health-records {
        livestock-id: livestock-id,
        record-id: record-id,
    })
)

(define-read-only (get-livestock-ownership-record
        (livestock-id uint)
        (transfer-id uint)
    )
    (map-get? livestock-ownership-history {
        livestock-id: livestock-id,
        transfer-id: transfer-id,
    })
)

(define-read-only (get-last-livestock-id)
    (var-get last-livestock-id)
)

(define-read-only (get-last-health-record-id (livestock-id uint))
    (default-to { last-record-id: u0 }
        (map-get? livestock-health-last-record-id { livestock-id: livestock-id })
    )
)

(define-read-only (get-last-transfer-id (livestock-id uint))
    (default-to { last-transfer-id: u0 }
        (map-get? livestock-ownership-last-transfer-id { livestock-id: livestock-id })
    )
)

(define-read-only (check-livestock-owner
        (id uint)
        (owner principal)
    )
    (let ((livestock-data (map-get? livestock-registry { id: id })))
        (if (is-some livestock-data)
            (is-eq owner (get owner (unwrap-panic livestock-data)))
            false
        )
    )
)

(define-public (register-livestock
        (species (string-ascii 20))
        (breed (string-ascii 30))
        (birth-date uint)
        (nfc-chip-id (string-ascii 64))
    )
    (let ((new-id (+ (var-get last-livestock-id) u1)))
        (var-set last-livestock-id new-id)
        (map-set livestock-registry { id: new-id } {
            owner: tx-sender,
            species: species,
            breed: breed,
            birth-date: birth-date,
            nfc-chip-id: nfc-chip-id,
            registered-at: burn-block-height,
        })
        (ok new-id)
    )
)

(define-public (add-health-record
        (livestock-id uint)
        (treatment-type (string-ascii 50))
        (notes (string-utf8 500))
    )
    (let (
            (livestock-data (map-get? livestock-registry { id: livestock-id }))
            (last-record (get-last-health-record-id livestock-id))
            (new-record-id (+ (get last-record-id last-record) u1))
        )
        (asserts! (is-some livestock-data) (err u404))
        (asserts! (is-eq tx-sender (get owner (unwrap-panic livestock-data)))
            (err u403)
        )
        (map-set livestock-health-records {
            livestock-id: livestock-id,
            record-id: new-record-id,
        } {
            vet-principal: tx-sender,
            treatment-date: burn-block-height,
            treatment-type: treatment-type,
            notes: notes,
            recorded-at: burn-block-height,
        })
        (map-set livestock-health-last-record-id { livestock-id: livestock-id } { last-record-id: new-record-id })
        (ok new-record-id)
    )
)
(define-public (transfer-ownership
        (livestock-id uint)
        (new-owner principal)
        (price uint)
        (notes (string-utf8 200))
    )
    (let (
            (livestock-data (map-get? livestock-registry { id: livestock-id }))
            (last-transfer (get-last-transfer-id livestock-id))
            (new-transfer-id (+ (get last-transfer-id last-transfer) u1))
        )
        (asserts! (is-some livestock-data) (err u404))
        (asserts! (is-eq tx-sender (get owner (unwrap-panic livestock-data)))
            (err u403)
        )
        (asserts! (not (is-eq tx-sender new-owner)) (err u400))
        (map-set livestock-ownership-history {
            livestock-id: livestock-id,
            transfer-id: new-transfer-id,
        } {
            from: tx-sender,
            to: new-owner,
            transfer-date: burn-block-height,
            price: price,
            notes: notes,
        })
        (map-set livestock-registry { id: livestock-id }
            (merge (unwrap-panic livestock-data) { owner: new-owner })
        )
        (map-set livestock-ownership-last-transfer-id { livestock-id: livestock-id } { last-transfer-id: new-transfer-id })
        (ok new-transfer-id)
    )
)
(define-public (update-nfc-chip
        (livestock-id uint)
        (new-nfc-chip-id (string-ascii 64))
    )
    (let ((livestock-data (map-get? livestock-registry { id: livestock-id })))
        (asserts! (is-some livestock-data) (err u404))
        (asserts! (is-eq tx-sender (get owner (unwrap-panic livestock-data)))
            (err u403)
        )
        (map-set livestock-registry { id: livestock-id }
            (merge (unwrap-panic livestock-data) { nfc-chip-id: new-nfc-chip-id })
        )
        (ok true)
    )
)
