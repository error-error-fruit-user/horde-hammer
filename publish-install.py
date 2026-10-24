#!/usr/bin/env python3
"""Publish Horde Hammer, then install the pk3 just published into tdl's wads.

usage: python3 publish-install.py [--accept] [--no-build] [--dir DIR]

First it says, under a red warning, exactly what it will do, and asks before doing any of it
(--accept goes ahead without asking). Then it packs hh/ into published/releases/horde-hammer.pk3 with
publish.py (or with --no-build packs nothing), and copies the pk3 into DIR/wads, the wad pool tdl
offers: DIR is tdl's folder, by default where tdl-install puts it for you (~/.local/opt/tdl, or
%LOCALAPPDATA%\\Programs\\tdl on Windows). The pk3 is always packed straight from hh/, so
there is nothing else to build from source.

Dependency-free Python 3.8+.
"""

import argparse
import os
import platform
import shutil
import subprocess
import sys
import textwrap
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PK3 = "horde-hammer.pk3"
WINDOWS = platform.system() == "Windows"
WHAT = "Horde Hammer"
# The installer it runs, which takes --computer-speak too
INSTALLER = None


# The journal: everything this does, with the time since it began (what it plans and is told,
# every command and all it prints, every file it puts somewhere), added to JOURNAL on each run.
JOURNAL = os.path.join(HERE, "published", "artifacts", "publish-install.log")
BEGAN = time.monotonic()
# Blender's line for every frame it renders, which would bury the rest
CHATTER = ("Fra:", "Saved:", "Time:", "Read blend")


def note(line):
    """Writes `line` down in the journal."""
    os.makedirs(os.path.dirname(JOURNAL), exist_ok=True)
    with open(JOURNAL, "a", encoding="utf-8") as journal:
        for part in line.splitlines() or [""]:
            journal.write(f"[{time.monotonic() - BEGAN:8.3f}s] {part}\n")


# The voice it speaks in, from installation-groans: the workspace's checkout beside this project,
# else GitHub. Toiling Through Hell unless told --computer-speak; without one (or Python older than
# 3.11, which can't read TOML), plain lines.
GROANS = "https://raw.githubusercontent.com/error-error-fruit-user/installation-groans/main/"
VOICE = {}


def speak_in(name):
    """Speaks in the installation-groans voice `name` (a file name) from now on, if it is found."""
    global VOICE
    try:
        import tomllib
    except ImportError:
        return
    path = os.path.join(os.path.dirname(HERE), "installation-groans", name)
    try:
        if os.path.isfile(path):
            with open(path, encoding="utf-8") as source:
                text = source.read()
        else:
            import urllib.request
            with urllib.request.urlopen(GROANS + name, timeout=5) as answer:
                text = answer.read().decode()
        VOICE = tomllib.loads(text)
    except Exception:
        VOICE = {}


def tell(event, plain, **fills):
    """Says `event` as one of the voice's phrases for it, picked at random and filled from `fills`,
    or `plain` without one; the journal keeps the plain line either way. Now and then the voice
    interjects (its [interjection])."""
    import random
    phrases = VOICE.get("phrases", {}).get(event) or []
    if not phrases:
        print(plain, flush=True)
        note(plain)
        return
    said = random.choice(phrases)
    for name, value in fills.items():
        said = said.replace("{" + name + "}", str(value))
    said = said[:1].upper() + said[1:]
    print(said, flush=True)
    note(f"{said}  ({plain})")
    interjection = VOICE.get("interjection", {})
    if interjection.get("phrases") and random.random() < float(interjection.get("chance", 0)):
        colors = {"yellow": 33, "green": 32, "blue": 34, "magenta": 35, "cyan": 36, "white": 37}
        code = colors.get(interjection.get("color", "red"), 31)
        shout = random.choice(interjection["phrases"])
        tty = sys.stdout.isatty() and "NO_COLOR" not in os.environ
        print(f"\033[1;{code}m{shout}\033[0m" if tty else shout, flush=True)
        note(shout)


def not_mine(folders):
    """The first file in `folders` (and the folders themselves) owned by someone else, as a run
    with sudo leaves them; None when every one is this user's."""
    if WINDOWS:
        return None
    for folder in folders:
        for root, dirs, files in os.walk(folder):
            for path in [root] + [os.path.join(root, name) for name in dirs + files]:
                try:
                    if os.lstat(path).st_uid != os.getuid():
                        return path
                except OSError:
                    pass
    return None


def check_owner(folders):
    """Stops, saying how to take them back, when anything in `folders` isn't this user's."""
    if WINDOWS or os.getuid() == 0:
        return
    stranger = not_mine(folders)
    if stranger is not None:
        import getpass
        fix = "sudo chown -R " + getpass.getuser() + " " + " ".join(folders)
        tell("problem", f"{stranger} isn't yours (a run with sudo left it)", problem=f"{stranger} isn't yours")
        sys.exit(f"Something in published/ belongs to another user, root most likely (a run with sudo "
                 f"leaves it): nothing can replace it. Take it back with:\n  {fix}")


