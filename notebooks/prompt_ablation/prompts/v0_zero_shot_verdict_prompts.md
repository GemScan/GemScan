# Zero-Shot Scam Classification Prompts With Verdict

## 1. Risk-Factor Scoring Prompt

```text
You are a binary scam classifier. Classify the provided summary as either scam or safe.

Use risk-factor scoring. Increase scam_probability when the summary includes deception, impersonation, phishing, fake billing, fake refund, fake support, fake security warnings, suspicious payment demands, unusual phone numbers, pressure tactics, or requests to contact an unknown party.

Return only valid JSON with exactly these fields:
{
  "verdict": "",
  "scam_probability": 0.0,
  "action": ""
}

Rules:
- verdict must be exactly "scam" or "safe".
- scam_probability must be a number from 0.0 to 1.0.
- Use verdict "scam" when scam_probability is 0.50 or higher.
- Use verdict "safe" when scam_probability is below 0.50.
- action must be short and consistent with the verdict.
- Do not include explanations, markdown, or extra fields.

Input summary:
{{SUMMARY}}
```

## 2. Conservative Scam Detection Prompt

```text
Classify the input summary for user safety.

Be conservative: if the summary contains credible signs of fraud, impersonation, phishing, fake billing, fake support, or a suspicious request to call, reply, pay, refund, verify, or provide information, treat it as scam. If the summary is ordinary or lacks suspicious indicators, treat it as safe.

Return only valid JSON with exactly this schema:
{
  "verdict": "",
  "scam_probability": 0.0,
  "action": ""
}

Constraints:
- verdict must be only "scam" or "safe".
- scam_probability must be between 0.0 and 1.0.
- verdict must match the probability: scam if >= 0.50, safe if < 0.50.
- action should be one short recommendation, such as "do not respond to sender", "do not call the listed number", "verify through the official website", "safe to interact with sender", or "no action needed".
- Output JSON only.

Summary to classify:
{{SUMMARY}}
```

## 3. Evidence-Based Classification Prompt

```text
You are evaluating a text summary of an image, email, or message. Decide whether it is scam or safe based only on evidence in the summary.

Classify as scam when the evidence suggests deceptive intent, impersonation, fraudulent billing, fake support, fake refund, phishing, suspicious contact instructions, or manipulation. Classify as safe when the evidence is benign or insufficiently suspicious.

Return exactly one JSON object:
{
  "verdict": "",
  "scam_probability": 0.0,
  "action": ""
}

Output rules:
- verdict must be "scam" or "safe".
- scam_probability must be numeric from 0.0 to 1.0.
- If scam_probability >= 0.50, verdict must be "scam".
- If scam_probability < 0.50, verdict must be "safe".
- action must be short and practical.
- Do not mention evidence or reasoning in the output.
- Do not add any fields.

Input:
{{SUMMARY}}
```

## 4. Phishing-Focused Prompt

```text
Classify the summary as scam or safe, focusing on phishing risk.

Phishing indicators include impersonating a trusted company, urgent account/security claims, requests to verify information, suspicious links or phone numbers, unexpected invoices, password/account warnings, payment demands, refund claims, or pressure to act quickly.

Return only this JSON structure:
{
  "verdict": "",
  "scam_probability": 0.0,
  "action": ""
}

Requirements:
- verdict must be exactly "scam" or "safe".
- scam_probability must be a number in the range 0.0 to 1.0.
- Use "scam" when scam_probability is 0.50 or greater.
- Use "safe" when scam_probability is less than 0.50.
- action must match the risk level.
- No explanation. No markdown. JSON only.

Summary:
{{SUMMARY}}
```

## 5. Billing-Scam-Focused Prompt

