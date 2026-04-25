# GitHub Actions Secrets

Configuration guide for CI/CD secrets used in GemScan's GitHub Actions workflows.

---

## Required Secrets

| Secret | Used in | Description |
|--------|---------|-------------|
| `IOS_CERTIFICATE_BASE64` | `release.yml` | Base64-encoded .p12 distribution certificate |
| `IOS_CERTIFICATE_PASSWORD` | `release.yml` | Password for the .p12 certificate |
| `IOS_PROVISIONING_PROFILE_BASE64` | `release.yml` | Base64-encoded .mobileprovision file |
| `IOS_PROVISIONING_PROFILE_NAME` | `release.yml` | Name of the provisioning profile |
| `IOS_SIGNING_IDENTITY` | `release.yml` | Certificate common name for code signing |
| `ASC_API_KEY_ID` | `release.yml` | App Store Connect API key ID |
| `ASC_ISSUER_ID` | `release.yml` | App Store Connect issuer ID |
| `CODECOV_TOKEN` | `ci.yml` | Codecov upload token |

---

## How to Set Up Each Secret

### IOS_CERTIFICATE_BASE64

The distribution certificate used to sign the app for TestFlight and App Store.

1. Open **Keychain Access** on your Mac.
2. Find the certificate named "Apple Distribution: Your Team (XXXXXXXXXX)".
3. Right-click > **Export Items** > save as `certificate.p12` with a strong password.
4. Encode to base64:
   ```bash
   base64 -i certificate.p12 -o certificate_base64.txt
   ```
5. Copy the contents of `certificate_base64.txt` into the GitHub secret.
6. Delete both files after uploading:
   ```bash
   rm certificate.p12 certificate_base64.txt
   ```

### IOS_CERTIFICATE_PASSWORD

The password you set when exporting the .p12 file above.

### IOS_PROVISIONING_PROFILE_BASE64

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/profiles/list).
2. Download the App Store distribution provisioning profile for `com.gemscan`.
3. Encode to base64:
   ```bash
   base64 -i GemScan_AppStore.mobileprovision -o profile_base64.txt
   ```
4. Copy the contents into the GitHub secret.
5. Delete after uploading.

**Note:** Each iOS extension requires its own provisioning profile. If extensions are included in the release workflow, add additional secrets:
- `IOS_SMSFILTER_PROFILE_BASE64`
- `IOS_CALLDIRECTORY_PROFILE_BASE64`
- `IOS_SHARE_PROFILE_BASE64`
- `IOS_SAFARIBLOCKER_PROFILE_BASE64`

### IOS_PROVISIONING_PROFILE_NAME

The name of the provisioning profile as it appears in Apple Developer Portal (e.g., `GemScan App Store`).

### IOS_SIGNING_IDENTITY

The common name of the signing certificate. Find it with:

```bash
security find-identity -v -p codesigning
```

Example value: `Apple Distribution: Your Team Name (XXXXXXXXXX)`

### ASC_API_KEY_ID

1. Go to [App Store Connect > Users and Access > Keys](https://appstoreconnect.apple.com/access/api).
2. Click the **+** button to create a new key.
3. Name: `GemScan CI`, Access: `App Manager`.
4. Copy the **Key ID** (e.g., `ABC1234DEF`).
5. Download the `.p8` key file — store it securely (you can only download it once).

### ASC_ISSUER_ID

On the same App Store Connect API keys page, the **Issuer ID** is displayed at the top (a UUID like `12345678-abcd-efgh-ijkl-123456789012`).

### CODECOV_TOKEN

1. Go to [codecov.io](https://codecov.io) and sign in with GitHub.
2. Navigate to the GemScan repository settings.
3. Copy the **Repository Upload Token**.

---

## Adding Secrets to GitHub

1. Go to the repository on GitHub.
2. Navigate to **Settings > Secrets and variables > Actions**.
3. Click **New repository secret**.
4. Enter the name and value.
5. Click **Add secret**.

For organization-level secrets, go to **Organization Settings > Secrets and variables > Actions**.

---

## How Secrets Are Used in Workflows

```yaml
# Example from release.yml
jobs:
  build:
    runs-on: macos-14
    steps:
      - name: Install certificate
        env:
          CERTIFICATE_BASE64: ${{ secrets.IOS_CERTIFICATE_BASE64 }}
          CERTIFICATE_PASSWORD: ${{ secrets.IOS_CERTIFICATE_PASSWORD }}
        run: |
          CERT_PATH=$RUNNER_TEMP/certificate.p12
          echo "$CERTIFICATE_BASE64" | base64 --decode > "$CERT_PATH"
          security create-keychain -p "" build.keychain
          security import "$CERT_PATH" -k build.keychain \
            -P "$CERTIFICATE_PASSWORD" -T /usr/bin/codesign
          security set-key-partition-list -S apple-tool:,apple: \
            -s -k "" build.keychain

      - name: Install provisioning profile
        env:
          PROFILE_BASE64: ${{ secrets.IOS_PROVISIONING_PROFILE_BASE64 }}
        run: |
          PROFILE_PATH=$RUNNER_TEMP/profile.mobileprovision
          echo "$PROFILE_BASE64" | base64 --decode > "$PROFILE_PATH"
          mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
          cp "$PROFILE_PATH" ~/Library/MobileDevice/Provisioning\ Profiles/

      - name: Upload to TestFlight
        env:
          ASC_API_KEY_ID: ${{ secrets.ASC_API_KEY_ID }}
          ASC_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
        run: |
          xcrun altool --upload-app \
            --file GemScan.ipa \
            --apiKey "$ASC_API_KEY_ID" \
            --apiIssuer "$ASC_ISSUER_ID"
```

---

## Rotation Policy

| Secret | Rotation frequency | Trigger |
|--------|-------------------|---------|
| `IOS_CERTIFICATE_BASE64` | Annually | Certificate expiration (365 days) |
| `IOS_CERTIFICATE_PASSWORD` | Annually | With certificate renewal |
| `IOS_PROVISIONING_PROFILE_BASE64` | Annually | Profile expiration |
| `ASC_API_KEY_ID` | As needed | Team member offboarding |
| `ASC_ISSUER_ID` | Never changes | Tied to App Store Connect account |
| `CODECOV_TOKEN` | As needed | Token compromise |

### Rotation Checklist

- [ ] Generate new certificate/profile in Apple Developer Portal.
- [ ] Export and encode as described above.
- [ ] Update the GitHub secret value.
- [ ] Trigger a test build to verify signing works.
- [ ] Revoke the old certificate/profile.
- [ ] Delete local copies of exported files.

---

## Security Notes

- Never commit secrets to the repository (use `.gitignore` for `.p12`, `.p8`, `.mobileprovision`).
- Never print secrets in workflow logs (GitHub masks them, but avoid `echo` of secret values).
- Use environment-level secrets for staging vs production if needed.
- Limit secret access to the `release.yml` workflow using [environment protection rules](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment).
