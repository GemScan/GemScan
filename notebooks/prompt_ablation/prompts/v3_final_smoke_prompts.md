# Scam Marker Extraction Prompts — Prompts 1 and 2 Only

These prompts extract observable scam-relevant markers from an input summary. They are intended for small-model prompt testing and downstream deterministic scoring.

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
- Evidence must be one short string, never a list or array.
- Use only one `"evidence"` key per field.
- If a field is absent, use an empty evidence string unless the summary explicitly gives negative evidence.
- Ignore phone/app UI text as evidence, such as `Text Message • SMS`, `Delete`, `Reply`, `Forward`, `More`, `Report Spam`, or warnings like `If you did not expect this message...`.

## Marker Set

```json
[
  "unknown_sender",
  "foreign_sender",
  "impersonation",
  "windfall",
  "opportunity",
  "pretexting",
  "urgency",
  "sensitive_info",
  "financial_transfer",
  "external_action"
]
```

## Compact Field Definitions

- `unknown_sender`: Present for a raw email, bare phone number, unknown/unsaved contact, blank/hidden sender, or sender/header that does not match the claimed brand. Absent for a short code or sender name that appears to match one routine brand OTP or marketing message. Do not use app spam warnings, footer addresses, or body signatures as sender proof.

- `foreign_sender`: Present only when the sender or message origin is directly shown as outside the USA, such as a non-US country/location, non-US country code, foreign address, foreign currency, foreign domain, or stated non-US origin.

- `impersonation`: Present when a raw, missing, unknown, or mismatched sender claims a brand, company, service, platform, agency, support team, authority, or executive in an account, billing, subscription, payment, support, prize, reward, survey, job, or security story. Absent for person-only messages and ordinary ads, coupons, donations, events, rentals, tours, tickets, or routine messages from a matching sender.

- `windfall`: Present for unusually high pay, free money, prizes, grants, lottery, inheritance, large rewards, valuable survey rewards, or too-good-to-be-true offers. Absent for normal discounts, coupons, sale prices, loyalty rewards, gift cards for donations, donation incentives, move-in specials, tickets, tours, or routine marketing.

- `opportunity`: Present only for jobs, remote tasks, recruiting, freelance work, business offers, investment offers, partnerships, or easy-earning offers. Absent for shopping, tickets, tours, apartments, cruises, events, coupons, donations, surveys, or ordinary ads.

- `pretexting`: Present when the message uses a story about a wrong number, prior relationship, job, prize, survey reward, account issue, bill, subscription, renewal, payment issue, delivery, order, refund, or grant to get a reply, click, payment, or information. Do not prove the story false. Absent for ordinary ads, sales, coupons, donation drives, event notices, rentals, tours, tickets, OTP codes, or opt-out text.

- `urgency`: Present for final warnings, threats, penalties, account loss, data loss, blocked access, deletion, payment failure, forced billing, emergency, secrecy, or act-now pressure tied to account, money, safety, prize, job, survey reward, or sensitive information. Absent for normal sale deadlines, coupon expiration, event dates, ticket dates, donation deadlines, appointment times, rental promos, or verification-code expiration.

- `sensitive_info`: Present when the message asks the recipient to provide, enter, update, review, confirm, or verify passwords, codes, account details, payment details, bank/card data, ID, SSN, documents, private data, name, identity, or relationship information. Absent when a verification code is only shown and the message does not ask the recipient to share or enter it.

- `financial_transfer`: Present when the recipient is asked to pay, send money, approve a charge, pay a fee/invoice, buy gift cards, send crypto, provide payment/banking details, or accept an auto-debit/charge. Absent for prices, discounts, gift cards, rewards, coupons, donation incentives, sweepstakes entries, or non-money donations.

- `external_action`: Present for a visible URL, link, domain, website, QR code, app download, phone/email contact, outside messaging/social channel, or button/action text such as review, update, apply, join, book, take survey, or visit site. The current SMS/email channel itself does not count.

## Required JSON Structure

Use this exact object shape for both prompts:

```json
{
  "unknown_sender": {
    "status": "present | absent",
    "evidence": ""
  },
  "foreign_sender": {
    "status": "present | absent",
    "evidence": ""
  },
  "impersonation": {
    "status": "present | absent",
    "evidence": ""
  },
  "windfall": {
    "status": "present | absent",
    "evidence": ""
  },
  "opportunity": {
    "status": "present | absent",
    "evidence": ""
  },
  "pretexting": {
    "status": "present | absent",
    "evidence": ""
  },
  "urgency": {
    "status": "present | absent",
    "evidence": ""
  },
  "sensitive_info": {
    "status": "present | absent",
    "evidence": ""
  },
  "financial_transfer": {
    "status": "present | absent",
    "evidence": ""
  },
  "external_action": {
    "status": "present | absent",
    "evidence": ""
  }
}
```

