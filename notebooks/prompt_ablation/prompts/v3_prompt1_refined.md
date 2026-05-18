# Scam Marker Extraction Prompt — Prompt 1 Only

This prompt extracts observable scam-relevant markers from an input summary. They are intended for small-model prompt testing and downstream deterministic scoring.

The model must **not** decide whether the content is a scam or safe. It should only mark whether each observable marker is directly supported by the summary.

## Output Rules

- Return **valid JSON only**.
- Do not include markdown, explanation, comments, or extra text.
- Do not give a scam/safe verdict.
- Do not give a probability, risk score, recommendation, or final user action.
- Use only information stated in the input summary.
- Use exactly two status values:
  - `"present"` = directly supported by the summary.
  - `"absent"` = not directly supported, unclear, missing, cropped out, unverifiable, or only possible.
- Do not use `"unknown"`.
- Evidence should be a short quote or grounded paraphrase from the summary. For present fields, prefer evidence from the suspicious sender's message rather than app UI text or the recipient's reply when possible.
- If a field is absent, use an empty evidence string unless the summary explicitly gives negative evidence.

## Marker Set

```json
[
  "sender_unknown_or_unverified",
  "sender_in_different_country_than_usa",
  "impersonates_authority_or_business",
  "unrealistic_offer_or_unexpected_windfall",
  "unsolicited_job_or_opportunity",
  "fabricated_context_or_wrong_number_pretext",
  "urgency_or_emotional_manipulation",
  "requests_sensitive_information",
  "requests_direct_payment_or_financial_transfer",
  "requests_external_or_off_platform_action"
]
```

## Compact Field Definitions

- `sender_unknown_or_unverified`: Present when the sender is a bare phone number, raw email, unknown/unsaved contact, blank/hidden sender, malformed/generic sender, possible-spam sender, or does not clearly match a claimed business. Do **not** mark absent merely because the message body contains a brand name, branded footer, copyright line, or signature. Absent when the sender is a saved contact, known person, verified business, short code clearly associated with the business, or sender identity clearly matching the claimed organization.

- `sender_in_different_country_than_usa`: Present only when the sender or message origin is directly shown as outside the USA, such as a non-US country/location, non-US country code other than `+1`, foreign address, foreign currency, foreign domain, or stated non-US origin. Do **not** mark present for `+1` phone numbers, US area codes, US addresses, US states, or USD prices. `+1` is not evidence of a non-USA sender by itself.

- `impersonates_authority_or_business`: Present only when there is direct evidence of a suspicious mismatch, spoofing clue, fake/nonexistent organization, lookalike domain/sender, fake support/executive/authority role, or explicit impersonation. Mark present when an unknown sender, bare phone number, raw email, or unrelated sender claims to represent a known company, platform, employer, recruiter, support team, government agency, school, bank, healthcare provider, or organization. Mark present when a message claims one company/service but contains mismatched product names, branding, support identity, footer identity, phone numbers, addresses, team names, or account details. Mark present for fake branded survey/reward lures that use a known company's name, branding, copyright/footer, reward program, survey, giveaway, customer notice, or loyalty-style offer to imply affiliation. Do **not** mark present merely because a company, nonprofit, campaign, platform, school, or organization is named.

- `unrealistic_offer_or_unexpected_windfall`: Present only for unexpected, unusually valuable, prize-like, grant-like, refund-like, investment-like, inheritance-like, free-money-like, guaranteed-payout, or clearly too-good-to-be-true offers. Do **not** mark present for ordinary retail promotions, coupons, rebates, discounts, sales, loyalty rewards, service discounts, healthcare/medication discounts, move-in specials, newsletters, normal donation appeals, routine marketing, or normal rewards from a matching known sender. A discount or `$X off` offer is not a windfall by itself, even when the dollar amount is large.

- `unsolicited_job_or_opportunity`: Present for unexpected jobs, tasks, freelance roles, remote work, recruiting, business opportunities, investment opportunities, partnerships, or easy earning opportunities.

