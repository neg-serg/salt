"""Python 3.13+ compatibility shims for Salt (PEP 594 module removals).

Call patch() before importing any salt module. Installs:
  - MockCrypt: replaces removed `crypt` module using passlib
  - MockSpwd: replaces removed `spwd` module
  - Warning filter: suppresses Salt's own DeprecationWarnings
  - Multiprocessing fork fix: Python 3.14 changed default to forkserver
"""
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
