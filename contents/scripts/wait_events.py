"""Wait for the first engine event, print it and exit.

Usage: wait_events.py SECONDS COMMAND

COMMAND is a streaming `{engine} events ...` shell command. One sleeping
process replaces a new `events --until` query every few seconds. Exits 0 with
no output when SECONDS pass quietly, with the event line when one arrives, and
with the command's own status when it fails before printing anything. The
helper also exits when the widget that started it goes away.
"""
import os, select, signal, subprocess, sys, time

def main():
    deadline = time.monotonic() + max(1, int(sys.argv[1]))
    parent = os.getppid()
    child = subprocess.Popen(sys.argv[2], shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             start_new_session=True)
    def stop():
        try: os.killpg(child.pid, signal.SIGTERM)
        except OSError: pass
        try: child.wait(timeout=2)
        except subprocess.TimeoutExpired:
            try: os.killpg(child.pid, signal.SIGKILL)
            except OSError: pass
    try:
        while True:
            left = deadline - time.monotonic()
            if left <= 0 or os.getppid() != parent:
                stop(); return 0
            ready, _, _ = select.select([child.stdout], [], [], min(left, 5))
            if not ready: continue
            line = child.stdout.readline()
            if line:
                stop(); sys.stdout.write(line.decode(errors="replace")); return 0
            # The stream ended without an event: report the command's failure.
            code = child.wait()
            sys.stderr.write(child.stderr.read().decode(errors="replace"))
            return code or 1
    finally:
        if child.poll() is None: stop()

if __name__ == "__main__":
    sys.exit(main())
