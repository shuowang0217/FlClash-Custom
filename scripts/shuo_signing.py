#!/usr/bin/env python3
"""SHUO Android signing: permanent key, encrypted at rest; never print password."""
import argparse
import base64
import json
import os
import pathlib
import re
import subprocess
import tempfile
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.scrypt import Scrypt

AAD = b"SHUO-FLCLASH-ANDROID-KEY-V1"
ALIAS = "shuo-release"
CIPHER_PATH = pathlib.Path("android/signing/shuo-release.jks.enc")

def b64(buf):
    return base64.b64encode(buf).decode("ascii")

def un64(s):
    return base64.b64decode(s, validate=True)

def password():
    value = os.getenv("SHUO_SIGNING_PASSWORD", "")
    if not re.fullmatch(r"[A-Za-z0-9_-]{32,}", value):
        raise SystemExit("Set GitHub Actions secret SHUO_SIGNING_PASSWORD to 32+ random ASCII letters, digits, - or _. Do not log it.")
    return value

def key(value, salt):
    return Scrypt(salt=salt, length=32, n=32768, r=8, p=1).derive(value.encode())

def keytool(*args, show_fingerprint=False):
    run = subprocess.run(["keytool", *args], check=True,
                         text=True, capture_output=True)
    if show_fingerprint:
        fingerprints = [line.strip() for line in run.stdout.splitlines()
                        if "SHA256:" in line]
        if not fingerprints:
            raise RuntimeError("Signing certificate verification failed.")
        print("Permanent SHUO certificate: " + fingerprints[0])

def verify(path):
    keytool("-list", "-v", "-keystore", str(path),
            "-storepass:env", "SHUO_SIGNING_PASSWORD",
            "-alias", ALIAS, show_fingerprint=True)

def generate(value, encrypted):
    if encrypted.exists():
        raise SystemExit("Signing key already exists. Refusing to regenerate.")
    with tempfile.TemporaryDirectory() as temp:
        plain = pathlib.Path(temp) / "shuo.jks"
        keytool("-genkeypair", "-noprompt", "-keystore", str(plain),
                "-storetype", "PKCS12", "-alias", ALIAS,
                "-keyalg", "RSA", "-keysize", "3072",
                "-sigalg", "SHA256withRSA", "-validity", "10000",
                "-dname", "CN=SHUO Custom, O=SHUO, C=CN",
                "-storepass:env", "SHUO_SIGNING_PASSWORD",
                "-keypass:env", "SHUO_SIGNING_PASSWORD")
        verify(plain)
        salt, nonce = os.urandom(16), os.urandom(12)
        cipher = AESGCM(key(value, salt)).encrypt(nonce, plain.read_bytes(), AAD)
        payload = {"version": 1, "cipher": "AES-256-GCM", "kdf": "scrypt",
                   "salt": b64(salt), "nonce": b64(nonce), "data": b64(cipher)}
        encrypted.parent.mkdir(parents=True, exist_ok=True)
        encrypted.write_text(json.dumps(payload, indent=2) + "\n")
    print("Committed files must include encrypted JSON only, NEVER the original JKS.")

def restore(value, encrypted, output, properties):
    j = json.loads(encrypted.read_text())
    if j.get("version") != 1 or j.get("cipher") != "AES-256-GCM":
        raise SystemExit("Unexpected signing key format.")
    plain = AESGCM(key(value, un64(j["salt"]))).decrypt(
        un64(j["nonce"]), un64(j["data"]), AAD)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(plain)
    output.chmod(0o600)
    verify(output)
    if properties:
        contents = properties.read_text() if properties.exists() else ""
        if re.search(r"(?m)^(keyAlias|keyPassword|storePassword)\s*=", contents):
            raise SystemExit("Release signing settings already present.")
        with properties.open("a") as f:
            f.write("\nkeyAlias=shuo-release\n")
            f.write("storePassword=" + value + "\n")
            f.write("keyPassword=" + value + "\n")

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("operation", choices=("generate", "restore"))
    p.add_argument("--encrypted", type=pathlib.Path, default=CIPHER_PATH)
    p.add_argument("--output", type=pathlib.Path, default=pathlib.Path("android/app/keystore.jks"))
    p.add_argument("--properties", type=pathlib.Path)
    args = p.parse_args()
    pw = password()
    if args.operation == "generate":
        generate(pw, args.encrypted)
    else:
        restore(pw, args.encrypted, args.output, args.properties)
