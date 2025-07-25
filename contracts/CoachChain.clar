;; CoachChain: Decentralized Personal Coaching Platform
;; Version: 1.0.0
;; Connects certified life coaches with clients for personal development and goal achievement

(define-data-var platform-supervisor principal tx-sender)

(define-map coach-profiles
  { coach-id: uint }
  {
    trainer: principal,
    coaching-fee: uint,
    coaching-specialty: (string-ascii 50),
    coach-qualifications: (string-ascii 500),
    coaching-experience: uint,
    licensed: bool
  })

(define-map coaching-sessions
  { coach-id: uint, session-id: uint }
  {
    client: principal,
    session-time: uint,
    session-type: (string-ascii 20)
  })

(define-data-var next-coach-id uint u1)

(define-map session-tracker
  { coach-id: uint }
  { sessions: uint })

;; Register as a coach
(define-public (register-coach (specialty-input (string-ascii 50)) (qualifications-input (string-ascii 500)) (experience-input uint) (fee-input uint))
  (let
    (
      (coach-id (var-get next-coach-id))
      (session-id u0)
      (specialty specialty-input)
      (qualifications qualifications-input)
      (experience experience-input)
      (fee fee-input)
    )
    ;; Input validation
    (asserts! (> fee u0) (err u1))
    (asserts! (> (len specialty) u0) (err u5))
    (asserts! (> (len qualifications) u0) (err u6))
    (asserts! (> experience u0) (err u7))
    
    (map-set coach-profiles
      { coach-id: coach-id }
      {
        trainer: tx-sender,
        coaching-fee: fee,
        coaching-specialty: specialty,
        coach-qualifications: qualifications,
        coaching-experience: experience,
        licensed: false
      }
    )
    (map-set coaching-sessions
      { coach-id: coach-id, session-id: session-id }
      {
        client: tx-sender,
        session-time: coach-id,
        session-type: "registered"
      }
    )
    (map-set session-tracker
      { coach-id: coach-id }
      { sessions: u1 }
    )
    (var-set next-coach-id (+ coach-id u1))
    (ok coach-id)
  ))

;; Book a coaching session
(define-public (book-coaching (coach-id-input uint))
  (let
    (
      (coach-id coach-id-input)
      (coach-info (unwrap! (map-get? coach-profiles { coach-id: coach-id }) (err u2)))
      (fee (get coaching-fee coach-info))
      (trainer (get trainer coach-info))
      (session-data (default-to { sessions: u0 } (map-get? session-tracker { coach-id: coach-id })))
      (session-id (get sessions session-data))
      (new-session-id (+ session-id u1))
    )
    ;; Input validation
    (asserts! (> coach-id u0) (err u8))
    (asserts! (not (is-eq tx-sender trainer)) (err u3))
    
    (try! (stx-transfer? fee tx-sender trainer))
    (map-set coaching-sessions
      { coach-id: coach-id, session-id: session-id }
      {
        client: tx-sender,
        session-time: (var-get next-coach-id),
        session-type: "booked"
      }
    )
    (map-set session-tracker
      { coach-id: coach-id }
      { sessions: new-session-id }
    )
    (ok true)
  ))

;; License a coach (supervisor only)
(define-public (license-coach (coach-id-input uint))
  (let
    (
      (coach-id coach-id-input)
      (coach-info (unwrap! (map-get? coach-profiles { coach-id: coach-id }) (err u2)))
      (session-data (default-to { sessions: u0 } (map-get? session-tracker { coach-id: coach-id })))
      (session-id (get sessions session-data))
      (new-session-id (+ session-id u1))
    )
    ;; Input validation
    (asserts! (> coach-id u0) (err u8))
    (asserts! (is-eq tx-sender (var-get platform-supervisor)) (err u4))
    
    (map-set coach-profiles
      { coach-id: coach-id }
      (merge coach-info { licensed: true })
    )
    (map-set coaching-sessions
      { coach-id: coach-id, session-id: session-id }
      {
        client: (get trainer coach-info),
        session-time: (var-get next-coach-id),
        session-type: "licensed"
      }
    )
    (map-set session-tracker
      { coach-id: coach-id }
      { sessions: new-session-id }
    )
    (ok true)
  ))

;; Get coach profile
(define-read-only (get-coach (coach-id uint))
  (map-get? coach-profiles { coach-id: coach-id }))

;; Get coaching session record
(define-read-only (get-session-record (coach-id uint) (session-id uint))
  (map-get? coaching-sessions { coach-id: coach-id, session-id: session-id }))

;; Get total sessions for a coach
(define-read-only (get-session-count (coach-id uint))
  (let
    (
      (session-data (default-to { sessions: u0 } (map-get? session-tracker { coach-id: coach-id })))
    )
    (get sessions session-data)
  ))

;; Get platform stats
(define-read-only (get-platform-stats)
  {
    supervisor: (var-get platform-supervisor),
    total-coaches: (- (var-get next-coach-id) u1)
  })