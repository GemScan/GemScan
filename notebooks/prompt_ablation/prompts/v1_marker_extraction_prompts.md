# Zero-Shot Structured Extraction Prompts for Scam-Relevant Outcome Markers

These prompts are designed for prompt ablation with a small local language model. Each prompt asks the model to extract observable scam-relevant markers from a future input summary without producing a scam/safe verdict, risk score, probability, recommendation, or final user action.

All prompts use the same JSON schema and marker set:

```json
[
  "sender_unknown_or_unverified",
  "sender_in_different_country_than_usa",
  "identity_impersonation_or_mismatch",
  "unusual_offer_or_windfall",
  "unsolicited_job_or_opportunity",
  "requests_sensitive_information",
  "requests_money_or_financial_action",
  "requests_external_or_off_platform_action",
  "urgency_pressure_or_emotional_manipulation",
  "vague_generic_or_inconsistent_language",
  "technical_or_credibility_anomaly"
]
```

---

## Prompt 1 — Literal observable checklist

```text
You are an information extraction system.

You will receive a text summary of an image, email, SMS, message, webpage, or social-media interaction.

Your task is NOT to decide whether the content is a scam.
Your task is ONLY to extract observable outcomes from the summary.

Rules:
- Return only valid JSON.
- Do not include markdown, explanation, comments, or extra text.
- Do not give a scam/safe verdict.
- Do not give a probability, risk score, or recommendation.
- Do not tell the user what to do.
- Use only information stated in the input summary.
- For each field, set "status" to exactly one of: "present", "absent", or "unknown".
- Use "present" only when the summary clearly contains that outcome.
- Use "absent" only when the summary clearly shows that outcome is not present.
- Use "unknown" when the summary does not provide enough information.
- In "evidence", quote or briefly paraphrase the specific part of the summary that supports the status.
- If status is "unknown", use an empty evidence string unless the summary explains why it is unknown.

Input summary:
{{INPUT_SUMMARY}}

Return exactly this JSON structure:

{
  "sender_unknown_or_unverified": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "sender_in_different_country_than_usa": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "identity_impersonation_or_mismatch": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "unusual_offer_or_windfall": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "unsolicited_job_or_opportunity": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_sensitive_information": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_money_or_financial_action": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_external_or_off_platform_action": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "urgency_pressure_or_emotional_manipulation": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "vague_generic_or_inconsistent_language": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "technical_or_credibility_anomaly": {
    "status": "present | absent | unknown",
    "evidence": ""
  }
}
```

---

## Prompt 2 — Conservative extractor

```text
Extract structured observations from the following summary.

Important:
This is not a classification task. Do not say whether the message is scam, safe, suspicious, legitimate, or fraudulent. Only mark whether specific observable features are present, absent, or unknown.

Be conservative:
- Mark "present" only when the summary explicitly supports it.
- Mark "absent" only when the summary explicitly rules it out or clearly shows the opposite.
- Otherwise mark "unknown".
- Evidence must be short and grounded in the summary.
- Do not infer hidden motives.
- Do not recommend actions.
- Output only valid JSON with no surrounding text.

Summary:
{{INPUT_SUMMARY}}

Use this exact JSON object and these exact keys. For each "status", replace "present | absent | unknown" with exactly one value: "present", "absent", or "unknown".

{
  "sender_unknown_or_unverified": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "sender_in_different_country_than_usa": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "identity_impersonation_or_mismatch": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "unusual_offer_or_windfall": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "unsolicited_job_or_opportunity": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_sensitive_information": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_money_or_financial_action": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_external_or_off_platform_action": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "urgency_pressure_or_emotional_manipulation": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "vague_generic_or_inconsistent_language": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "technical_or_credibility_anomaly": {
    "status": "present | absent | unknown",
    "evidence": ""
  }
}
```

---

## Prompt 3 — Evidence-first observation pass

```text
Read the input summary and fill a JSON object with observed outcomes.

For each outcome:
1. Look for direct evidence in the summary.
2. Decide whether the outcome is "present", "absent", or "unknown".
3. Put the supporting phrase in "evidence".

Do not evaluate danger, fraud, trustworthiness, or user safety. Do not make a final judgment. Do not advise the user. The output is only for later deterministic scoring by another system.

Output requirements:
- Valid JSON only.
- No markdown.
- No extra keys.
- No missing keys.
- Status values must be exactly "present", "absent", or "unknown".
- Evidence values must be strings.

Input summary:
{{INPUT_SUMMARY}}

JSON output:

{
  "sender_unknown_or_unverified": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "sender_in_different_country_than_usa": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "identity_impersonation_or_mismatch": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "unusual_offer_or_windfall": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "unsolicited_job_or_opportunity": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_sensitive_information": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_money_or_financial_action": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_external_or_off_platform_action": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "urgency_pressure_or_emotional_manipulation": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "vague_generic_or_inconsistent_language": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "technical_or_credibility_anomaly": {
    "status": "present | absent | unknown",
    "evidence": ""
  }
}
```

