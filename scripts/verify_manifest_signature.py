#!/usr/bin/env python3
"""
Verify the Ed25519 signature of manifest.json.

This script reads manifest.json, extracts the 'signature' field,
verifies it against the remaining manifest content using the
MANIFEST_PUBLIC_KEY environment variable, and exits with code 0
on success or 1 on failure.

Usage:
    MANIFEST_PUBLIC_KEY=<hex-encoded-public-key> python scripts/verify_manifest_signature.py

Dependencies:
    pip install pynacl
"""

import json
import os
import sys
from pathlib import Path

try:
    from nacl.signing import VerifyKey
    from nacl.exceptions import BadSignatureError
except ImportError:
    print("ERROR: PyNaCl is required. Install with: pip install pynacl")
    sys.exit(1)


MANIFEST_PATH = Path(__file__).resolve().parent.parent / "manifest.json"


def load_manifest() -> dict:
    """Load and parse manifest.json."""
    if not MANIFEST_PATH.exists():
        print(f"ERROR: Manifest file not found at {MANIFEST_PATH}")
        sys.exit(1)

    with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def get_signing_payload(manifest: dict) -> bytes:
    """
    Produce the canonical signing payload from the manifest.

    The signature field is excluded from the payload. All other fields
    are serialized with sorted keys and no extra whitespace to ensure
    deterministic output.
    """
    payload = {k: v for k, v in manifest.items() if k != "signature"}
    return json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")


def get_public_key() -> bytes:
    """Read the Ed25519 public key from the environment."""
    key_hex = os.environ.get("MANIFEST_PUBLIC_KEY")
    if not key_hex:
        print("ERROR: MANIFEST_PUBLIC_KEY environment variable is not set")
        sys.exit(1)

    try:
        return bytes.fromhex(key_hex)
    except ValueError:
        print("ERROR: MANIFEST_PUBLIC_KEY is not valid hex")
        sys.exit(1)


def verify_signature(manifest: dict, public_key_bytes: bytes) -> bool:
    """
    Verify the Ed25519 signature on the manifest.

    Returns True if the signature is valid, False otherwise.
    """
    signature_hex = manifest.get("signature", "")
    if not signature_hex:
        print("ERROR: Manifest has no signature field or it is empty")
        return False

    try:
        signature = bytes.fromhex(signature_hex)
    except ValueError:
        print("ERROR: Signature is not valid hex")
        return False

    payload = get_signing_payload(manifest)

    try:
        verify_key = VerifyKey(public_key_bytes)
        verify_key.verify(payload, signature)
        return True
    except BadSignatureError:
        return False
    except Exception as exc:
        print(f"ERROR: Verification failed with unexpected error: {exc}")
        return False


def main() -> None:
    """Entry point."""
    print(f"Verifying manifest signature: {MANIFEST_PATH}")

    manifest = load_manifest()

    # Validate manifest structure
    required_fields = ["version", "models"]
    for field in required_fields:
        if field not in manifest:
            print(f"ERROR: Manifest is missing required field: {field}")
            sys.exit(1)

    # Validate model entries
    models = manifest.get("models", [])
    if not models:
        print("ERROR: Manifest contains no models")
        sys.exit(1)

    required_model_fields = ["id", "sha256", "sizeBytes", "downloadUrl", "downloadPolicy"]
    for model in models:
        for field in required_model_fields:
            if field not in model:
                print(f"ERROR: Model '{model.get('id', 'unknown')}' is missing field: {field}")
                sys.exit(1)

        # Validate downloadPolicy
        if model["downloadPolicy"] not in ("required", "on_demand"):
            print(
                f"ERROR: Model '{model['id']}' has invalid downloadPolicy: "
                f"{model['downloadPolicy']}"
            )
            sys.exit(1)

        # Validate sha256 length
        if len(model["sha256"]) != 64:
            print(f"ERROR: Model '{model['id']}' has invalid sha256 hash length")
            sys.exit(1)

    print(f"Manifest structure valid: {len(models)} model(s) found")

    # Verify signature
    public_key_bytes = get_public_key()

    if verify_signature(manifest, public_key_bytes):
        print("SUCCESS: Manifest signature is valid")
        sys.exit(0)
    else:
        print("FAILURE: Manifest signature verification failed")
        sys.exit(1)


if __name__ == "__main__":
    main()
