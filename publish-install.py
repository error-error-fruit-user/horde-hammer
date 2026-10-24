#!/usr/bin/env python3
"""Publish Horde Hammer, then install the pk3 just published into tdl's wads.

usage: python3 publish-install.py [--accept] [--no-build] [--dir DIR] [--computer-speak]

First it says, under a red warning, exactly what it will do, and asks once: "Are you sure? [y/n]".
The answer can carry any of its flags after the y (`y --no-build`), which win over the same flags
on the command line; --accept goes ahead without asking. Then it packs hh/ into
published/releases/horde-hammer.pk3 with publish.py (or with --no-build packs nothing), and copies the pk3
into DIR/wads, the wad pool tdl offers: DIR is tdl's folder, by default where tdl-install puts it
for you (~/.local/opt/tdl, or %LOCALAPPDATA%\\Programs\\tdl on Windows). The pk3 is always packed
straight from hh/, so there is nothing else to build from source.

It speaks in a voice from ../installation-groans (Toiling Through Hell, or --computer-speak), and
everything it and what it runs did is in published/artifacts/publish-install.log.

Dependency-free Python 3.8+.
"""

import argparse
import os
import platform
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
JOURNAL = os.path.join(HERE, "published", "artifacts", "publish-install.log")
WINDOWS = platform.system() == "Windows"
PK3 = "horde-hammer.pk3"
GROANS_GITHUB = "https://raw.githubusercontent.com/error-error-fruit-user/installation-groans/main/"


def load_groans():
    """installation-groans' groans.py, which these scripts speak through: the project's
    installation-groans submodule, else the workspace's checkout beside the project, else a copy
    fetched from its GitHub into published/artifacts/groans/."""
    project = HERE
    places = [os.path.join(project, "installation-groans"),
              os.path.join(os.path.dirname(project), "installation-groans"),
              os.path.join(project, "published", "artifacts", "groans")]
    folder = next((place for place in places if os.path.isfile(os.path.join(place, "groans.py"))), None)
    if folder is None:
        folder = places[-1]
        try:
            import urllib.request
            os.makedirs(folder, exist_ok=True)
            for name in ("groans.py", "toiling-through-hell.toml", "computer-speak.toml"):
                with urllib.request.urlopen(GROANS_GITHUB + name, timeout=10) as answer:
                    with open(os.path.join(folder, name), "wb") as out:
                        out.write(answer.read())
        except Exception as error:
            sys.exit(f"installation-groans isn't beside {os.path.basename(project)}, and couldn't be "
                     f"fetched ({error}): clone it beside it.")
    if folder not in sys.path:
        sys.path.insert(0, folder)
    import groans
    return groans


groans = load_groans()


def rust_on_path():
    """Puts rustup's folder ($CARGO_HOME/bin, else ~/.cargo/bin) on the PATH when cargo isn't on
    it, as a shell that never ran rustup's profile line leaves it; everything this runs inherits it."""
    if shutil.which("cargo"):
        return
    home = os.environ.get("CARGO_HOME") or os.path.join(os.path.expanduser("~"), ".cargo")
    folder = os.path.join(home, "bin")
    if any(os.path.isfile(os.path.join(folder, name)) for name in ("cargo", "cargo.exe")):
        os.environ["PATH"] = folder + os.pathsep + os.environ.get("PATH", "")


def as_root():
    return not WINDOWS and os.geteuid() == 0


def check_owner(folders):
    """Stops, saying how to take them back, when anything in `folders` isn't this user's (a run
    with sudo leaves root's files behind)."""
    if WINDOWS or as_root():
        return
    folders = [folder for folder in folders if os.path.isdir(folder)]
    for folder in folders:
        for root, dirs, files in os.walk(folder):
            for path in [root] + [os.path.join(root, name) for name in dirs + files]:
                try:
                    stranger = os.lstat(path).st_uid != os.getuid()
                except OSError:
                    continue
                if stranger:
                    import getpass
                    fix = "sudo chown -R " + getpass.getuser() + " " + " ".join(folders)
                    groans.say("problem", f"{path} isn't yours (a run with sudo left it)",
                               problem=f"{path} isn't yours")
                    sys.exit(f"Something in published/ belongs to another user, root most likely: "
                             f"nothing can replace it. Take it back with:\n  {fix}")


