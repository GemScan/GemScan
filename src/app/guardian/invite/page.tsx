'use client'

import { useState } from 'react'

export default function GuardianInvitePage() {
  const [accepted, setAccepted] = useState(false)

  // In production this would parse a deep link / QR code token
  const inviteToken =
    typeof window !== 'undefined' ? new URLSearchParams(window.location.search).get('token') : null

  const handleAccept = () => {
    // TODO: validate token and register as guardian
    setAccepted(true)
  }

  return (
    <main className="page" style={{ alignItems: 'center', justifyContent: 'center' }}>
      <h1 className="text-2xl font-bold mb-4">Guardian Invite</h1>

      {!inviteToken && !accepted && (
        <div className="text-center max-w-sm">
          <p className="text-gray-600 mb-6">
            Share this page as a QR code or deep link to invite a trusted contact as your guardian.
          </p>
          <div className="w-48 h-48 mx-auto rounded-xl border-2 border-dashed border-gray-300 flex items-center justify-center text-gray-400 text-sm">
            QR Code Placeholder
          </div>
        </div>
      )}

      {inviteToken && !accepted && (
        <div className="text-center max-w-sm">
          <p className="text-gray-600 mb-6">
            You have been invited to be a guardian. Accept to receive scam alerts for this person.
          </p>
          <button
            onClick={handleAccept}
            className="rounded-xl bg-blue-500 px-8 py-4 text-white font-semibold text-lg"
          >
            Accept Invite
          </button>
        </div>
      )}

      {accepted && (
        <div className="text-center">
          <p className="text-green-600 font-semibold text-lg">
            Invite accepted! You are now a guardian.
          </p>
        </div>
      )}
    </main>
  )
}