- `fabricated_context_or_wrong_number_pretext`: Present when the message invents, asserts, or relies on a suspicious setup that gives the recipient a reason to continue, reply, call, click, verify, review, cancel, modify, or act. This includes wrong-number setups, mistaken identity, vague familiarity, fake prior relationships, fake referrals or mutual contacts, fake appointments, pickups, adoptions, reservations, meetings, business/order/delivery/factory/customer issues, account issues, subscription issues, membership issues, antivirus/software plan issues, warranty issues, security issues, billing issues, billing summaries, renewal notices, invoices, receipts, charges, pending charges, debits, auto-debits, payment methods, support cases, cloud/storage problems, transactions, or purchases. Do not require the message to ask for money, credentials, a wrong-number setup, or a link. Early scam messages may only establish a fabricated context.

- `urgency_or_emotional_manipulation`: Present for either **hard urgency** or **soft emotional pressure**. Hard urgency includes time pressure, deadlines, threats, penalties, fear, emergency, secrecy, account/data loss, financial loss, pending charges, cancellation deadlines, renewal deadlines, loss of access, and act-now language. Soft emotional pressure includes guilt, sympathy, praise, gratitude, obligation, romance/flattery pressure, authority pressure, vulnerable people, vulnerable animals, rescue/adoption stories, illness, hardship, or language that makes the recipient feel responsible for helping, rescuing, caring, paying, cancelling, responding, meeting, picking up, or following through. A message does **not** need an explicit deadline, threat, or panic language to satisfy this marker.

- `requests_sensitive_information`: Present when the message asks the recipient to provide, confirm, enter, send, share, upload, or verify passwords, login codes, one-time passcodes, account access, SSN, ID, bank/card details, personal documents, private data, remote/device access, or other sensitive information. Do **not** mark present merely because a message contains a verification code, activation code, reference number, transaction ID, or account-related number. Mark present only if the recipient is asked to disclose or use sensitive information in response.

- `requests_direct_payment_or_financial_transfer`: Present only when the recipient is directly asked to pay, send money, transfer funds, deposit money, approve or complete a charge, pay an invoice/fee, buy gift cards, send crypto, provide payment/banking details, or complete a direct payment/transfer step. Do **not** mark present just because the message mentions prices, discounts, refunds, invoices, donations, gift cards, rewards, sweepstakes entries, charges, debits, renewals, subscriptions, receipts, payment methods, total amounts, auto-debits, or pending charges.

- `requests_external_or_off_platform_action`: Present when the summary directly shows a visible URL, link, domain, outside website, phone call/text request to a separate number, email contact, QR code, app download, WhatsApp, Telegram, Signal, social-media contact, crypto wallet, contact-information exchange, CTA button, or instruction to use an outside destination/contact method. A phone number or support line provided by the sender counts when the message asks or implies the recipient should call or contact it. Do **not** mark present merely because a company/platform name appears or because the sender asks for a same-thread reply such as "reply yes," "reply interested," "send pictures," "text back," or "message back." The current channel itself, such as SMS or email, does not count.

## Common Guardrails

- Verification-code messages: Do not mark `impersonates_authority_or_business`, `fabricated_context_or_wrong_number_pretext`, `requests_sensitive_information`, or `urgency_or_emotional_manipulation` present merely because a normal verification-code message contains a code or a standard expiration window. Mark `requests_sensitive_information` present only if the message asks the recipient to share, reply with, enter into an outside destination, or otherwise disclose the code. Mark impersonation or fabricated context present only if there is separate mismatch, spoofing, fake account issue, or other direct evidence.

- Discounts and promotions: Do not mark `unrealistic_offer_or_unexpected_windfall` present for ordinary discounts, coupons, rebates, move-in specials, service discounts, healthcare/medication discounts, retail promotions, donation incentives, or `$X off` advertisements. Mark present only for prize-like, free-money-like, grant-like, inheritance-like, guaranteed-payout, unexpected refund/compensation, investment-return, or clearly too-good-to-be-true offers.

- Fabricated context: Mark `fabricated_context_or_wrong_number_pretext` present for fake account, billing, subscription, membership, antivirus plan, software plan, warranty, billing summary, renewal, invoice, receipt, charge, debit, auto-debit, payment method, transaction, support case, cloud/storage, order, delivery, factory, customer, support, appointment, adoption, referral, wrong-number, mistaken-identity, or prior-relationship setups that create a reason to reply, call, click, review, verify, cancel, modify, or act. Fake invoice/renewal notices do not need a wrong-number setup, payment request, credential request, or link. Use evidence from the suspicious sender's setup when possible, not only the recipient's correction.

