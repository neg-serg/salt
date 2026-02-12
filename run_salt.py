import sys
import warnings

# Suppress DeprecationWarnings from Salt internals (codecs.open, datetime.utcnow)
warnings.filterwarnings("ignore", category=DeprecationWarning, module=r"salt\.")


# 1. Emulate removed 'crypt' module (Python 3.13+)
class MockCrypt:
    def __init__(self):
        try:
            import passlib.hash as hash

            self.hash = hash
        except ImportError:
            self.hash = None
            print("Warning: passlib not found. Salt user password management might fail.")

        # Emulate methods for Salt
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
        if not self.hash:
            raise ImportError("passlib is required for crypt emulation")
        from passlib.hash import des_crypt, md5_crypt, sha256_crypt, sha512_crypt

        if salt.startswith("$6$"):
            return sha512_crypt.hash(word, salt=salt.split("$")[2])
        if salt.startswith("$5$"):
            return sha256_crypt.hash(word, salt=salt.split("$")[2])
        if salt.startswith("$1$"):
            return md5_crypt.hash(word, salt=salt.split("$")[2])
        return des_crypt.hash(word, salt=salt)


sys.modules["crypt"] = MockCrypt()


# 2. Emulate removed 'spwd' module
class MockSpwd:
    def getspnam(self, name):
        # Ideally this should read /etc/shadow, but for dry-run and basic checks
        # Salt often just checks for function existence.
        raise KeyError(f"spwd.getspnam emulation: user {name} lookup failed or not implemented")


sys.modules["spwd"] = MockSpwd()

# 3. Run Salt
import salt.scripts  # noqa: E402

if __name__ == "__main__":
    salt.scripts.salt_call()
