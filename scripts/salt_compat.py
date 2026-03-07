"""Python 3.13+ compatibility shims for Salt (PEP 594 module removals).

Call patch() before importing any salt module. Installs:
  - MockCrypt: replaces removed `crypt` module using passlib
  - MockSpwd: replaces removed `spwd` module
  - Warning filter: suppresses Salt's own DeprecationWarnings
  - Multiprocessing fork fix: Python 3.14 changed default to forkserver
  - URL fix: Python 3.14 urlunparse normalization breaks salt:// URL creation
"""

import importlib
import importlib.abc
import importlib.machinery
import multiprocessing
import sys
import warnings


def patch():
    """Install stdlib shims and warning filters for Salt compatibility."""
    # Python 3.14 changed default multiprocessing start method from 'fork' to
    # 'forkserver' on Linux.  Salt's parallel state execution (parallel: True)
    # passes unpicklable objects through call_parallel and its Process.__new__
    # only sets pickling attrs on spawning_platform().  Force 'fork' to restore
    # the behavior Salt was designed for.
    if sys.version_info >= (3, 14):
        try:
            multiprocessing.set_start_method("fork")
        except RuntimeError:
            pass  # already set

    # Suppress Salt's own DeprecationWarnings (noisy, not actionable)
    _orig = warnings.showwarning

    def _filtered(msg, cat, filename, lineno, file=None, line=None):
        if cat is DeprecationWarning and "/salt/" in (filename or ""):
            return
        _orig(msg, cat, filename, lineno, file, line)

    warnings.showwarning = _filtered

    # PEP 594: crypt module removed in Python 3.13+, Salt still imports it
    class _MockCrypt:
        def __init__(self):
            try:
                import passlib.hash as _hash

                self._hash = _hash
            except ImportError:
                self._hash = None

            class Method:
                def __init__(self, name, ident):
                    self.name = name
                    self.ident = ident

            self.methods = [
                Method("sha512", "6"),
                Method("sha256", "5"),
                Method("md5", "1"),
                Method("crypt", ""),
            ]

        def crypt(self, word, salt):
            if not self._hash:
                raise ImportError("passlib required")
            from passlib.hash import des_crypt, md5_crypt, sha256_crypt, sha512_crypt

            if salt.startswith("$6$"):
                return sha512_crypt.hash(word, salt=salt.split("$")[2])
            if salt.startswith("$5$"):
                return sha256_crypt.hash(word, salt=salt.split("$")[2])
            if salt.startswith("$1$"):
                return md5_crypt.hash(word, salt=salt.split("$")[2])
            return des_crypt.hash(word, salt=salt)

    sys.modules["crypt"] = _MockCrypt()

    # PEP 594: spwd module removed in Python 3.13+
    class _MockSpwd:
        def getspnam(self, name):
            raise KeyError(f"spwd: {name}")

    sys.modules["spwd"] = _MockSpwd()

    # Python 3.14: urlunparse normalizes file:///path differently, breaking
    # salt.utils.url.create(). Instead of a fragile sed patch on the installed
    # source, monkey-patch the function at import time via a meta path finder.
    if sys.version_info >= (3, 14):
        _install_url_patch()


def _patched_url_create(path, saltenv=None):
    """Replacement for salt.utils.url.create that handles Python 3.14+ urlunparse."""
    from urllib.parse import urlunparse

    import salt.utils.data

    path = path.replace("\\", "/")
    query = f"saltenv={saltenv}" if saltenv else ""
    url = salt.utils.data.decode(urlunparse(("file", "", path, "", query, "")))
    # Python 3.14 urlunparse may produce "file:path" instead of "file:///path".
    # Use split+lstrip to robustly extract the path portion regardless of format.
    return "salt://{}".format(url.split("file:", 1)[1].lstrip("/"))


class _SaltUrlPatchFinder(importlib.abc.MetaPathFinder):
    """Meta path finder that patches salt.utils.url.create after import."""

    def find_module(self, fullname, path=None):
        if fullname == "salt.utils.url":
            return self
        return None

    def load_module(self, fullname):
        # Remove ourselves to avoid recursion
        sys.meta_path.remove(self)
        # Let the real import happen
        mod = importlib.import_module(fullname)
        # Patch the create function
        mod.create = _patched_url_create
        return mod


def _install_url_patch():
    """Install a meta path finder that patches salt.utils.url on first import."""
    sys.meta_path.insert(0, _SaltUrlPatchFinder())
