import sys
import os
import importlib.util

# 1. Setup PATH for dnf
os.environ["PATH"] = "/var/home/neg/.gemini/tmp/salt_deps:" + os.environ.get("PATH", "")

# 2. Local dependencies
sys.path.insert(0, "/var/home/neg/.gemini/tmp/salt_deps")
sys.path.insert(0, "/var/home/neg/.local/lib/python3.14/site-packages")

# 3. Emulate removed 'crypt' module
class MockCrypt:
    def __init__(self):
        try:
            import passlib.hash as hash
            self.hash = hash
        except ImportError:
            self.hash = None
        
        # Emulate methods for Salt
        class Method:
            def __init__(self, name, ident):
                self.name = name
                self.ident = ident
        
        self.methods = [
            Method("sha512", "6"),
            Method("sha256", "5"),
            Method("md5", "1"),
            Method("crypt", "")
        ]

    def crypt(self, word, salt):
        from passlib.hash import sha512_crypt, sha256_crypt, md5_crypt, des_crypt
        if salt.startswith("$6$"): return sha512_crypt.hash(word, salt=salt.split('$')[2])
        if salt.startswith("$5$"): return sha256_crypt.hash(word, salt=salt.split('$')[2])
        if salt.startswith("$1$"): return md5_crypt.hash(word, salt=salt.split('$')[2])
        return des_crypt.hash(word, salt=salt)

sys.modules['crypt'] = MockCrypt()

# 4. Emulate removed 'spwd' module
class MockSpwd:
    def getspnam(self, name):
        # Ideally this should read /etc/shadow, but for dry-run and basic checks
        # Salt often just checks for function existence.
        # Implementation of real password changes would be more complex.
        raise KeyError(f"spwd.getspnam emulation: user {name} lookup failed or not implemented")

sys.modules['spwd'] = MockSpwd()

# 5. Force patch salt.utils.pycrypto
try:
    import salt.utils
    patch_path = "/var/home/neg/.gemini/tmp/salt_deps/salt/utils/pycrypto.py"
    if os.path.exists(patch_path):
        spec = importlib.util.spec_from_file_location("salt.utils.pycrypto", patch_path)
        pycrypto = importlib.util.module_from_spec(spec)
        sys.modules["salt.utils.pycrypto"] = pycrypto
        spec.loader.exec_module(pycrypto)
except Exception as e:
    pass

# 6. Run Salt
import salt.scripts
if __name__ == "__main__":
    salt.scripts.salt_call()