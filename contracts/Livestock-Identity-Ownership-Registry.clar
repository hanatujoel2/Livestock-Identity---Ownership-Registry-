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
(define-map livestock-breeding-records
    {
        livestock-id: uint,
        breeding-id: uint,
    }
    {
        mate-id: uint,
        breeding-date: uint,
        breeding-type: (string-ascii 20),
        expected-birth-date: uint,
        breeder: principal,
        recorded-at: uint,
    }
)

(define-map livestock-parentage
    { offspring-id: uint }
    {
        sire-id: uint,
        dam-id: uint,
        birth-date: uint,
        verified: bool,
    }
)

(define-map livestock-breeding-last-id
    { livestock-id: uint }
    { last-breeding-id: uint }
)

(define-read-only (get-breeding-record
        (livestock-id uint)
        (breeding-id uint)
    )
    (map-get? livestock-breeding-records {
        livestock-id: livestock-id,
        breeding-id: breeding-id,
    })
)

(define-read-only (get-parentage (offspring-id uint))
    (map-get? livestock-parentage { offspring-id: offspring-id })
)

(define-read-only (get-last-breeding-id (livestock-id uint))
    (default-to { last-breeding-id: u0 }
        (map-get? livestock-breeding-last-id { livestock-id: livestock-id })
    )
)

(define-public (record-breeding
        (livestock-id uint)
        (mate-id uint)
        (breeding-type (string-ascii 20))
        (expected-birth-date uint)
    )
    (let (
            (livestock-data (map-get? livestock-registry { id: livestock-id }))
            (mate-data (map-get? livestock-registry { id: mate-id }))
            (last-breeding (get-last-breeding-id livestock-id))
            (new-breeding-id (+ (get last-breeding-id last-breeding) u1))
        )
        (asserts! (is-some livestock-data) (err u404))
        (asserts! (is-some mate-data) (err u405))
        (asserts! (is-eq tx-sender (get owner (unwrap-panic livestock-data)))
            (err u403)
        )
        (asserts! (not (is-eq livestock-id mate-id)) (err u400))
        (map-set livestock-breeding-records {
            livestock-id: livestock-id,
            breeding-id: new-breeding-id,
        } {
            mate-id: mate-id,
            breeding-date: burn-block-height,
            breeding-type: breeding-type,
            expected-birth-date: expected-birth-date,
            breeder: tx-sender,
            recorded-at: burn-block-height,
        })
        (map-set livestock-breeding-last-id { livestock-id: livestock-id } { last-breeding-id: new-breeding-id })
        (ok new-breeding-id)
    )
)

(define-public (register-offspring
        (sire-id uint)
        (dam-id uint)
        (species (string-ascii 20))
        (breed (string-ascii 30))
        (birth-date uint)
        (nfc-chip-id (string-ascii 64))
    )
    (let (
            (sire-data (map-get? livestock-registry { id: sire-id }))
            (dam-data (map-get? livestock-registry { id: dam-id }))
            (new-id (+ (var-get last-livestock-id) u1))
        )
        (asserts! (is-some sire-data) (err u404))
        (asserts! (is-some dam-data) (err u405))
        (var-set last-livestock-id new-id)
        (map-set livestock-registry { id: new-id } {
            owner: tx-sender,
            species: species,
            breed: breed,
            birth-date: birth-date,
            nfc-chip-id: nfc-chip-id,
            registered-at: burn-block-height,
        })
        (map-set livestock-parentage { offspring-id: new-id } {
            sire-id: sire-id,
            dam-id: dam-id,
            birth-date: birth-date,
            verified: false,
        })
        (ok new-id)
    )
)

(define-public (verify-parentage (offspring-id uint))
    (let (
            (parentage-data (map-get? livestock-parentage { offspring-id: offspring-id }))
            (offspring-data (map-get? livestock-registry { id: offspring-id }))
        )
        (asserts! (is-some parentage-data) (err u404))
        (asserts! (is-some offspring-data) (err u405))
        (asserts! (is-eq tx-sender (get owner (unwrap-panic offspring-data)))
            (err u403)
        )
        (map-set livestock-parentage { offspring-id: offspring-id }
            (merge (unwrap-panic parentage-data) { verified: true })
        )
        (ok true)
    )
)
(define-map livestock-insurance
    { livestock-id: uint }
    {
        policy-number: (string-ascii 50),
        insurer: principal,
        coverage-amount: uint,
        premium: uint,
        start-date: uint,
        end-date: uint,
        active: bool,
    }
)

(define-map livestock-valuations
    {
        livestock-id: uint,
        valuation-id: uint,
    }
    {
        appraiser: principal,
        valuation-amount: uint,
        valuation-date: uint,
        valuation-purpose: (string-ascii 30),
        notes: (string-utf8 200),
    }
)

(define-map livestock-insurance-claims
    {
        livestock-id: uint,
        claim-id: uint,
    }
    {
        claimant: principal,
        claim-amount: uint,
        claim-date: uint,
        claim-reason: (string-ascii 50),
        status: (string-ascii 20),
        processed-by: (optional principal),
        processed-date: (optional uint),
    }
)

(define-map livestock-valuation-last-id
    { livestock-id: uint }
    { last-valuation-id: uint }
)