- Urgency/emotional manipulation: Mark `urgency_or_emotional_manipulation` present for soft obligation as well as hard urgency. Animal shelter, rescue, adoption, fostering, abandoned-pet, sick-pet, child, elderly-person, illness, hardship, or emergency scenarios should be present when paired with gratitude, praise, sympathy, responsibility, pickup timing, follow-through language, or implied responsibility. Renewal, pending-charge, auto-debit, saved-payment-method, cancellation-window, loss-of-access, or financial-loss scenarios should also be present when the message pressures the recipient to cancel, modify, call, review, verify, or act before money, access, or status changes.

- Country: A `+1` phone number, US area code, US address, US state, or USD amount is not evidence of a non-USA sender. Mark `sender_in_different_country_than_usa` present only for direct non-USA evidence.

## Required JSON Structure

Use this exact object shape for Prompt 1:

```json
{
  "sender_unknown_or_unverified": {
    "status": "present | absent",
    "evidence": ""
  },
  "sender_in_different_country_than_usa": {
    "status": "present | absent",
    "evidence": ""
  },
  "impersonates_authority_or_business": {
    "status": "present | absent",
    "evidence": ""
  },
  "unrealistic_offer_or_unexpected_windfall": {
    "status": "present | absent",
    "evidence": ""
  },
  "unsolicited_job_or_opportunity": {
    "status": "present | absent",
    "evidence": ""
  },
  "fabricated_context_or_wrong_number_pretext": {
    "status": "present | absent",
    "evidence": ""
  },
  "urgency_or_emotional_manipulation": {
    "status": "present | absent",
    "evidence": ""
  },
  "requests_sensitive_information": {
    "status": "present | absent",
    "evidence": ""
  },
  "requests_direct_payment_or_financial_transfer": {
    "status": "present | absent",
    "evidence": ""
  },
  "requests_external_or_off_platform_action": {
    "status": "present | absent",
    "evidence": ""
  }
}
```

---

# Prompt 1 — Literal Observable Checklist