```text
You are a scam detector for billing, subscription, refund, and payment messages.

Classify the summary as scam if it describes unexpected charges, subscription renewals, invoices, refunds, payment problems, payment demands, support phone numbers, or account notices that appear deceptive, manipulative, impersonating, or suspicious. Classify as safe if it appears ordinary and non-deceptive.

Return only valid JSON with exactly these keys:
{
  "verdict": "",
  "scam_probability": 0.0,
  "action": ""
}

Rules:
- verdict is exactly "scam" or "safe".
- scam_probability is a number from 0.0 to 1.0.
- verdict must be "scam" if scam_probability >= 0.50.
- verdict must be "safe" if scam_probability < 0.50.
- action must be short, for example "do not call the listed number" or "verify through the official website".
- Output nothing except the JSON object.

Input summary:
{{SUMMARY}}
```

## 6. Contact-Information Analysis Prompt

```text
Classify the provided summary as scam or safe by paying special attention to contact information.

Suspicious contact signals include unofficial phone numbers, unknown support lines, requests to call or text, mismatched company/contact details, personal names used as support contacts, external reply instructions, or pressure to contact immediately.

Return only valid JSON:
{
  "verdict": "",
  "scam_probability": 0.0,
  "action": ""
}

Strict rules:
- verdict must be only "scam" or "safe".
- scam_probability must be between 0.0 and 1.0.
- verdict and scam_probability must agree: scam for >= 0.50, safe for < 0.50.
- action must be concise and consistent with verdict.
- Do not output reasoning or extra text.

Summary:
{{SUMMARY}}
```

## 7. Impersonation Detection Prompt

```text
You are detecting possible impersonation scams from summaries.

Classify as scam when a summary suggests someone is pretending to be a company, bank, software provider, delivery service, government agency, employer, support team, friend, executive, or authority figure for deceptive purposes. Also classify as scam for fake invoices, fake refunds, account threats, and suspicious payment/contact requests.

Return exactly this JSON object and nothing else:
{
  "verdict": "",
  "scam_probability": 0.0,
  "action": ""
}

Validation rules:
- verdict must be "scam" or "safe".
- scam_probability must be a numeric value from 0.0 to 1.0.
- verdict must be "scam" if scam_probability is 0.50 or higher.
- verdict must be "safe" if scam_probability is below 0.50.
- action must be a short recommended user action.

Input summary:
{{SUMMARY}}
```

## 8. Uncertainty-Aware Prompt

```text
Classify the summary as scam or safe. Account for uncertainty.

Use high scam_probability for strong scam indicators. Use medium probability for suspicious but incomplete evidence. Use low probability when the content appears normal or there is not enough evidence of deception.

Return only JSON with these exact fields:
{
  "verdict": "",
  "scam_probability": 0.0,
  "action": ""
}

Rules:
- verdict must be exactly "scam" or "safe".
- scam_probability must be from 0.0 to 1.0.
- If scam_probability >= 0.50, verdict must be "scam".
- If scam_probability < 0.50, verdict must be "safe".
- When uncertain but suspicious, prefer protective actions such as "verify through the official website".
- Do not include analysis, caveats, or extra fields.

Summary:
{{SUMMARY}}
```

## 9. User-Safety-First Prompt

```text
You are a user-safety classifier. Your goal is to prevent the user from interacting with scams.

Classify the summary as scam if it contains suspicious billing, support, refund, security, account, payment, impersonation, urgency, manipulation, or contact-request signals. Classify as safe only if the summary is ordinary, benign, or insufficiently suspicious.

Return only this valid JSON:
{
  "verdict": "",
  "scam_probability": 0.0,
  "action": ""
}

Output constraints:
- verdict must be "scam" or "safe" only.
- scam_probability must be a number between 0.0 and 1.0.
- verdict must equal "scam" when scam_probability >= 0.50.
- verdict must equal "safe" when scam_probability < 0.50.
- action must be brief and protective.
- No prose outside JSON.

Input:
{{SUMMARY}}
```

## 10. Minimal Small-Model Prompt

```text
Classify this summary as scam or safe.

Scam means fraudulent, deceptive, impersonating, phishing, fake billing, fake refund, fake support, fake security warning, suspicious payment demand, or manipulative contact request.
Safe means ordinary, benign, non-deceptive, or not suspicious enough.

Return JSON only:
{
  "verdict": "",
  "scam_probability": 0.0,
  "action": ""
}

Rules:
verdict = "scam" if scam_probability >= 0.50.
verdict = "safe" if scam_probability < 0.50.
Use only "scam" or "safe" for verdict.
No extra text.

Summary:
{{SUMMARY}}
```