def run(command, cwd=HERE):
    """Runs `command`, its output shown as it comes (prompts included) and written down, with how it
    ended. Raises CalledProcessError if it failed."""
    shown = " ".join(str(part) for part in command)
    tell("run", f"+ {shown}", command=shown)
    note(f"+ {shown}  (in {cwd})")
    process = subprocess.Popen(command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    pending, quiet = b"", 0
    while True:
        chunk = process.stdout.read1(4096)
        if not chunk:
            break
        sys.stdout.buffer.write(chunk)
        sys.stdout.buffer.flush()
        *lines, pending = (pending + chunk).split(b"\n")
        for line in lines:
            text = line.decode(errors="replace").rstrip("\r")
            if text.startswith(CHATTER):
                quiet += 1
            else:
                note("  | " + text)
    if pending:
        note("  | " + pending.decode(errors="replace"))
    code = process.wait()
    if quiet:
        note(f"  ({quiet} lines of Blender's frame by frame progress left out)")
    note(f"  ended with code {code}")
    if code:
        raise subprocess.CalledProcessError(code, command)


def default_dir():
    if WINDOWS:
        return os.path.join(os.environ["LOCALAPPDATA"], "Programs", "tdl")
    return os.path.join(os.path.expanduser("~"), ".local", "opt", "tdl")


def warning(lines):
    """`lines` under a red '--- Warning ---' (plain where the output isn't a terminal)."""
    if WINDOWS:
        os.system("")  # lets the Windows console show colors
    color = sys.stdout.isatty() and "NO_COLOR" not in os.environ
    print("\033[31m--- Warning ---\033[0m" if color else "--- Warning ---")
    note("--- Warning ---")
    for line in lines:
        note(line)
    width = min(shutil.get_terminal_size().columns, 100)
    for line in lines:
        # a step's later lines line up under its text
        hang = len(line) - len(line.lstrip(" -"))
        print(textwrap.fill(line, width, subsequent_indent=" " * hang,
                            break_on_hyphens=False, break_long_words=False) if line else "")
    print()


def agreed(accept):
    if accept:
        note("--accept: going ahead without asking")
        return True
    if not sys.stdin.isatty():
        note("no one to ask, and no --accept: nothing was done")
        sys.exit("There is no one to ask, so nothing was done: pass --accept to go ahead.")
    answer = input("Go ahead? [y/N] ").strip()
    note(f"asked to go ahead, the answer was {answer!r}")
    return answer.lower() in ("y", "yes")


def plan(args):
    """What saying yes does, step by step."""
    lines = ["Saying yes will:"]
    if args.no_build:
        lines.append(f"  - pack nothing, and install the {PK3} published/releases/ has now")
    else:
        lines.append(f"  - pack hh/ into published/releases/{PK3} (with LICENSE), replacing the "
                     "one there")
    lines.append(f"  - copy it to {os.path.join(args.dir, 'wads', PK3)}, replacing any {PK3} there")
    lines.append("")
    lines.append("To change that: --no-build installs what is published already, and --dir says "
                 "which tdl folder it goes to.")
    return lines


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--accept", action="store_true", help="go ahead without asking")
    parser.add_argument("--no-build", action="store_true",
                        help="install what published/releases/ has now, packing nothing")
    parser.add_argument("--dir", default=default_dir(),
                        help="tdl's folder, whose wads/ gets the pk3 (default: %(default)s)")
    parser.add_argument("--computer-speak", action="store_true",
                        help="say what it does plainly and formally, rather than as a descent "
                             "through hell" + (" (and have the installer do the same)" if INSTALLER else ""))
    args = parser.parse_args()
    speak_in("computer-speak.toml" if args.computer_speak else "toiling-through-hell.toml")
    note(f"=== {os.path.basename(__file__)} {' '.join(sys.argv[1:])} ===")
    if not os.path.isdir(args.dir):
        sys.exit(f"tdl isn't installed in {args.dir}: install it with tdl-install, or give --dir")

    warning(plan(args))
    if not agreed(args.accept):
        note("not going ahead: nothing was done")
        sys.exit("Nothing was done.")
    check_owner([folder for folder in (os.path.normpath(os.path.join(HERE, "published")),) if os.path.isdir(folder)])
    tell("begin", f"Publishing and installing {WHAT}", what=WHAT, place=os.path.join(HERE, "published"))
    if not args.no_build:
        command = [sys.executable, "publish.py"]
        print("+", " ".join(command), flush=True)
        subprocess.run(command, check=True, cwd=HERE)
    source = os.path.join(HERE, "published", "releases", PK3)
    if not os.path.isfile(source):
        sys.exit(f"There is no {PK3} in published/releases/: pack it (leave out --no-build).")
    wads = os.path.join(args.dir, "wads")
    os.makedirs(wads, exist_ok=True)
    target = os.path.join(wads, PK3)
    shutil.copy2(source, target + ".part")
    os.replace(target + ".part", target)
    note(f"copied {source} to {target}")
    tell("copy", f"Installed {target}", what=os.path.basename(target), place=target)


if __name__ == "__main__":
    try:
        main()
        note("done")
    except subprocess.CalledProcessError as error:
        note(f"failed: {error}")
        tell("problem", f"publish-install failed: {error}", problem=error)
        tell("journal", f"What it did is in {JOURNAL}", place=JOURNAL)
        sys.exit(1)
    tell("done", "Done.", what=WHAT)
    tell("journal", f"What it did is in {JOURNAL}", place=JOURNAL)