(define-map livestock-claim-last-id
    { livestock-id: uint }
    { last-claim-id: uint }
)

(define-read-only (get-insurance (livestock-id uint))
    (map-get? livestock-insurance { livestock-id: livestock-id })
)

(define-read-only (get-valuation
        (livestock-id uint)
        (valuation-id uint)
    )
    (map-get? livestock-valuations {
        livestock-id: livestock-id,
        valuation-id: valuation-id,
    })
)

(define-read-only (get-insurance-claim
        (livestock-id uint)
        (claim-id uint)
    )
    (map-get? livestock-insurance-claims {
        livestock-id: livestock-id,
        claim-id: claim-id,
    })
)

(define-read-only (get-last-valuation-id (livestock-id uint))
    (default-to { last-valuation-id: u0 }
        (map-get? livestock-valuation-last-id { livestock-id: livestock-id })
    )
)

(define-read-only (get-last-claim-id (livestock-id uint))
    (default-to { last-claim-id: u0 }
        (map-get? livestock-claim-last-id { livestock-id: livestock-id })
    )
)

(define-public (create-insurance-policy
        (livestock-id uint)
        (policy-number (string-ascii 50))
        (coverage-amount uint)
        (premium uint)
        (duration-blocks uint)
    )
    (let ((livestock-data (map-get? livestock-registry { id: livestock-id })))
        (asserts! (is-some livestock-data) (err u404))
        (asserts! (is-eq tx-sender (get owner (unwrap-panic livestock-data)))
            (err u403)
        )
        (asserts! (> coverage-amount u0) (err u400))
        (map-set livestock-insurance { livestock-id: livestock-id } {
            policy-number: policy-number,
            insurer: tx-sender,
            coverage-amount: coverage-amount,
            premium: premium,
            start-date: burn-block-height,
            end-date: (+ burn-block-height duration-blocks),
            active: true,
        })
        (ok true)
    )
)

(define-public (add-valuation
        (livestock-id uint)
        (valuation-amount uint)
        (valuation-purpose (string-ascii 30))
        (notes (string-utf8 200))
    )
    (let (
            (livestock-data (map-get? livestock-registry { id: livestock-id }))
            (last-valuation (get-last-valuation-id livestock-id))
            (new-valuation-id (+ (get last-valuation-id last-valuation) u1))
        )
        (asserts! (is-some livestock-data) (err u404))
        (asserts! (> valuation-amount u0) (err u400))
        (map-set livestock-valuations {
            livestock-id: livestock-id,
            valuation-id: new-valuation-id,
        } {
            appraiser: tx-sender,
            valuation-amount: valuation-amount,
            valuation-date: burn-block-height,
            valuation-purpose: valuation-purpose,
            notes: notes,
        })
        (map-set livestock-valuation-last-id { livestock-id: livestock-id } { last-valuation-id: new-valuation-id })
        (ok new-valuation-id)
    )
)

(define-public (file-insurance-claim
        (livestock-id uint)
        (claim-amount uint)
        (claim-reason (string-ascii 50))
    )
    (let (
            (livestock-data (map-get? livestock-registry { id: livestock-id }))
            (insurance-data (map-get? livestock-insurance { livestock-id: livestock-id }))
            (last-claim (get-last-claim-id livestock-id))
            (new-claim-id (+ (get last-claim-id last-claim) u1))
        )
        (asserts! (is-some livestock-data) (err u404))
        (asserts! (is-some insurance-data) (err u405))
        (asserts! (is-eq tx-sender (get owner (unwrap-panic livestock-data)))
            (err u403)
        )
        (asserts! (get active (unwrap-panic insurance-data)) (err u406))
        (asserts!
            (<= claim-amount (get coverage-amount (unwrap-panic insurance-data)))
            (err u407)
        )
        (map-set livestock-insurance-claims {
            livestock-id: livestock-id,
            claim-id: new-claim-id,
        } {
            claimant: tx-sender,
            claim-amount: claim-amount,
            claim-date: burn-block-height,
            claim-reason: claim-reason,
            status: "pending",
            processed-by: none,
            processed-date: none,
        })
        (map-set livestock-claim-last-id { livestock-id: livestock-id } { last-claim-id: new-claim-id })
        (ok new-claim-id)
    )
)

(define-public (process-insurance-claim
        (livestock-id uint)
        (claim-id uint)
        (new-status (string-ascii 20))
    )
    (let (
            (claim-data (map-get? livestock-insurance-claims {
                livestock-id: livestock-id,
                claim-id: claim-id,
            }))
            (insurance-data (map-get? livestock-insurance { livestock-id: livestock-id }))
        )
        (asserts! (is-some claim-data) (err u404))
        (asserts! (is-some insurance-data) (err u405))
        (asserts! (is-eq tx-sender (get insurer (unwrap-panic insurance-data)))
            (err u403)
        )
        (map-set livestock-insurance-claims {
            livestock-id: livestock-id,
            claim-id: claim-id,
        }
            (merge (unwrap-panic claim-data) {
                status: new-status,
                processed-by: (some tx-sender),
                processed-date: (some burn-block-height),
            })
        )
        (ok true)
    )
)