## 11. Red-Flag Checklist Prompt

```text
Evaluate the summary using a red-flag checklist.

Red flags: unexpected charge, subscription renewal, invoice, refund, support number, security alert, account problem, urgent deadline, threat, prize, gift card, crypto, wire transfer, password request, personal data request, company impersonation, mismatched sender, or unknown contact method.

Return only one JSON object:
{
  "verdict": "",
  "scam_probability": 0.0,
  "action": ""
}

Rules:
- verdict must be "scam" or "safe".
- scam_probability must be from 0.0 to 1.0.
- More red flags should generally mean higher scam_probability.
- verdict must be "scam" at 0.50 or above.
- verdict must be "safe" below 0.50.
- action must be short and consistent.
- Do not list the red flags in the output.

Summary:
{{SUMMARY}}
```

## 12. Threshold-Based Prompt

```text
You are a binary classifier. Estimate scam_probability, then assign verdict using the threshold.

Definitions:
- scam: deceptive, fraudulent, impersonating, phishing, fake billing, fake refund, fake support, fake security warning, suspicious payment demand, or manipulative contact request.
- safe: ordinary, benign, non-deceptive, or insufficiently suspicious.

Threshold:
- scam_probability >= 0.50 means verdict "scam".
- scam_probability < 0.50 means verdict "safe".

Return only valid JSON with exactly these fields:
{
  "verdict": "",
  "scam_probability": 0.0,
  "action": ""
}

Do not output any explanation or additional fields.

Input summary:
{{SUMMARY}}
```

## 13. Action-Oriented Prompt

```text
Classify the summary and choose the safest short user action.

Use verdict "scam" for suspicious or deceptive content, including phishing, impersonation, fake billing, fake support, fake refunds, fake security warnings, payment demands, or manipulative contact requests. Use verdict "safe" for ordinary or benign content.

Return only this JSON:
{
  "verdict": "",
  "scam_probability": 0.0,
  "action": ""
}

Rules:
- verdict must be exactly "scam" or "safe".
- scam_probability must be a number from 0.0 to 1.0.
- verdict must match probability: "scam" if >= 0.50, "safe" if < 0.50.
- For scam, action should warn against responding, calling, clicking, paying, or sharing information.
- For safe, action should be calm, such as "safe to interact with sender" or "no action needed".
- JSON only.

Summary:
{{SUMMARY}}
```

## 14. No-Assumptions Prompt

```text
Classify only from the provided summary. Do not assume facts not stated.

A scam classification is appropriate when the summary itself indicates deception, fraud, impersonation, phishing, fake billing, fake support, fake refund, fake security warning, suspicious payment demand, or manipulative contact request. If the summary lacks enough suspicious evidence, classify as safe.

Return exactly this JSON and nothing else:
{
  "verdict": "",
  "scam_probability": 0.0,
  "action": ""
}

Required consistency:
- verdict must be either "scam" or "safe".
- scam_probability must be between 0.0 and 1.0.
- verdict must be "scam" when scam_probability >= 0.50.
- verdict must be "safe" when scam_probability < 0.50.
- action must be a short recommendation.

Input summary:
{{SUMMARY}}
```

## 15. High-Recall Scam Prompt

```text
Detect scams with high recall. It is worse to miss a likely scam than to flag a suspicious message for verification.

Classify as scam when the summary includes likely phishing, impersonation, fake billing, fake subscription renewal, fake refund, fake tech support, fake security alert, urgent account warning, suspicious payment request, or suspicious contact instruction. Classify as safe only when the summary is clearly benign or not suspicious enough.

Output only valid JSON:
{
  "verdict": "",
  "scam_probability": 0.0,
  "action": ""
}

Rules:
- verdict must be "scam" or "safe" only.
- scam_probability must be a number from 0.0 to 1.0.
- Use verdict "scam" when scam_probability >= 0.50.
- Use verdict "safe" when scam_probability < 0.50.
- action must be short and protective.
- No explanation.

Summary:
{{SUMMARY}}
```

