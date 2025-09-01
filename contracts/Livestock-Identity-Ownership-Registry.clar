;; Livestock Identity & Ownership Registry
;; Production-ready contract with comprehensive security and transparency

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_INPUT (err u400))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant ERR_INSUFFICIENT_FUNDS (err u402))
(define-constant ERR_CONTRACT_PAUSED (err u423))
(define-constant ERR_EXPIRED (err u410))
(define-constant ERR_INVALID_OPERATION (err u422))

(define-data-var contract-paused bool false)
(define-data-var last-livestock-id uint u0)
(define-data-var batch-operation-id uint u0)
(define-data-var contract-admin principal tx-sender)

(define-map livestock-registry
    { id: uint }
    {
        owner: principal,
        species: (string-ascii 20),
        breed: (string-ascii 30),
        birth-date: uint,
        nfc-chip-id: (string-ascii 64),
        registered-at: uint,
        status: (string-ascii 20),
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

(define-map livestock-batches
    { batch-id: uint }
    {
        owner: principal,
        name: (string-ascii 50),
        description: (string-utf8 200),
        created-at: uint,
        livestock-count: uint,
        active: bool,
    }
)

(define-map batch-livestock-members
    {
        batch-id: uint,
        livestock-id: uint,
    }
    {
        added-at: uint,
        active: bool,
    }
)

(define-map authorized-certifiers
    { certifier: principal }
    {
        authorized: bool,
        certification-types: (string-ascii 200),
        authorized-by: principal,
        authorized-date: uint,
    }
)

(define-private (is-contract-paused)
    (var-get contract-paused)
)

(define-private (validate-ascii-length
        (str (string-ascii 200))
        (min-len uint)
        (max-len uint)
    )
    (let ((str-len (len str)))
        (and (>= str-len min-len) (<= str-len max-len))
    )
)

(define-private (validate-utf8-length
        (str (string-utf8 500))
        (min-len uint)
        (max-len uint)
    )
    (let ((str-len (len str)))
        (and (>= str-len min-len) (<= str-len max-len))
    )
)

(define-private (validate-future-date (date uint))
    (> date burn-block-height)
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
        (match livestock-data
            data (is-eq owner (get owner data))
            false
        )
    )
)

(define-read-only (get-batch (batch-id uint))
    (map-get? livestock-batches { batch-id: batch-id })
)

(define-read-only (is-livestock-in-batch
        (batch-id uint)
        (livestock-id uint)
    )
    (match (map-get? batch-livestock-members {
        batch-id: batch-id,
        livestock-id: livestock-id,
    })
        member-data (get active member-data)
        false
    )
)

(define-read-only (is-authorized-certifier (certifier principal))
    (match (map-get? authorized-certifiers { certifier: certifier })
        auth-data (get authorized auth-data)
        false
    )
)

(define-read-only (get-contract-info)
    {
        paused: (var-get contract-paused),
        admin: (var-get contract-admin),
        total-livestock: (var-get last-livestock-id),
        total-batches: (var-get batch-operation-id),
    }
)

(define-public (pause-contract)
    (begin
        (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
        (var-set contract-paused true)
        (print {
            event: "contract-paused",
            admin: tx-sender,
            block: burn-block-height,
        })
        (ok true)
    )
)

(define-public (unpause-contract)
    (begin
        (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
        (var-set contract-paused false)
        (print {
            event: "contract-unpaused",
            admin: tx-sender,
            block: burn-block-height,
        })
        (ok true)
    )
)

(define-public (transfer-admin (new-admin principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
        (asserts! (not (is-eq tx-sender new-admin)) ERR_INVALID_INPUT)
        (var-set contract-admin new-admin)
        (print {
            event: "admin-transferred",
            old-admin: tx-sender,
            new-admin: new-admin,
            block: burn-block-height,
        })
        (ok true)
    )
)

(define-public (register-livestock
        (species (string-ascii 20))
        (breed (string-ascii 30))
        (birth-date uint)
        (nfc-chip-id (string-ascii 64))
    )
    (let ((new-id (+ (var-get last-livestock-id) u1)))
        (asserts! (not (is-contract-paused)) ERR_CONTRACT_PAUSED)
        (asserts! (validate-ascii-length species u1 u20) ERR_INVALID_INPUT)
        (asserts! (validate-ascii-length breed u1 u30) ERR_INVALID_INPUT)
        (asserts! (validate-ascii-length nfc-chip-id u8 u64) ERR_INVALID_INPUT)
        (asserts! (<= birth-date burn-block-height) ERR_INVALID_INPUT)
        (asserts! (>= birth-date (- burn-block-height u525600)) ERR_INVALID_INPUT)
        (var-set last-livestock-id new-id)
        (map-set livestock-registry { id: new-id } {
            owner: tx-sender,
            species: species,
            breed: breed,
            birth-date: birth-date,
            nfc-chip-id: nfc-chip-id,
            registered-at: burn-block-height,
            status: "active",
        })
        (print {
            event: "livestock-registered",
            livestock-id: new-id,
            owner: tx-sender,
            species: species,
            block: burn-block-height,
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
        (asserts! (not (is-contract-paused)) ERR_CONTRACT_PAUSED)
        (asserts! (is-some livestock-data) ERR_NOT_FOUND)
        (asserts! (is-eq tx-sender (get owner (unwrap-panic livestock-data)))
            ERR_UNAUTHORIZED
        )
        (asserts! (validate-ascii-length treatment-type u2 u50) ERR_INVALID_INPUT)
        (asserts! (validate-utf8-length notes u1 u500) ERR_INVALID_INPUT)
        (asserts! (is-eq (get status (unwrap-panic livestock-data)) "active")
            ERR_INVALID_OPERATION
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
        (print {
            event: "health-record-added",
            livestock-id: livestock-id,
            record-id: new-record-id,
            vet: tx-sender,
            treatment: treatment-type,
            block: burn-block-height,
        })
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
        (asserts! (not (is-contract-paused)) ERR_CONTRACT_PAUSED)
        (asserts! (is-some livestock-data) ERR_NOT_FOUND)
        (asserts! (is-eq tx-sender (get owner (unwrap-panic livestock-data)))
            ERR_UNAUTHORIZED
        )
        (asserts! (not (is-eq tx-sender new-owner)) ERR_INVALID_INPUT)
        (asserts! (validate-utf8-length notes u1 u200) ERR_INVALID_INPUT)
        (asserts! (is-eq (get status (unwrap-panic livestock-data)) "active")
            ERR_INVALID_OPERATION
        )
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
        (print {
            event: "ownership-transferred",
            livestock-id: livestock-id,
            from: tx-sender,
            to: new-owner,
            price: price,
            block: burn-block-height,
        })
        (ok new-transfer-id)
    )
)

(define-public (update-nfc-chip
        (livestock-id uint)
        (new-nfc-chip-id (string-ascii 64))
    )
    (let ((livestock-data (map-get? livestock-registry { id: livestock-id })))
        (asserts! (not (is-contract-paused)) ERR_CONTRACT_PAUSED)
        (asserts! (is-some livestock-data) ERR_NOT_FOUND)
        (asserts! (is-eq tx-sender (get owner (unwrap-panic livestock-data)))
            ERR_UNAUTHORIZED
        )
        (asserts! (validate-ascii-length new-nfc-chip-id u8 u64)
            ERR_INVALID_INPUT
        )
        (asserts! (is-eq (get status (unwrap-panic livestock-data)) "active")
            ERR_INVALID_OPERATION
        )
        (map-set livestock-registry { id: livestock-id }
            (merge (unwrap-panic livestock-data) { nfc-chip-id: new-nfc-chip-id })
        )
        (print {
            event: "nfc-chip-updated",
            livestock-id: livestock-id,
            owner: tx-sender,
            block: burn-block-height,
        })
        (ok true)
    )
)

(define-public (deactivate-livestock (livestock-id uint))
    (let ((livestock-data (map-get? livestock-registry { id: livestock-id })))
        (asserts! (not (is-contract-paused)) ERR_CONTRACT_PAUSED)
        (asserts! (is-some livestock-data) ERR_NOT_FOUND)
        (asserts! (is-eq tx-sender (get owner (unwrap-panic livestock-data)))
            ERR_UNAUTHORIZED
        )
        (asserts! (is-eq (get status (unwrap-panic livestock-data)) "active")
            ERR_INVALID_OPERATION
        )
        (map-set livestock-registry { id: livestock-id }
            (merge (unwrap-panic livestock-data) { status: "inactive" })
        )
        (print {
            event: "livestock-deactivated",
            livestock-id: livestock-id,
            owner: tx-sender,
            block: burn-block-height,
        })
        (ok true)
    )
)

(define-public (authorize-certifier
        (certifier principal)
        (certification-types (string-ascii 200))
    )
    (begin
        (asserts! (not (is-contract-paused)) ERR_CONTRACT_PAUSED)
        (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
        (asserts! (not (is-eq tx-sender certifier)) ERR_INVALID_INPUT)
        (asserts! (validate-ascii-length certification-types u3 u200)
            ERR_INVALID_INPUT
        )
        (map-set authorized-certifiers { certifier: certifier } {
            authorized: true,
            certification-types: certification-types,
            authorized-by: tx-sender,
            authorized-date: burn-block-height,
        })
        (print {
            event: "certifier-authorized",
            certifier: certifier,
            types: certification-types,
            admin: tx-sender,
            block: burn-block-height,
        })
        (ok true)
    )
)

(define-public (revoke-certifier (certifier principal))
    (let ((certifier-data (map-get? authorized-certifiers { certifier: certifier })))
        (asserts! (not (is-contract-paused)) ERR_CONTRACT_PAUSED)
        (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
        (asserts! (is-some certifier-data) ERR_NOT_FOUND)
        (asserts! (get authorized (unwrap-panic certifier-data))
            ERR_INVALID_OPERATION
        )
        (map-set authorized-certifiers { certifier: certifier }
            (merge (unwrap-panic certifier-data) { authorized: false })
        )
        (print {
            event: "certifier-revoked",
            certifier: certifier,
            admin: tx-sender,
            block: burn-block-height,
        })
        (ok true)
    )
)

(define-public (create-livestock-batch
        (name (string-ascii 50))
        (description (string-utf8 200))
        (livestock-ids (list 50 uint))
    )
    (let (
            (new-batch-id (+ (var-get batch-operation-id) u1))
            (livestock-count (len livestock-ids))
        )
        (asserts! (not (is-contract-paused)) ERR_CONTRACT_PAUSED)
        (asserts! (validate-ascii-length name u2 u50) ERR_INVALID_INPUT)
        (asserts! (validate-utf8-length description u1 u200) ERR_INVALID_INPUT)
        (asserts! (and (> livestock-count u0) (<= livestock-count u50))
            ERR_INVALID_INPUT
        )
        (var-set batch-operation-id new-batch-id)
        (map-set livestock-batches { batch-id: new-batch-id } {
            owner: tx-sender,
            name: name,
            description: description,
            created-at: burn-block-height,
            livestock-count: livestock-count,
            active: true,
        })
        (fold batch-add-livestock-helper livestock-ids new-batch-id)
        (print {
            event: "batch-created",
            batch-id: new-batch-id,
            owner: tx-sender,
            count: livestock-count,
            block: burn-block-height,
        })
        (ok new-batch-id)
    )
)

(define-private (batch-add-livestock-helper
        (livestock-id uint)
        (batch-id uint)
    )
    (let ((livestock-data (map-get? livestock-registry { id: livestock-id })))
        (if (and
                (is-some livestock-data)
                (is-eq tx-sender (get owner (unwrap-panic livestock-data)))
                (is-eq (get status (unwrap-panic livestock-data)) "active")
            )
            (map-set batch-livestock-members {
                batch-id: batch-id,
                livestock-id: livestock-id,
            } {
                added-at: burn-block-height,
                active: true,
            })
            false
        )
        batch-id
    )
)

(define-public (batch-register-livestock (livestock-data-list (list 20
    {
    species: (string-ascii 20),
    breed: (string-ascii 30),
    birth-date: uint,
    nfc-chip-id: (string-ascii 64),
})))
    (let ((batch-size (len livestock-data-list)))
        (asserts! (not (is-contract-paused)) ERR_CONTRACT_PAUSED)
        (asserts! (and (> batch-size u0) (<= batch-size u20)) ERR_INVALID_INPUT)
        (let ((registration-results (fold batch-register-helper livestock-data-list (list))))
            (print {
                event: "batch-livestock-registered",
                count: batch-size,
                owner: tx-sender,
                block: burn-block-height,
            })
            (ok registration-results)
        )
    )
)

(define-private (batch-register-helper
        (livestock-data {
            species: (string-ascii 20),
            breed: (string-ascii 30),
            birth-date: uint,
            nfc-chip-id: (string-ascii 64),
        })
        (results (list 20 uint))
    )
    (let ((new-id (+ (var-get last-livestock-id) u1)))
        (if (and
                (validate-ascii-length (get species livestock-data) u1 u20)
                (validate-ascii-length (get breed livestock-data) u1 u30)
                (validate-ascii-length (get nfc-chip-id livestock-data) u8 u64)
                (<= (get birth-date livestock-data) burn-block-height)
                (>= (get birth-date livestock-data) (- burn-block-height u525600))
            )
            (begin
                (var-set last-livestock-id new-id)
                (map-set livestock-registry { id: new-id } {
                    owner: tx-sender,
                    species: (get species livestock-data),
                    breed: (get breed livestock-data),
                    birth-date: (get birth-date livestock-data),
                    nfc-chip-id: (get nfc-chip-id livestock-data),
                    registered-at: burn-block-height,
                    status: "active",
                })
                (unwrap-panic (as-max-len? (append results new-id) u20))
            )
            results
        )
    )
)

(define-public (batch-transfer-ownership
        (livestock-ids (list 30 uint))
        (new-owner principal)
        (price-per-animal uint)
        (notes (string-utf8 200))
    )
    (let ((batch-size (len livestock-ids)))
        (asserts! (not (is-contract-paused)) ERR_CONTRACT_PAUSED)
        (asserts! (not (is-eq tx-sender new-owner)) ERR_INVALID_INPUT)
        (asserts! (and (> batch-size u0) (<= batch-size u30)) ERR_INVALID_INPUT)
        (asserts! (validate-utf8-length notes u1 u200) ERR_INVALID_INPUT)
        (let ((transfer-results (fold batch-transfer-helper livestock-ids {
                new-owner: new-owner,
                price: price-per-animal,
                notes: notes,
                success-count: u0,
            })))
            (print {
                event: "batch-ownership-transferred",
                count: (get success-count transfer-results),
                to: new-owner,
                price-per: price-per-animal,
                block: burn-block-height,
            })
            (ok (get success-count transfer-results))
        )
    )
)

(define-private (batch-transfer-helper
        (livestock-id uint)
        (transfer-info {
            new-owner: principal,
            price: uint,
            notes: (string-utf8 200),
            success-count: uint,
        })
    )
    (let (
            (livestock-data (map-get? livestock-registry { id: livestock-id }))
            (last-transfer (get-last-transfer-id livestock-id))
            (new-transfer-id (+ (get last-transfer-id last-transfer) u1))
        )
        (if (and
                (is-some livestock-data)
                (is-eq tx-sender (get owner (unwrap-panic livestock-data)))
                (is-eq (get status (unwrap-panic livestock-data)) "active")
            )
            (begin
                (map-set livestock-ownership-history {
                    livestock-id: livestock-id,
                    transfer-id: new-transfer-id,
                } {
                    from: tx-sender,
                    to: (get new-owner transfer-info),
                    transfer-date: burn-block-height,
                    price: (get price transfer-info),
                    notes: (get notes transfer-info),
                })
                (map-set livestock-registry { id: livestock-id }
                    (merge (unwrap-panic livestock-data) { owner: (get new-owner transfer-info) })
                )
                (map-set livestock-ownership-last-transfer-id { livestock-id: livestock-id } { last-transfer-id: new-transfer-id })
                (merge transfer-info { success-count: (+ (get success-count transfer-info) u1) })
            )
            transfer-info
        )
    )
)

(define-public (emergency-deactivate-livestock
        (livestock-id uint)
        (reason (string-ascii 100))
    )
    (let ((livestock-data (map-get? livestock-registry { id: livestock-id })))
        (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
        (asserts! (is-some livestock-data) ERR_NOT_FOUND)
        (asserts! (validate-ascii-length reason u5 u100) ERR_INVALID_INPUT)
        (map-set livestock-registry { id: livestock-id }
            (merge (unwrap-panic livestock-data) { status: "suspended" })
        )
        (print {
            event: "emergency-deactivation",
            livestock-id: livestock-id,
            admin: tx-sender,
            reason: reason,
            block: burn-block-height,
        })
        (ok true)
    )
)

(define-public (remove-livestock-from-batch
        (batch-id uint)
        (livestock-id uint)
    )
    (let (
            (batch-data (map-get? livestock-batches { batch-id: batch-id }))
            (member-data (map-get? batch-livestock-members {
                batch-id: batch-id,
                livestock-id: livestock-id,
            }))
        )
        (asserts! (not (is-contract-paused)) ERR_CONTRACT_PAUSED)
        (asserts! (is-some batch-data) ERR_NOT_FOUND)
        (asserts! (is-some member-data) ERR_NOT_FOUND)
        (asserts! (is-eq tx-sender (get owner (unwrap-panic batch-data)))
            ERR_UNAUTHORIZED
        )
        (asserts! (get active (unwrap-panic member-data)) ERR_INVALID_OPERATION)
        (asserts! (get active (unwrap-panic batch-data)) ERR_INVALID_OPERATION)
        (map-set batch-livestock-members {
            batch-id: batch-id,
            livestock-id: livestock-id,
        }
            (merge (unwrap-panic member-data) { active: false })
        )
        (let ((current-batch (unwrap-panic batch-data)))
            (map-set livestock-batches { batch-id: batch-id }
                (merge current-batch { livestock-count: (- (get livestock-count current-batch) u1) })
            )
        )
        (print {
            event: "livestock-removed-from-batch",
            batch-id: batch-id,
            livestock-id: livestock-id,
            owner: tx-sender,
            block: burn-block-height,
        })
        (ok true)
    )
)

(define-public (deactivate-batch (batch-id uint))
    (let ((batch-data (map-get? livestock-batches { batch-id: batch-id })))
        (asserts! (not (is-contract-paused)) ERR_CONTRACT_PAUSED)
        (asserts! (is-some batch-data) ERR_NOT_FOUND)
        (asserts! (is-eq tx-sender (get owner (unwrap-panic batch-data)))
            ERR_UNAUTHORIZED
        )
        (asserts! (get active (unwrap-panic batch-data)) ERR_INVALID_OPERATION)
        (map-set livestock-batches { batch-id: batch-id }
            (merge (unwrap-panic batch-data) { active: false })
        )
        (print {
            event: "batch-deactivated",
            batch-id: batch-id,
            owner: tx-sender,
            block: burn-block-height,
        })
        (ok true)
    )
)

(define-public (bulk-health-update
        (livestock-ids (list 25 uint))
        (treatment-type (string-ascii 50))
        (notes (string-utf8 500))
    )
    (let ((batch-size (len livestock-ids)))
        (asserts! (not (is-contract-paused)) ERR_CONTRACT_PAUSED)
        (asserts! (and (> batch-size u0) (<= batch-size u25)) ERR_INVALID_INPUT)
        (asserts! (validate-ascii-length treatment-type u2 u50) ERR_INVALID_INPUT)
        (asserts! (validate-utf8-length notes u1 u500) ERR_INVALID_INPUT)
        (let ((update-results (fold bulk-health-helper livestock-ids {
                treatment: treatment-type,
                notes: notes,
                success-count: u0,
            })))
            (print {
                event: "bulk-health-update",
                count: (get success-count update-results),
                treatment: treatment-type,
                vet: tx-sender,
                block: burn-block-height,
            })
            (ok (get success-count update-results))
        )
    )
)

(define-private (bulk-health-helper
        (livestock-id uint)
        (health-info {
            treatment: (string-ascii 50),
            notes: (string-utf8 500),
            success-count: uint,
        })
    )
    (let (
            (livestock-data (map-get? livestock-registry { id: livestock-id }))
            (last-record (get-last-health-record-id livestock-id))
            (new-record-id (+ (get last-record-id last-record) u1))
        )
        (if (and
                (is-some livestock-data)
                (is-eq tx-sender (get owner (unwrap-panic livestock-data)))
                (is-eq (get status (unwrap-panic livestock-data)) "active")
            )
            (begin
                (map-set livestock-health-records {
                    livestock-id: livestock-id,
                    record-id: new-record-id,
                } {
                    vet-principal: tx-sender,
                    treatment-date: burn-block-height,
                    treatment-type: (get treatment health-info),
                    notes: (get notes health-info),
                    recorded-at: burn-block-height,
                })
                (map-set livestock-health-last-record-id { livestock-id: livestock-id } { last-record-id: new-record-id })
                (merge health-info { success-count: (+ (get success-count health-info) u1) })
            )
            health-info
        )
    )
)

(define-public (query-livestock-by-owner (owner principal))
    (ok true)
)

(define-public (emergency-force-transfer
        (livestock-id uint)
        (new-owner principal)
        (reason (string-ascii 100))
    )
    (let (
            (livestock-data (map-get? livestock-registry { id: livestock-id }))
            (last-transfer (get-last-transfer-id livestock-id))
            (new-transfer-id (+ (get last-transfer-id last-transfer) u1))
        )
        (asserts! (is-eq tx-sender (var-get contract-admin)) ERR_UNAUTHORIZED)
        (asserts! (is-some livestock-data) ERR_NOT_FOUND)
        (asserts!
            (not (is-eq (get owner (unwrap-panic livestock-data)) new-owner))
            ERR_INVALID_INPUT
        )
        (asserts! (validate-ascii-length reason u5 u100) ERR_INVALID_INPUT)
        (map-set livestock-ownership-history {
            livestock-id: livestock-id,
            transfer-id: new-transfer-id,
        } {
            from: (get owner (unwrap-panic livestock-data)),
            to: new-owner,
            transfer-date: burn-block-height,
            price: u0,
            notes: u"Emergency admin transfer",
        })
        (map-set livestock-registry { id: livestock-id }
            (merge (unwrap-panic livestock-data) { owner: new-owner })
        )
        (map-set livestock-ownership-last-transfer-id { livestock-id: livestock-id } { last-transfer-id: new-transfer-id })
        (print {
            event: "emergency-transfer",
            livestock-id: livestock-id,
            admin: tx-sender,
            new-owner: new-owner,
            reason: reason,
            block: burn-block-height,
        })
        (ok new-transfer-id)
    )
)