def ask(flags, args, plan):
    """The warning, then the one question; returns the arguments, with any flags given with the
    y parsed after the command line's so they win. Stops if the answer is no."""
    groans.warning(plan(args))
    names = [name for action in flags._actions for name in action.option_strings
             if name not in ("-h", "--help", "--accept")]
    added = groans.confirm(args.accept, names)
    if added is None:
        groans.note("not going ahead: nothing was done")
        groans.declined()
    if added:
        groans.note(f"with the flags given at the question: {' '.join(added)}")
        return flags.parse_args(sys.argv[1:] + added)
    return args


def default_dir():
    if WINDOWS:
        return os.path.join(os.environ["LOCALAPPDATA"], "Programs", "tdl")
    return os.path.join(os.path.expanduser("~"), ".local", "opt", "tdl")


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
    lines.append("To change that, here or after the y: --no-build installs what is published already, "
                 "--dir says which tdl folder it goes to, --reinstall does it all again, and --computer-speak speaks plainly.")
    return lines


def parser():
    flags = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    flags.add_argument("--accept", action="store_true", help="go ahead without asking")
    flags.add_argument("--no-build", action="store_true",
                       help="install what published/releases/ has now, packing nothing")
    flags.add_argument("--dir", default=default_dir(),
                       help="tdl's folder, whose wads/ gets the pk3 (default: %(default)s)")
    flags.add_argument("--reinstall", action="store_true",
                       help="build and install everything again, where a run picks up where the last "
                            "one left off")
    flags.add_argument("--computer-speak", action="store_true",
                       help="say what it does plainly and formally, rather than as a descent through hell")
    return flags


def main():
    flags = parser()
    args = flags.parse_args()
    groans.start(JOURNAL, args.computer_speak)
    args = ask(flags, args, plan)
    if not os.path.isdir(args.dir):
        sys.exit(f"tdl isn't installed in {args.dir}: install it with tdl-install, or give --dir")
    check_owner([os.path.join(HERE, "published")])
    groans.say("begin", "Publishing and installing Horde Hammer", what="Horde Hammer", place=args.dir)
    if not args.no_build:
        groans.section("pack")
        packed = os.path.join(HERE, "published", "releases", PK3)
        if not args.reinstall and groans.up_to_date([packed], [HERE]):
            groans.say("skip", f"{PK3} is newer than its sources: nothing to pack (--reinstall packs "
                       "it again)", what=PK3, place=os.path.dirname(packed))
        else:
            groans.run([sys.executable, "publish.py"], cwd=HERE, voiced=True)
    groans.section("install")
    source = os.path.join(HERE, "published", "releases", PK3)
    if not os.path.isfile(source):
        sys.exit(f"There is no {PK3} in published/releases/: pack it (leave out --no-build).")
    wads = os.path.join(args.dir, "wads")
    os.makedirs(wads, exist_ok=True)
    target = os.path.join(wads, PK3)
    if not args.reinstall and groans.same_file(source, target):
        groans.say("skip", f"{target} is this {PK3} already", what=PK3, place=wads)
        return
    shutil.copy2(source, target + ".part")
    os.replace(target + ".part", target)
    groans.say("copy", f"Installed {target}", what=PK3, place=wads)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        groans.finish("Horde Hammer", ok=False,
                      error=f"{' '.join(map(str, error.cmd))} ended with code {error.returncode}")
        sys.exit(1)
    except SystemExit as stop:
        if isinstance(stop.code, str):
            groans.say("problem", stop.code, problem=stop.code)
            sys.exit(1)
        raise
    groans.finish("Horde Hammer")
