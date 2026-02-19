#!/usr/bin/env python3
"""Salt-call wrapper with compatibility shims for Python 3.14+.

Patches:
  - Suppresses DeprecationWarnings from Salt internals
  - MockCrypt: replaces removed `crypt` module (PEP 594) using passlib
  - MockSpwd: replaces removed `spwd` module (PEP 594)

Usage:
  python3 scripts/salt-runner.py --config-dir=.salt_runtime --local state.sls ...
"""
import sys
import warnings

# Suppress Salt's own DeprecationWarnings (noisy, not actionable)
_orig = warnings.showwarning

def _w(msg, cat, filename, lineno, file=None, line=None):
    if cat is DeprecationWarning and "/salt/" in (filename or ""):
        return
    _orig(msg, cat, filename, lineno, file, line)

warnings.showwarning = _w


# PEP 594: crypt module removed in Python 3.13+, Salt still imports it
class MockCrypt:
    def __init__(self):
        try:
            import passlib.hash as _hash
            self.hash = _hash
        except ImportError:
            self.hash = None

        class Method:
            def __init__(self, n, i):
                self.name = n
                self.ident = i

        self.methods = [
            Method("sha512", "6"),
            Method("sha256", "5"),
            Method("md5", "1"),
            Method("crypt", ""),
        ]

    def crypt(self, word, salt):
        if not self.hash:
            raise ImportError("passlib required")
        from passlib.hash import des_crypt, md5_crypt, sha256_crypt, sha512_crypt

        if salt.startswith("$6$"):
            return sha512_crypt.hash(word, salt=salt.split("$")[2])
        if salt.startswith("$5$"):
            return sha256_crypt.hash(word, salt=salt.split("$")[2])
        if salt.startswith("$1$"):
            return md5_crypt.hash(word, salt=salt.split("$")[2])
        return des_crypt.hash(word, salt=salt)


sys.modules["crypt"] = MockCrypt()


# PEP 594: spwd module removed in Python 3.13+
class MockSpwd:
    def getspnam(self, name):
        raise KeyError(f"spwd: {name}")


sys.modules["spwd"] = MockSpwd()

import salt.scripts

salt.scripts.salt_call()
