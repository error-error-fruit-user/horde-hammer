#!/usr/bin/env python3
"""Publish Horde Hammer, then install the pk3 just published into tdl's wads.

usage: python3 publish-install.py [--dir DIR]

Runs publish.py (published/releases/horde-hammer.pk3), then copies the pk3 into DIR/wads, the wad
pool tdl offers: DIR is tdl's folder, by default where tdl-install puts it for you
(~/.local/opt/tdl, or %LOCALAPPDATA%\\Programs\\tdl on Windows).

Dependency-free Python 3.8+.
"""

import argparse
import os
import platform
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PK3 = "horde-hammer.pk3"


def default_dir():
    if platform.system() == "Windows":
        return os.path.join(os.environ["LOCALAPPDATA"], "Programs", "tdl")
    return os.path.join(os.path.expanduser("~"), ".local", "opt", "tdl")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--dir", default=default_dir(),
                        help="tdl's folder, whose wads/ gets the pk3 (default: %(default)s)")
    args = parser.parse_args()
    if not os.path.isdir(args.dir):
        sys.exit(f"tdl isn't installed in {args.dir}: install it with tdl-install, or give --dir")

    command = [sys.executable, "publish.py"]
    print("+", " ".join(command), flush=True)
    subprocess.run(command, check=True, cwd=HERE)

    wads = os.path.join(args.dir, "wads")
    os.makedirs(wads, exist_ok=True)
    target = os.path.join(wads, PK3)
    shutil.copy2(os.path.join(HERE, "published", "releases", PK3), target + ".part")
    os.replace(target + ".part", target)
    print("Installed", target)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        sys.exit(f"publish-install failed: {error}")
