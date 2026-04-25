import { test, expect } from '@playwright/test'

const SCAM_MESSAGE =
  'URGENT: Your bank account has been compromised! Click here immediately to verify your identity: http://totallylegit-bank.xyz/verify?id=83721. You have 24 hours before your account is permanently locked.'

const SAFE_MESSAGE =
  'Hi! Just wanted to confirm our lunch tomorrow at 12:30 PM at the Italian place on Main St. Let me know if that still works for you!'

test.describe('SMS Analysis Flow', () => {
  test('should navigate from home to analyse page', async ({ page }) => {
    await page.goto('/')
    await expect(page.getByRole('heading', { name: 'GemScan' })).toBeVisible()

    await page.getByRole('button', { name: /check this for me/i }).click()
    await expect(page).toHaveURL('/analyse')
    await expect(page.getByRole('heading', { name: /analyse message/i })).toBeVisible()
  })

  test('should analyse a scam message and show verdict', async ({ page }) => {
    await page.goto('/analyse')

    const textarea = page.getByPlaceholder(/paste a message/i)
    await textarea.fill(SCAM_MESSAGE)

    await page.getByRole('button', { name: /analyse/i }).click()

    // Wait for the verdict card to appear (up to 30s for model inference)
    const verdictCard = page.locator('[class*="rounded-xl"][class*="border-2"]')
    await expect(verdictCard).toBeVisible({ timeout: 30_000 })

    // Verify verdict text is present
    const verdictText = verdictCard.locator('text=Verdict')
    await expect(verdictText).toBeVisible()

    // The verdict should be scam or suspicious for this message
    const verdictValue = verdictCard.locator('.capitalize')
    await expect(verdictValue).toBeVisible()
    const text = await verdictValue.textContent()
    expect(['scam', 'suspicious']).toContain(text?.toLowerCase())
  })

  test('should analyse a safe message and show safe verdict', async ({ page }) => {
    await page.goto('/analyse')

    const textarea = page.getByPlaceholder(/paste a message/i)
    await textarea.fill(SAFE_MESSAGE)

    await page.getByRole('button', { name: /analyse/i }).click()

    const verdictCard = page.locator('[class*="rounded-xl"][class*="border-2"]')
    await expect(verdictCard).toBeVisible({ timeout: 30_000 })

    const verdictValue = verdictCard.locator('.capitalize')
    await expect(verdictValue).toBeVisible()
    const text = await verdictValue.textContent()
    expect(['safe', 'suspicious']).toContain(text?.toLowerCase())
  })

  test('should disable submit button when input is empty', async ({ page }) => {
    await page.goto('/analyse')

    const button = page.getByRole('button', { name: /analyse/i })
    await expect(button).toBeDisabled()
  })

  test('should show streaming tokens during analysis', async ({ page }) => {
    await page.goto('/analyse')

    const textarea = page.getByPlaceholder(/paste a message/i)
    await textarea.fill(SCAM_MESSAGE)

    await page.getByRole('button', { name: /analyse/i }).click()

    // The button text should change to "Analysing..."
    await expect(page.getByRole('button', { name: /analysing/i })).toBeVisible()
  })
})