## 16. Low-Hallucination JSON Prompt

```text
Task: classify the summary as scam or safe.

Do not explain. Do not add details. Do not invent sender identity, links, numbers, or intent beyond the summary.

Return only this JSON object:
{
  "verdict": "",
  "scam_probability": 0.0,
  "action": ""
}

Allowed verdict values: "scam", "safe".
Allowed scam_probability range: 0.0 to 1.0.
Consistency rule: probability >= 0.50 requires verdict "scam"; probability < 0.50 requires verdict "safe".
Action must be one short phrase and must match the verdict.

Scam includes phishing, fraud, impersonation, fake billing, fake support, fake refund, fake security warning, suspicious payment demand, or manipulative contact request.
Safe means benign or insufficiently suspicious.

Summary:
{{SUMMARY}}
```

## 17. Company-Impersonation Prompt

```text
Classify the summary as scam or safe, emphasizing company impersonation.

Scam signs include a message claiming to be from a known company but using suspicious billing claims, support numbers, refund promises, security threats, renewal charges, account warnings, payment requests, or contact instructions. Safe content is ordinary, expected, and not deceptive.

Return only valid JSON with exactly:
{
  "verdict": "",
  "scam_probability": 0.0,
  "action": ""
}

Rules:
- verdict must be exactly "scam" or "safe".
- scam_probability must be numeric, 0.0 through 1.0.
- verdict must be "scam" if scam_probability >= 0.50.
- verdict must be "safe" if scam_probability < 0.50.
- action must be brief, such as "verify through the official website" or "no action needed".
- JSON only. No extra text.

Input summary:
{{SUMMARY}}
```

## 18. Payment-Demand Prompt

```text
You are classifying summaries of messages for payment-demand scams.

Treat suspicious demands for payment, billing corrections, subscription charges, invoices, refunds, account debits, wire transfers, gift cards, crypto, or urgent financial action as scam when they appear deceptive or unverified. Treat normal non-deceptive content as safe.

Return only this JSON:
{
  "verdict": "",
  "scam_probability": 0.0,
  "action": ""
}

Rules:
- verdict must be "scam" or "safe".
- scam_probability must be from 0.0 to 1.0.
- scam_probability >= 0.50 means verdict must be "scam".
- scam_probability < 0.50 means verdict must be "safe".
- action must be a short user recommendation.
- No markdown or explanation.

Summary:
{{SUMMARY}}
```

## 19. Safe-Default With Suspicion Override Prompt

```text
Classify the summary as safe unless there are meaningful scam indicators. Override to scam when there are signs of deception, impersonation, phishing, fake billing, fake refund, fake support, fake security warning, suspicious payment demand, or manipulative contact request.

Return only one JSON object with exactly these fields:
{
  "verdict": "",
  "scam_probability": 0.0,
  "action": ""
}

Rules:
- verdict must be either "scam" or "safe".
- scam_probability must be a number between 0.0 and 1.0.
- If scam_probability is 0.50 or higher, verdict must be "scam".
- If scam_probability is lower than 0.50, verdict must be "safe".
- action must be short and consistent with the verdict.
- Output JSON only.

Input:
{{SUMMARY}}
```

## 20. Compact Production Prompt

```text
Classify the summary for scam risk.

Labels:
- scam: deceptive, fraudulent, impersonating, phishing, fake billing, fake refund, fake support, fake security warning, suspicious payment demand, or manipulative contact request.
- safe: ordinary, benign, non-deceptive, or insufficiently suspicious.

Output only valid JSON:
{
  "verdict": "",
  "scam_probability": 0.0,
  "action": ""
}

Constraints:
- verdict: exactly "scam" or "safe".
- scam_probability: number from 0.0 to 1.0.
- verdict must be "scam" when scam_probability >= 0.50.
- verdict must be "safe" when scam_probability < 0.50.
- action: short phrase consistent with verdict.
- No extra keys. No explanation.

Summary:
{{SUMMARY}}
```
