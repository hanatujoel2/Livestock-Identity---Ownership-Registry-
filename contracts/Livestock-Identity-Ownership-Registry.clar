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

(define-map livestock-locations
    { livestock-id: uint }
    {
        current-location: (string-ascii 100),
        coordinates: (string-ascii 50),
        location-type: (string-ascii 20),
        updated-by: principal,
        updated-at: uint,
    }
)

(define-map livestock-location-history
    {
        livestock-id: uint,
        movement-id: uint,
    }
    {
        from-location: (string-ascii 100),
        to-location: (string-ascii 100),
        from-coordinates: (string-ascii 50),
        to-coordinates: (string-ascii 50),
        movement-date: uint,
        movement-reason: (string-ascii 50),
        transport-method: (string-ascii 30),
        moved-by: principal,
        verified: bool,
    }
)

(define-map livestock-movement-last-id
    { livestock-id: uint }
    { last-movement-id: uint }
)

(define-read-only (get-livestock-location (livestock-id uint))
    (map-get? livestock-locations { livestock-id: livestock-id })
)

(define-read-only (get-location-history
        (livestock-id uint)
        (movement-id uint)
    )
    (map-get? livestock-location-history {
        livestock-id: livestock-id,
        movement-id: movement-id,
    })
)

(define-read-only (get-last-movement-id (livestock-id uint))
    (default-to { last-movement-id: u0 }
        (map-get? livestock-movement-last-id { livestock-id: livestock-id })
    )
)

(define-public (set-initial-location
        (livestock-id uint)
        (location (string-ascii 100))
        (coordinates (string-ascii 50))
        (location-type (string-ascii 20))
    )
    (let ((livestock-data (map-get? livestock-registry { id: livestock-id })))
        (asserts! (is-some livestock-data) (err u404))
        (asserts! (is-eq tx-sender (get owner (unwrap-panic livestock-data)))
            (err u403)
        )
        (asserts!
            (is-none (map-get? livestock-locations { livestock-id: livestock-id }))
            (err u409)
        )
        (map-set livestock-locations { livestock-id: livestock-id } {
            current-location: location,
            coordinates: coordinates,
            location-type: location-type,
            updated-by: tx-sender,
            updated-at: burn-block-height,
        })
        (ok true)
    )
)

(define-public (record-livestock-movement
        (livestock-id uint)
        (to-location (string-ascii 100))
        (to-coordinates (string-ascii 50))
        (movement-reason (string-ascii 50))
        (transport-method (string-ascii 30))
    )
    (let (
            (livestock-data (map-get? livestock-registry { id: livestock-id }))
            (current-location-data (map-get? livestock-locations { livestock-id: livestock-id }))
            (last-movement (get-last-movement-id livestock-id))
            (new-movement-id (+ (get last-movement-id last-movement) u1))
        )
        (asserts! (is-some livestock-data) (err u404))
        (asserts! (is-some current-location-data) (err u405))
        (asserts! (is-eq tx-sender (get owner (unwrap-panic livestock-data)))
            (err u403)
        )
        (map-set livestock-location-history {
            livestock-id: livestock-id,
            movement-id: new-movement-id,
        } {
            from-location: (get current-location (unwrap-panic current-location-data)),
            to-location: to-location,
            from-coordinates: (get coordinates (unwrap-panic current-location-data)),
            to-coordinates: to-coordinates,
            movement-date: burn-block-height,
            movement-reason: movement-reason,
            transport-method: transport-method,
            moved-by: tx-sender,
            verified: false,
        })
        (map-set livestock-locations { livestock-id: livestock-id }
            (merge (unwrap-panic current-location-data) {
                current-location: to-location,
                coordinates: to-coordinates,
                updated-by: tx-sender,
                updated-at: burn-block-height,
            })
        )
        (map-set livestock-movement-last-id { livestock-id: livestock-id } { last-movement-id: new-movement-id })
        (ok new-movement-id)
    )
)

(define-public (verify-movement
        (livestock-id uint)
        (movement-id uint)
    )
    (let (
            (livestock-data (map-get? livestock-registry { id: livestock-id }))
            (movement-data (map-get? livestock-location-history {
                livestock-id: livestock-id,
                movement-id: movement-id,
            }))
        )
        (asserts! (is-some livestock-data) (err u404))
        (asserts! (is-some movement-data) (err u405))
        (asserts! (is-eq tx-sender (get owner (unwrap-panic livestock-data)))
            (err u403)
        )
        (map-set livestock-location-history {
            livestock-id: livestock-id,
            movement-id: movement-id,
        }
            (merge (unwrap-panic movement-data) { verified: true })
        )
        (ok true)
    )
)