---

---

# Prompt 2 — Conservative Binary Extractor

```text
Extract structured observations from the following summary.

Important:
This is not a classification task. Do not say whether the message is scam, safe, suspicious, legitimate, or fraudulent. Only mark whether specific observable features are present or absent.

Be conservative:
- Mark "present" only when the summary explicitly supports it.
- Mark "absent" when the summary does not explicitly support it.
- Do not infer hidden motives.
- Do not treat possibilities as facts.
- If the feature is unclear, missing, cropped out, unverifiable, or not stated, mark "absent".
- Evidence must be one short string, never a list or array.
- Use only one "evidence" key per field.
- Do not recommend actions.
- Output only valid JSON with no surrounding text.
- Ignore phone/app UI text as evidence, such as Text Message, Delete, Reply, Forward, More, Report Spam, or warnings like "If you did not expect this message..."
- For unknown_sender, mark present for a raw email, bare phone number, unknown/unsaved contact, blank/hidden sender, or sender/header that does not match the claimed brand. Mark absent for a short code or sender name that appears to match one routine brand OTP or marketing message. Do not use app spam warnings, footer addresses, or body signatures as sender proof.
- For foreign_sender, mark present only when the summary directly shows non-USA origin evidence such as a non-US country/location, non-US country code, foreign address, foreign currency, foreign domain, or stated non-US origin.
- For impersonation, mark present when unknown_sender is present and the message names a brand, company, service, platform, agency, support team, authority, or executive in a job, prize, reward, survey, account, billing, subscription, payment, support, or security story. Mark absent for person-only messages and ordinary ads, coupons, donations, events, rentals, tours, tickets, or routine messages from a matching sender.
- For windfall, mark present for unusually high pay, free money, prizes, grants, lottery, inheritance, large rewards, valuable survey rewards, or too-good-to-be-true offers. Mark absent for normal discounts, coupons, sale prices, loyalty rewards, gift cards for donations, donation incentives, move-in specials, tickets, tours, or routine marketing.
- For opportunity, mark present only for jobs, remote tasks, recruiting, freelance work, business offers, investment offers, partnerships, or easy-earning offers. Mark absent for shopping, tickets, tours, apartments, cruises, events, coupons, donations, surveys, or ordinary ads.
- For pretexting, mark present for a wrong-number story, prior-relationship story, job story, prize story, survey-reward story, account issue, bill, subscription, renewal, payment issue, delivery, order, refund, or grant used to get a reply, click, payment, or information. Do not prove the story false. Mark absent for ordinary ads, sales, coupons, donation drives, event notices, rentals, tours, tickets, OTP codes, or opt-out text.
- For urgency, mark present for final warnings, threats, penalties, account loss, data loss, blocked access, deletion, payment failure, forced billing, emergency, secrecy, or act-now pressure tied to account, money, safety, prize, job, survey reward, or sensitive information. Mark absent for normal sale deadlines, coupon expiration, event dates, ticket dates, donation deadlines, appointment times, rental promos, or verification-code expiration.
- For sensitive_info, mark present when the message asks the recipient to provide, enter, update, review, confirm, or verify passwords, codes, account details, payment details, bank/card data, ID, SSN, documents, private data, name, identity, or relationship information. Mark absent when a verification code is only shown and the message does not ask the recipient to share or enter it.
- For financial_transfer, mark present when the recipient is asked to pay, send money, approve a charge, pay a fee/invoice, buy gift cards, send crypto, provide payment/banking details, or accept an auto-debit/charge. Mark absent for prices, discounts, gift cards, rewards, coupons, donation incentives, sweepstakes entries, or non-money donations.
- For external_action, mark present for a visible URL, link, domain, website, QR code, app download, phone/email contact, outside messaging/social channel, or button/action text such as review, update, apply, join, book, take survey, or visit site. The current SMS/email channel itself does not count.

Summary:
{{INPUT_SUMMARY}}

Use this exact JSON object and these exact keys. For each "status", replace "present | absent" with exactly one value: "present" or "absent".

{
  "unknown_sender": {
    "status": "present | absent",
    "evidence": ""
  },
  "foreign_sender": {
    "status": "present | absent",
    "evidence": ""
  },
  "impersonation": {
    "status": "present | absent",
    "evidence": ""
  },
  "windfall": {
    "status": "present | absent",
    "evidence": ""
  },
  "opportunity": {
    "status": "present | absent",
    "evidence": ""
  },
  "pretexting": {
    "status": "present | absent",
    "evidence": ""
  },
  "urgency": {
    "status": "present | absent",
    "evidence": ""
  },
  "sensitive_info": {
    "status": "present | absent",
    "evidence": ""
  },
  "financial_transfer": {
    "status": "present | absent",
    "evidence": ""
  },
  "external_action": {
    "status": "present | absent",
    "evidence": ""
  }
}
```
