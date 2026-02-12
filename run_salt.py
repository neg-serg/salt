import sys
import warnings

# Suppress DeprecationWarnings from Salt internals (codecs.open, datetime.utcnow).
# Override showwarning instead of filterwarnings — Salt's init calls resetwarnings()
# which clears programmatic filters, but showwarning survives.
_orig_showwarning = warnings.showwarning


def _showwarning(msg, cat, filename, lineno, file=None, line=None):
    if cat is DeprecationWarning and "/salt/" in filename:
        return
    _orig_showwarning(msg, cat, filename, lineno, file, line)


warnings.showwarning = _showwarning


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

# 3. Streaming state output — print each state result as it completes.
#    Salt normally buffers all results and outputs them at the end via the
#    highstate outputter.  In local mode self.event() is a no-op, so there
#    is no built-in streaming.  We monkey-patch State.call_chunk() to emit
#    a terse one-liner after every state, then replace the final batch
#    display with a compact summary.
import salt.output  # noqa: E402
import salt.scripts  # noqa: E402
import salt.state  # noqa: E402

_orig_call_chunk = salt.state.State.call_chunk


def _streaming_call_chunk(self, low, running, chunks):
    before = set(running.keys())
    running = _orig_call_chunk(self, low, running, chunks)
    for tag in sorted(
        set(running.keys()) - before,
        key=lambda t: running[t].get("__run_num__", 0)
        if isinstance(running[t], dict)
        else 0,
    ):
        ret = running[tag]
        if not isinstance(ret, dict) or tag.startswith("__"):
            continue
        parts = tag.split("_|-")
        if len(parts) != 4:
            continue
        state, sid, _name, fun = parts
        r = ret.get("result")
        has_changes = bool(ret.get("changes"))
        if r is True:
            status = "Changed" if has_changes else "Clean"
        elif r is False:
            status = "Failed"
        else:
            status = "Differ"
        line = f"  Name: {sid} - Function: {state}.{fun} - Result: {status}"
        if "start_time" in ret:
            line += f" - Started: {ret['start_time']} - Duration: {ret['duration']} ms"
        print(line, flush=True)
    return running


salt.state.State.call_chunk = _streaming_call_chunk

# Replace the final batch display with a summary-only output.
_orig_display = salt.output.display_output


def _summary_display(data, out=None, opts=None, **kwargs):
    if out != "highstate" or not isinstance(data, dict):
        return _orig_display(data, out, opts, **kwargs)
    for minion, results in data.items():
        if not isinstance(results, dict):
            print(f"\n{minion}: {results}", flush=True)
            continue
        states = [r for r in results.values() if isinstance(r, dict)]
        succeeded = sum(1 for r in states if r.get("result") is True)
        failed = sum(1 for r in states if r.get("result") is False)
        changed = sum(
            1 for r in states if r.get("result") is True and r.get("changes")
        )
        total = len(states)
        duration = sum(r.get("duration", 0) for r in states)
        print(f"\nSummary for {minion}", flush=True)
        print(f"-------------", flush=True)
        print(f"Succeeded: {succeeded} (changed={changed})", flush=True)
        print(f"Failed:    {failed}", flush=True)
        print(f"-------------", flush=True)
        print(f"Total states run:     {total}", flush=True)
        print(f"Total run time: {duration:.3f} ms", flush=True)


salt.output.display_output = _summary_display

# 4. Run Salt
if __name__ == "__main__":
    salt.scripts.salt_call()
