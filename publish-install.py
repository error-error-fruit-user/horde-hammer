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


def run(command, cwd=HERE):
    """Runs `command`, its output shown as it comes (prompts included) and written down, with how it
    ended. Raises CalledProcessError if it failed."""
    shown = " ".join(str(part) for part in command)
    print("+", shown, flush=True)
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
    args = parser.parse_args()
    note(f"=== {os.path.basename(__file__)} {' '.join(sys.argv[1:])} ===")
    if not os.path.isdir(args.dir):
        sys.exit(f"tdl isn't installed in {args.dir}: install it with tdl-install, or give --dir")

    warning(plan(args))
    if not agreed(args.accept):
        note("not going ahead: nothing was done")
        sys.exit("Nothing was done.")
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
    print("Installed", target)


if __name__ == "__main__":
    try:
        main()
        note("done")
    except subprocess.CalledProcessError as error:
        note(f"failed: {error}")
        sys.exit(f"publish-install failed: {error}\nWhat it did is in {JOURNAL}")
    print(f"What it did is in {JOURNAL}")