```text
You are an information extraction system.

You will receive a text summary of an image, email, SMS, message, webpage, or social-media interaction.

Your task is NOT to decide whether the content is a scam.
Your task is ONLY to extract observable outcomes from the summary.

Important marker interaction rules:
1. fabricated_context_or_wrong_number_pretext is broader than explicit wrong-number messages.
Mark it present when the sender assumes or invents a context that has not been established in the summary, including:
- assumed personal familiarity
- planned meetings or social plans
- travel plans involving the recipient
- fake referrals or mutual contacts
- fake appointments, pickups, adoptions, reservations, or meetings
- fake account, subscription, membership, billing, renewal, invoice, receipt, charge, debit, auto-debit, saved payment method, transaction, order, delivery, warranty, software, antivirus, cloud/storage, or support issues

Do not require the words "wrong number." Do not require a link, payment request, credential request, or explicit threat.

2. Casual unknown-sender meetup messages can be fabricated context.
If an unknown sender asks about meeting, hiking, golfing, lunch, dinner, travel plans, appointments, pickup times, or similar plans without identifying a known relationship, mark fabricated_context_or_wrong_number_pretext present.

Example:
Unknown SMS: "I'll be in Austin next month for the tech summit. Are you still free for dinner or a round of tennis?"
=> fabricated_context_or_wrong_number_pretext: present
Reason: assumes a prior relationship or expected meetup.

3. Renewal, billing, and pending-charge messages can be fabricated context.
If a message says the recipient has a subscription, renewal, invoice, receipt, saved payment method, pending charge, debit, auto-debit, or billing issue, mark fabricated_context_or_wrong_number_pretext present unless the summary clearly establishes that the sender and account relationship are legitimate.

Example:
Email/SMS: "Your Norton protection plan is scheduled to renew today. The renewal fee will be charged to the card we have on file."
=> fabricated_context_or_wrong_number_pretext: present
Reason: assumes an existing security subscription, upcoming renewal, saved payment method, and automatic charge.

4. urgency_or_emotional_manipulation includes soft pressure, not only deadlines or threats.
Mark urgency_or_emotional_manipulation present for:
- deadlines, time pressure, pending charges, auto-debits, cancellation windows, financial loss, account/data loss, loss of access, penalties, threats, emergencies, or act-now language
- praise, gratitude, guilt, sympathy, obligation, flattery, authority pressure, or language that makes the recipient feel responsible for helping or following through
- vulnerable people, vulnerable animals, animal shelters, pet rescue, adoption, fostering, abandoned pets, sick pets, illness, hardship, emergencies, or rescue stories

A message does not need a deadline, threat, or panic wording to have urgency_or_emotional_manipulation present. Soft social pressure is enough when it creates responsibility, guilt, sympathy, gratitude, praise, or obligation.

If fabricated_context_or_wrong_number_pretext is present and the fabricated story involves vulnerable animals, rescue/adoption, hardship, illness, emergency, romance/flattery, praise, gratitude, guilt, obligation, account loss, data loss, financial loss, pending charges, renewal deadlines, cancellation deadlines, or loss of access, mark urgency_or_emotional_manipulation present too.

Example:
Unknown SMS: "The rescue coordinator said you agreed to foster two abandoned kittens this weekend. They are scared and need a safe home tonight. Thank you so much for helping them."
=> urgency_or_emotional_manipulation: present
Reason: uses vulnerable animals, urgency, gratitude, and obligation to pressure the recipient to follow through.

Example:
Unknown SMS: "Shirley told me that you would come to the pet shelter to adopt three lovely huskies. Thank you for your kind gesture. When will you pick them up?"
=> urgency_or_emotional_manipulation: present
Reason: uses vulnerable animals, gratitude/praise, pickup timing, and follow-through pressure to make the recipient feel responsible.

Example:
Email/SMS: "To avoid renewal or to modify your plan, please contact us at least 48 hours before the renewal date."
=> urgency_or_emotional_manipulation: present
Reason: uses a renewal/cancellation deadline and financial-loss pressure.

5. Same-thread replies are not external/off-platform actions.
Do not mark requests_external_or_off_platform_action present for replying in the same SMS/chat/email thread, including "reply yes," "text back," "message me," "send pictures here," or "send them pictures on text message." Mark present only for a separate URL, website, different phone number, email address, QR code, app, social/messaging platform, support line, or other outside destination.

Rules:
- Return only valid JSON.
- Do not include markdown, explanation, comments, or extra text.
- Do not give a scam/safe verdict.
- Do not give a probability, risk score, or recommendation.
- Do not tell the user what to do.
- Use only information stated in the input summary.
- For each field, set "status" to exactly one of: "present" or "absent".
- Use "present" only when the summary directly supports that outcome.
- Use "absent" when the summary does not directly support that outcome, including when the information is unclear, missing, cropped out, unverifiable, or only possible.
- In "evidence", quote or briefly paraphrase the specific part of the summary that supports a "present" status. For present fields, prefer evidence from the suspicious sender's message rather than app UI text or the recipient's reply when possible.
- If status is "absent", use an empty evidence string unless the summary explicitly gives negative evidence.
- For sender_unknown_or_unverified, mark present for bare phone numbers, raw emails, unknown senders, unsaved contacts, missing/unclear/malformed/generic senders, suspicious body/footer-only brand claims, or sender identities that do not clearly match a claimed business. Do not mark absent just because the message body contains a brand name, branded footer, copyright line, or signature.
- For sender_in_different_country_than_usa, mark present only when the summary directly shows non-USA origin evidence such as a non-US country/location, non-US country code other than +1, foreign address, foreign currency, foreign domain, or stated non-US origin. Do not mark present for +1 phone numbers, US area codes, US addresses, US states, or USD prices.
- For impersonates_authority_or_business, mark present only when there is a visible sender/claimed-company mismatch, spoofing clue, fake/nonexistent organization, lookalike sender/domain, fake authority/business claim, or explicit impersonation evidence. Mark present when an unknown sender, bare phone number, raw email, or unrelated sender claims to represent a known company, platform, employer, recruiter, support team, government agency, school, bank, healthcare provider, or organization. Mark present when a message claims one company/service but contains mismatched product names, branding, support identity, footer identity, phone numbers, addresses, team names, or account details, such as a McAfee renewal message listing Webroot Deluxe product details. Mark present for fake branded survey/reward/giveaway lures that use a known company's name, branding, copyright/footer, reward program, survey, customer notice, loyalty-style offer, or "exclusive reward offers" to imply affiliation. Do not mark present for normal business messages where sender and claimed company appear to match.
- For unrealistic_offer_or_unexpected_windfall, do not mark present for ordinary retail promotions, coupons, rebates, discounts, sales, loyalty rewards, service discounts, healthcare/medication discounts, move-in specials, newsletters, normal donation appeals, routine marketing, normal rewards from a matching known sender, or $X off advertisements. Mark present only for prize-like, free-money-like, grant-like, inheritance-like, guaranteed-payout, unexpected refund/compensation, investment-return, or clearly too-good-to-be-true offers.
- For fabricated_context_or_wrong_number_pretext, mark present when the summary shows a suspicious invented setup such as a wrong number, mistaken identity, fake referral, fake prior relationship, fake appointment/pickup/adoption/reservation, fake business/order/delivery/factory/customer issue, fake account/subscription/membership/antivirus plan/software plan/warranty/security/billing/billing summary/renewal/invoice/receipt/charge/debit/auto-debit/payment method/support case issue, fake cloud/storage issue, fake transaction, or other invented reason to reply, call, click, review, verify, cancel, modify, or act. Do not require a wrong-number setup, payment request, credential request, or link.
- For urgency_or_emotional_manipulation, mark present for hard urgency or soft emotional pressure. Hard urgency includes time pressure, deadlines, threats, penalties, fear, emergency, secrecy, account/data loss, financial loss, pending charges, cancellation deadlines, renewal deadlines, loss of access, and act-now language. Soft emotional pressure includes guilt, sympathy, praise, gratitude, obligation, romance/flattery, vulnerable people, vulnerable animals, animal shelters, rescue/adoption/fostering stories, abandoned pets, sick pets, illness, hardship, authority pressure, pickup timing, follow-through pressure, or language that makes the recipient feel responsible for helping, rescuing, caring, paying, cancelling, responding, meeting, picking up, or following through. A message does not need an explicit deadline, threat, or panic language to satisfy this marker. If fabricated_context_or_wrong_number_pretext is present and the fabricated story uses vulnerable animals, rescue/adoption, hardship, illness, emergency, romance/flattery, praise, gratitude, guilt, obligation, account loss, data loss, financial loss, pending charges, renewal deadlines, cancellation deadlines, loss of access, pickup timing, or follow-through pressure, mark urgency_or_emotional_manipulation present.
- For verification-code messages, do not mark impersonation, fabricated context, sensitive-information request, or urgency present merely because the message contains a code or ordinary expiration time. Mark those fields present only when there is separate direct evidence, such as a sender mismatch, fake account issue, request to share the code, threat, loss, or coercive pressure.
- For requests_direct_payment_or_financial_transfer, do not mark present merely because the message mentions a price, discount, refund, invoice, donation, gift card, reward, sweepstakes entry, charge, debit, renewal, subscription, receipt, payment method, total amount, auto-debit, or pending charge. Mark present only when the recipient is directly asked to pay, send money, transfer funds, approve or complete a charge, buy gift cards, send crypto, provide payment/banking details, or complete a direct payment/transfer step.
- For requests_external_or_off_platform_action, mark present only when the summary shows a visible URL, link, outside website, phone call/text request to a separate number, email contact, QR code, app download, social/messaging channel, contact exchange, CTA button, phone/support line to call or contact, or other outside destination/action. Do not mark present merely because a company/platform name appears or because the sender asks for a same-thread reply such as "reply yes," "reply interested," "send pictures," "text back," or "message back."

Input summary:
{{INPUT_SUMMARY}}

Return exactly this JSON structure:

{
  "sender_unknown_or_unverified": {
    "status": "present | absent",
    "evidence": ""
  },
  "sender_in_different_country_than_usa": {
    "status": "present | absent",
    "evidence": ""
  },
  "impersonates_authority_or_business": {
    "status": "present | absent",
    "evidence": ""
  },
  "unrealistic_offer_or_unexpected_windfall": {
    "status": "present | absent",
    "evidence": ""
  },
  "unsolicited_job_or_opportunity": {
    "status": "present | absent",
    "evidence": ""
  },
  "fabricated_context_or_wrong_number_pretext": {
    "status": "present | absent",
    "evidence": ""
  },
  "urgency_or_emotional_manipulation": {
    "status": "present | absent",
    "evidence": ""
  },
  "requests_sensitive_information": {
    "status": "present | absent",
    "evidence": ""
  },
  "requests_direct_payment_or_financial_transfer": {
    "status": "present | absent",
    "evidence": ""
  },
  "requests_external_or_off_platform_action": {
    "status": "present | absent",
    "evidence": ""
  }
}
```