(define-map livestock-certifications
    {
        livestock-id: uint,
        cert-id: uint,
    }
    {
        certification-type: (string-ascii 50),
        issuing-authority: principal,
        certificate-number: (string-ascii 100),
        issue-date: uint,
        expiry-date: uint,
        status: (string-ascii 20),
        requirements-met: (string-utf8 300),
        inspector: principal,
    }
)

(define-map livestock-compliance-checks
    {
        livestock-id: uint,
        check-id: uint,
    }
    {
        compliance-type: (string-ascii 50),
        checker: principal,
        check-date: uint,
        result: (string-ascii 20),
        score: uint,
        notes: (string-utf8 400),
        next-check-due: uint,
    }
)

(define-map livestock-cert-last-id
    { livestock-id: uint }
    { last-cert-id: uint }
)

(define-map livestock-check-last-id
    { livestock-id: uint }
    { last-check-id: uint }
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

(define-data-var contract-admin principal tx-sender)

(define-read-only (get-certification
        (livestock-id uint)
        (cert-id uint)
    )
    (map-get? livestock-certifications {
        livestock-id: livestock-id,
        cert-id: cert-id,
    })
)

(define-read-only (get-compliance-check
        (livestock-id uint)
        (check-id uint)
    )
    (map-get? livestock-compliance-checks {
        livestock-id: livestock-id,
        check-id: check-id,
    })
)

(define-read-only (get-last-cert-id (livestock-id uint))
    (default-to { last-cert-id: u0 }
        (map-get? livestock-cert-last-id { livestock-id: livestock-id })
    )
)

(define-read-only (get-last-check-id (livestock-id uint))
    (default-to { last-check-id: u0 }
        (map-get? livestock-check-last-id { livestock-id: livestock-id })
    )
)

(define-read-only (is-authorized-certifier (certifier principal))
    (match (map-get? authorized-certifiers { certifier: certifier })
        auth-data (get authorized auth-data)
        false
    )
)

(define-public (authorize-certifier
        (certifier principal)
        (certification-types (string-ascii 200))
    )
    (begin
        (asserts! (is-eq tx-sender (var-get contract-admin)) (err u401))
        (map-set authorized-certifiers { certifier: certifier } {
            authorized: true,
            certification-types: certification-types,
            authorized-by: tx-sender,
            authorized-date: burn-block-height,
        })
        (ok true)
    )
)

(define-public (issue-certification
        (livestock-id uint)
        (certification-type (string-ascii 50))
        (certificate-number (string-ascii 100))
        (validity-blocks uint)
        (requirements-met (string-utf8 300))
        (inspector principal)
    )
    (let (
            (livestock-data (map-get? livestock-registry { id: livestock-id }))
            (last-cert (get-last-cert-id livestock-id))
            (new-cert-id (+ (get last-cert-id last-cert) u1))
        )
        (asserts! (is-some livestock-data) (err u404))
        (asserts! (is-authorized-certifier tx-sender) (err u403))
        (asserts! (> validity-blocks u0) (err u400))
        (map-set livestock-certifications {
            livestock-id: livestock-id,
            cert-id: new-cert-id,
        } {
            certification-type: certification-type,
            issuing-authority: tx-sender,
            certificate-number: certificate-number,
            issue-date: burn-block-height,
            expiry-date: (+ burn-block-height validity-blocks),
            status: "active",
            requirements-met: requirements-met,
            inspector: inspector,
        })
        (map-set livestock-cert-last-id { livestock-id: livestock-id } { last-cert-id: new-cert-id })
        (ok new-cert-id)
    )
)

(define-public (conduct-compliance-check
        (livestock-id uint)
        (compliance-type (string-ascii 50))
        (result (string-ascii 20))
        (score uint)
        (notes (string-utf8 400))
        (next-check-blocks uint)
    )
    (let (
            (livestock-data (map-get? livestock-registry { id: livestock-id }))
            (last-check (get-last-check-id livestock-id))
            (new-check-id (+ (get last-check-id last-check) u1))
        )
        (asserts! (is-some livestock-data) (err u404))
        (asserts! (is-authorized-certifier tx-sender) (err u403))
        (asserts! (<= score u100) (err u400))
        (map-set livestock-compliance-checks {
            livestock-id: livestock-id,
            check-id: new-check-id,
        } {
            compliance-type: compliance-type,
            checker: tx-sender,
            check-date: burn-block-height,
            result: result,
            score: score,
            notes: notes,
            next-check-due: (+ burn-block-height next-check-blocks),
        })
        (map-set livestock-check-last-id { livestock-id: livestock-id } { last-check-id: new-check-id })
        (ok new-check-id)
    )
)

(define-public (revoke-certification
        (livestock-id uint)
        (cert-id uint)
    )
    (let ((cert-data (map-get? livestock-certifications {
            livestock-id: livestock-id,
            cert-id: cert-id,
        })))
        (asserts! (is-some cert-data) (err u404))
        (asserts!
            (is-eq tx-sender (get issuing-authority (unwrap-panic cert-data)))
            (err u403)
        )
        (map-set livestock-certifications {
            livestock-id: livestock-id,
            cert-id: cert-id,
        }
            (merge (unwrap-panic cert-data) { status: "revoked" })
        )
        (ok true)
    )
)

(define-public (renew-certification
        (livestock-id uint)
        (cert-id uint)
        (validity-blocks uint)
    )
    (let ((cert-data (map-get? livestock-certifications {
            livestock-id: livestock-id,
            cert-id: cert-id,
        })))
        (asserts! (is-some cert-data) (err u404))
        (asserts!
            (is-eq tx-sender (get issuing-authority (unwrap-panic cert-data)))
            (err u403)
        )
        (asserts! (> validity-blocks u0) (err u400))
        (map-set livestock-certifications {
            livestock-id: livestock-id,
            cert-id: cert-id,
        }
            (merge (unwrap-panic cert-data) {
                expiry-date: (+ burn-block-height validity-blocks),
                status: "active",
            })
        )
        (ok true)
    )
)

(define-map livestock-marketplace
    { livestock-id: uint }
    {
        seller: principal,
        price: uint,
        listed-date: uint,
        description: (string-utf8 300),
        active: bool,
    }
)

(define-map marketplace-offers
    {
        livestock-id: uint,
        offer-id: uint,
    }
    {
        buyer: principal,
        offer-amount: uint,
        offer-date: uint,
        message: (string-utf8 200),
        status: (string-ascii 20),
    }
)

(define-map livestock-offer-last-id
    { livestock-id: uint }
    { last-offer-id: uint }
)

(define-read-only (get-marketplace-listing (livestock-id uint))
    (map-get? livestock-marketplace { livestock-id: livestock-id })
)

(define-read-only (get-marketplace-offer
        (livestock-id uint)
        (offer-id uint)
    )
    (map-get? marketplace-offers {
        livestock-id: livestock-id,
        offer-id: offer-id,
    })
)

(define-read-only (get-last-offer-id (livestock-id uint))
    (default-to { last-offer-id: u0 }
        (map-get? livestock-offer-last-id { livestock-id: livestock-id })
    )
)

(define-public (list-livestock-for-sale
        (livestock-id uint)
        (price uint)
        (description (string-utf8 300))
    )
    (let ((livestock-data (map-get? livestock-registry { id: livestock-id })))
        (asserts! (is-some livestock-data) (err u404))
        (asserts! (is-eq tx-sender (get owner (unwrap-panic livestock-data)))
            (err u403)
        )
        (asserts! (> price u0) (err u400))
        (asserts!
            (is-none (map-get? livestock-marketplace { livestock-id: livestock-id }))
            (err u408)
        )
        (map-set livestock-marketplace { livestock-id: livestock-id } {
            seller: tx-sender,
            price: price,
            listed-date: burn-block-height,
            description: description,
            active: true,
        })
        (ok true)
    )
)

(define-public (update-listing-price
        (livestock-id uint)
        (new-price uint)
    )
    (let ((listing-data (map-get? livestock-marketplace { livestock-id: livestock-id })))
        (asserts! (is-some listing-data) (err u404))
        (asserts! (is-eq tx-sender (get seller (unwrap-panic listing-data)))
            (err u403)
        )
        (asserts! (get active (unwrap-panic listing-data)) (err u409))
        (asserts! (> new-price u0) (err u400))
        (map-set livestock-marketplace { livestock-id: livestock-id }
            (merge (unwrap-panic listing-data) { price: new-price })
        )
        (ok true)
    )
)

(define-public (remove-marketplace-listing (livestock-id uint))
    (let ((listing-data (map-get? livestock-marketplace { livestock-id: livestock-id })))
        (asserts! (is-some listing-data) (err u404))
        (asserts! (is-eq tx-sender (get seller (unwrap-panic listing-data)))
            (err u403)
        )
        (map-delete livestock-marketplace { livestock-id: livestock-id })
        (ok true)
    )
)

(define-public (make-offer
        (livestock-id uint)
        (offer-amount uint)
        (message (string-utf8 200))
    )
    (let (
            (listing-data (map-get? livestock-marketplace { livestock-id: livestock-id }))
            (last-offer (get-last-offer-id livestock-id))
            (new-offer-id (+ (get last-offer-id last-offer) u1))
        )
        (asserts! (is-some listing-data) (err u404))
        (asserts! (get active (unwrap-panic listing-data)) (err u409))
        (asserts! (> offer-amount u0) (err u400))
        (asserts!
            (not (is-eq tx-sender (get seller (unwrap-panic listing-data))))
            (err u410)
        )
        (map-set marketplace-offers {
            livestock-id: livestock-id,
            offer-id: new-offer-id,
        } {
            buyer: tx-sender,
            offer-amount: offer-amount,
            offer-date: burn-block-height,
            message: message,
            status: "pending",
        })
        (map-set livestock-offer-last-id { livestock-id: livestock-id } { last-offer-id: new-offer-id })
        (ok new-offer-id)
    )
)

(define-public (accept-offer
        (livestock-id uint)
        (offer-id uint)
    )
    (let (
            (listing-data (map-get? livestock-marketplace { livestock-id: livestock-id }))
            (offer-data (map-get? marketplace-offers {
                livestock-id: livestock-id,
                offer-id: offer-id,
            }))
            (livestock-data (map-get? livestock-registry { id: livestock-id }))
            (last-transfer (get-last-transfer-id livestock-id))
            (new-transfer-id (+ (get last-transfer-id last-transfer) u1))
        )
        (asserts! (is-some listing-data) (err u404))
        (asserts! (is-some offer-data) (err u405))
        (asserts! (is-some livestock-data) (err u406))
        (asserts! (is-eq tx-sender (get seller (unwrap-panic listing-data)))
            (err u403)
        )
        (asserts! (is-eq "pending" (get status (unwrap-panic offer-data)))
            (err u411)
        )
        (map-set marketplace-offers {
            livestock-id: livestock-id,
            offer-id: offer-id,
        }
            (merge (unwrap-panic offer-data) { status: "accepted" })
        )
        (map-set livestock-ownership-history {
            livestock-id: livestock-id,
            transfer-id: new-transfer-id,
        } {
            from: tx-sender,
            to: (get buyer (unwrap-panic offer-data)),
            transfer-date: burn-block-height,
            price: (get offer-amount (unwrap-panic offer-data)),
            notes: u"Marketplace sale",
        })
        (map-set livestock-registry { id: livestock-id }
            (merge (unwrap-panic livestock-data) { owner: (get buyer (unwrap-panic offer-data)) })
        )
        (map-set livestock-ownership-last-transfer-id { livestock-id: livestock-id } { last-transfer-id: new-transfer-id })
        (map-delete livestock-marketplace { livestock-id: livestock-id })
        (ok new-transfer-id)
    )
)

(define-public (reject-offer
        (livestock-id uint)
        (offer-id uint)
    )
    (let (
            (listing-data (map-get? livestock-marketplace { livestock-id: livestock-id }))
            (offer-data (map-get? marketplace-offers {
                livestock-id: livestock-id,
                offer-id: offer-id,
            }))
        )
        (asserts! (is-some listing-data) (err u404))
        (asserts! (is-some offer-data) (err u405))
        (asserts! (is-eq tx-sender (get seller (unwrap-panic listing-data)))
            (err u403)
        )
        (asserts! (is-eq "pending" (get status (unwrap-panic offer-data)))
            (err u411)
        )
        (map-set marketplace-offers {
            livestock-id: livestock-id,
            offer-id: offer-id,
        }
            (merge (unwrap-panic offer-data) { status: "rejected" })
        )
        (ok true)
    )
)

(define-public (purchase-livestock (livestock-id uint))
    (let (
            (listing-data (map-get? livestock-marketplace { livestock-id: livestock-id }))
            (livestock-data (map-get? livestock-registry { id: livestock-id }))
            (last-transfer (get-last-transfer-id livestock-id))
            (new-transfer-id (+ (get last-transfer-id last-transfer) u1))
        )
        (asserts! (is-some listing-data) (err u404))
        (asserts! (is-some livestock-data) (err u405))
        (asserts! (get active (unwrap-panic listing-data)) (err u409))
        (asserts!
            (not (is-eq tx-sender (get seller (unwrap-panic listing-data))))
            (err u410)
        )
        (map-set livestock-ownership-history {
            livestock-id: livestock-id,
            transfer-id: new-transfer-id,
        } {
            from: (get seller (unwrap-panic listing-data)),
            to: tx-sender,
            transfer-date: burn-block-height,
            price: (get price (unwrap-panic listing-data)),
            notes: u"Direct marketplace purchase",
        })
        (map-set livestock-registry { id: livestock-id }
            (merge (unwrap-panic livestock-data) { owner: tx-sender })
        )
        (map-set livestock-ownership-last-transfer-id { livestock-id: livestock-id } { last-transfer-id: new-transfer-id })
        (map-delete livestock-marketplace { livestock-id: livestock-id })
        (ok new-transfer-id)
    )
)