---

## Prompt 4 — Field definitions included

```text
You are extracting observable features from a message summary.

Do not classify the message. Do not call it a scam, safe, real, fake, phishing, or legitimate. Do not provide a score or advice.

Use these meanings:
- sender_unknown_or_unverified: sender identity is missing, unclear, anonymous, spoofed-looking, unfamiliar, or not verified.
- sender_in_different_country_than_usa: sender phone number, address, domain, location, currency, country code, or stated origin indicates a country outside the USA.
- identity_impersonation_or_mismatch: someone claims to be a company, bank, government agency, platform, employer, support agent, executive, known person, or authority, or there is a mismatch between claimed identity and sender/details.
- unusual_offer_or_windfall: unexpected prize, refund, grant, inheritance, giveaway, investment return, romance benefit, compensation, or unusually favorable offer.
- unsolicited_job_or_opportunity: unexpected job, task, freelance role, recruiting message, business opportunity, investment opportunity, partnership, or earning opportunity.
- requests_sensitive_information: asks for passwords, codes, login, account access, ID numbers, personal data, financial data, private documents, or remote/device access.
- requests_money_or_financial_action: requests payment, fee, purchase, refund action, invoice payment, charge approval, gift card, crypto, bank transfer, deposit, donation, or other financial action.
- requests_external_or_off_platform_action: asks the recipient to call, text, email, visit a site, scan a QR code, download an app, use WhatsApp, Telegram, Signal, crypto wallet, or move to another channel/platform.
- urgency_pressure_or_emotional_manipulation: time pressure, deadline, penalty, account closure, legal threat, emergency, fear, secrecy, guilt, romance pressure, authority pressure, or pressure to act quickly.
- vague_generic_or_inconsistent_language: unclear details, generic greeting, missing context, mismatched names, odd wording, conflicting facts, incomplete explanation, or vague transaction/account context.
- technical_or_credibility_anomaly: suspicious links, shortened URLs, attachments, QR codes, unusual domains, mismatched branding, strange formatting, spelling/grammar issues, fake-looking invoice details, unusual phone numbers, or other credibility problems.

For every field, choose exactly one status:
- "present": directly supported by the summary.
- "absent": clearly not shown or clearly contradicted by the summary.
- "unknown": not enough information.

Return only valid JSON.

Summary:
{{INPUT_SUMMARY}}

Return exactly:

{
  "sender_unknown_or_unverified": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "sender_in_different_country_than_usa": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "identity_impersonation_or_mismatch": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "unusual_offer_or_windfall": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "unsolicited_job_or_opportunity": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_sensitive_information": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_money_or_financial_action": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_external_or_off_platform_action": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "urgency_pressure_or_emotional_manipulation": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "vague_generic_or_inconsistent_language": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "technical_or_credibility_anomaly": {
    "status": "present | absent | unknown",
    "evidence": ""
  }
}
```

---

## Prompt 5 — JSON validator emphasis

```text
Fill the JSON template using only facts visible in the input summary.

The result must be parseable JSON. Do not output any text before or after the JSON. Do not use trailing commas. Do not use comments. Do not wrap the JSON in markdown.

Forbidden outputs:
- Scam or safe verdict
- Risk score
- Probability
- Recommendation
- User instruction
- Explanation outside JSON

Allowed task:
Mark observable outcomes as "present", "absent", or "unknown".

Status rules:
- Use "present" when the input says or clearly shows the outcome.
- Use "absent" when the input clearly shows the outcome is not there.
- Use "unknown" when the input does not say enough.
- Evidence must be a short string from the input or a short grounded paraphrase.

Input summary:
{{INPUT_SUMMARY}}

Required JSON schema:

{
  "sender_unknown_or_unverified": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "sender_in_different_country_than_usa": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "identity_impersonation_or_mismatch": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "unusual_offer_or_windfall": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "unsolicited_job_or_opportunity": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_sensitive_information": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_money_or_financial_action": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_external_or_off_platform_action": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "urgency_pressure_or_emotional_manipulation": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "vague_generic_or_inconsistent_language": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "technical_or_credibility_anomaly": {
    "status": "present | absent | unknown",
    "evidence": ""
  }
}
```

---

## Prompt 6 — Mechanical extraction, no reasoning prose

```text
Perform mechanical extraction from the summary below.

Do not reason aloud. Do not explain. Do not classify. Do not say what the user should do.

For each JSON field:
- Read the summary.
- Check whether the named outcome is observable.
- Set status to "present", "absent", or "unknown".
- Add brief evidence copied or paraphrased from the summary.
- When unsure, choose "unknown".

Return only the JSON object. The JSON must contain exactly the keys shown below.

Summary:
{{INPUT_SUMMARY}}

{
  "sender_unknown_or_unverified": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "sender_in_different_country_than_usa": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "identity_impersonation_or_mismatch": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "unusual_offer_or_windfall": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "unsolicited_job_or_opportunity": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_sensitive_information": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_money_or_financial_action": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_external_or_off_platform_action": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "urgency_pressure_or_emotional_manipulation": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "vague_generic_or_inconsistent_language": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "technical_or_credibility_anomaly": {
    "status": "present | absent | unknown",
    "evidence": ""
  }
}
```

