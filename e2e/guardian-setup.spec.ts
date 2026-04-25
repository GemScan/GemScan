import { test, expect } from '@playwright/test'

test.describe('Guardian Mode Setup', () => {
  test('should navigate to guardian setup page', async ({ page }) => {
    await page.goto('/guardian/setup')
    await expect(page.getByRole('heading', { name: /guardian mode/i })).toBeVisible()
  })

  test('should show toggle for enabling guardian mode', async ({ page }) => {
    await page.goto('/guardian/setup')

    const toggle = page.getByRole('switch')
    await expect(toggle).toBeVisible()
  })

  test('should enable guardian mode and show contact input', async ({ page }) => {
    await page.goto('/guardian/setup')

    const toggle = page.getByRole('switch')

    // Initially off
    const initialChecked = await toggle.getAttribute('aria-checked')
    if (initialChecked === 'true') {
      // If already enabled, click to disable first
      await toggle.click()
      await expect(toggle).toHaveAttribute('aria-checked', 'false')
    }

    // Enable guardian mode
    await toggle.click()
    await expect(toggle).toHaveAttribute('aria-checked', 'true')

    // Contact input should appear
    const contactInput = page.getByPlaceholder(/enter contact id/i)
    await expect(contactInput).toBeVisible()
  })

  test('should hide contact input when guardian mode is disabled', async ({ page }) => {
    await page.goto('/guardian/setup')

    const toggle = page.getByRole('switch')

    // Enable first
    const initialChecked = await toggle.getAttribute('aria-checked')
    if (initialChecked !== 'true') {
      await toggle.click()
    }

    // Verify input is visible
    const contactInput = page.getByPlaceholder(/enter contact id/i)
    await expect(contactInput).toBeVisible()

    // Disable guardian mode
    await toggle.click()

    // Contact input should disappear
    await expect(contactInput).not.toBeVisible()
  })

  test('should save guardian mode settings and redirect', async ({ page }) => {
    await page.goto('/guardian/setup')

    const toggle = page.getByRole('switch')

    // Enable guardian mode
    const initialChecked = await toggle.getAttribute('aria-checked')
    if (initialChecked !== 'true') {
      await toggle.click()
    }

    // Enter a contact ID
    const contactInput = page.getByPlaceholder(/enter contact id/i)
    await contactInput.fill('+1234567890')

    // Click save
    await page.getByRole('button', { name: /save/i }).click()

    // Should redirect to home
    await expect(page).toHaveURL('/')
  })

  test('should display guardian description text', async ({ page }) => {
    await page.goto('/guardian/setup')

    await expect(
      page.getByText(/guardian mode lets a trusted contact/i)
    ).toBeVisible()
  })
})