---

## Prompt 7 — Avoid conclusions and labels

```text
You are converting a summary into structured outcome flags.

Never use the output to label the message as scam, safe, fraud, phishing, real, fake, trustworthy, or suspicious. The JSON should contain only observations.

Use only the summary text. Do not assume facts that are not in the summary. A sender name, country code, company name, phone number, charge, link, attachment, deadline, or request may be evidence for a field, but it is not by itself a final conclusion.

Choose:
- "present" = the feature appears in the summary.
- "absent" = the summary makes clear the feature does not appear.
- "unknown" = the summary does not provide enough evidence.

Evidence:
- Keep evidence short.
- Use an empty string when there is no evidence.
- Do not include advice in evidence.

Summary to extract from:
{{INPUT_SUMMARY}}

Return only valid JSON in this exact structure:

{
  "sender_unknown_or_unverified": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "sender_in_different_country_than_usa": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "identity_impersonation_or_mismatch": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "unusual_offer_or_windfall": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "unsolicited_job_or_opportunity": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_sensitive_information": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_money_or_financial_action": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_external_or_off_platform_action": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "urgency_pressure_or_emotional_manipulation": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "vague_generic_or_inconsistent_language": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "technical_or_credibility_anomaly": {
    "status": "present | absent | unknown",
    "evidence": ""
  }
}
```

---

## Prompt 8 — Positive and negative evidence focus

```text
Analyze the summary only to determine whether specific observable outcomes are present, absent, or unknown.

You must not decide whether the message is harmful or legitimate. You must not give the user advice. You must not produce a score.

For each field:
- If the summary contains positive evidence of the outcome, status is "present".
- If the summary contains clear negative evidence or clearly lacks the outcome, status is "absent".
- If the summary is incomplete or unclear, status is "unknown".
- The evidence string should explain the status using only the summary.

Return one valid JSON object only.

Input:
{{INPUT_SUMMARY}}

Output schema:

{
  "sender_unknown_or_unverified": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "sender_in_different_country_than_usa": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "identity_impersonation_or_mismatch": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "unusual_offer_or_windfall": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "unsolicited_job_or_opportunity": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_sensitive_information": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_money_or_financial_action": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_external_or_off_platform_action": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "urgency_pressure_or_emotional_manipulation": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "vague_generic_or_inconsistent_language": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "technical_or_credibility_anomaly": {
    "status": "present | absent | unknown",
    "evidence": ""
  }
}
```

---

## Prompt 9 — Small-model friendly compact version

```text
Task: Extract facts from the summary. Do not classify the message.

Output only valid JSON. No markdown. No extra text.

Do not output:
- scam/safe verdict
- risk score
- probability
- recommendation
- final action

Use these status values only:
- "present": seen in the summary
- "absent": clearly not seen in the summary
- "unknown": not enough information

Evidence must be short and based only on the summary.

Summary:
{{INPUT_SUMMARY}}

Return this JSON:

{
  "sender_unknown_or_unverified": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "sender_in_different_country_than_usa": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "identity_impersonation_or_mismatch": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "unusual_offer_or_windfall": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "unsolicited_job_or_opportunity": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_sensitive_information": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_money_or_financial_action": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_external_or_off_platform_action": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "urgency_pressure_or_emotional_manipulation": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "vague_generic_or_inconsistent_language": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "technical_or_credibility_anomaly": {
    "status": "present | absent | unknown",
    "evidence": ""
  }
}
```

---

## Prompt 10 — Structured audit without judgment

```text
Create a structured audit of observable message features.

The audit must not contain a judgment. Do not state or imply that the message is a scam or safe. Do not estimate risk. Do not recommend any response.

Only inspect the summary. Some summaries are incomplete. Incomplete information should usually be marked "unknown", not guessed.

Use the exact JSON keys below:
- Keep all keys.
- Do not add keys.
- Use only "present", "absent", or "unknown" for status.
- Evidence must be a JSON string.
- Return valid JSON only.

Summary:
{{INPUT_SUMMARY}}

{
  "sender_unknown_or_unverified": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "sender_in_different_country_than_usa": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "identity_impersonation_or_mismatch": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "unusual_offer_or_windfall": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "unsolicited_job_or_opportunity": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_sensitive_information": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_money_or_financial_action": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "requests_external_or_off_platform_action": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "urgency_pressure_or_emotional_manipulation": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "vague_generic_or_inconsistent_language": {
    "status": "present | absent | unknown",
    "evidence": ""
  },
  "technical_or_credibility_anomaly": {
    "status": "present | absent | unknown",
    "evidence": ""
  }
}
```
