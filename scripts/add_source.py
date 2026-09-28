#!/usr/bin/env python3
"""Register a new Swift file in Maccy.xcodeproj (objectVersion 54 uses explicit references).

Usage: scripts/add_source.py <new file path> <sibling file name>

The new file joins the same group and the same Sources build phase as the sibling,
so pick a sibling that already lives in the target folder and target.
Example: scripts/add_source.py Maccy/SecretDetector.swift Throttler.swift
"""
import os
import re
import secrets
import subprocess
import sys

PROJECT = os.path.join(os.path.dirname(__file__), "..", "Maccy.xcodeproj", "project.pbxproj")


def new_id(text):
  while True:
    candidate = secrets.token_hex(12).upper()
    if candidate not in text:
      return candidate


def main():
  if len(sys.argv) != 3:
    sys.exit(__doc__)
  new_path, sibling = sys.argv[1], sys.argv[2]
  name = os.path.basename(new_path)
  text = open(PROJECT).read()

  if f"/* {name} */ = {{isa = PBXFileReference" in text:
    sys.exit(f"{name} is already in the project")

  sibling_ref = re.search(rf"\t\t([0-9A-F]{{24}}) /\* {re.escape(sibling)} \*/ = {{isa = PBXFileReference", text)
  sibling_build = re.search(rf"\t\t([0-9A-F]{{24}}) /\* {re.escape(sibling)} in Sources \*/ = {{isa = PBXBuildFile", text)
  if not sibling_ref or not sibling_build:
    sys.exit(f"sibling {sibling} not found as a compiled source")

  ref_id = new_id(text)
  build_id = new_id(text + ref_id)

  build_line = (f"\t\t{build_id} /* {name} in Sources */ = {{isa = PBXBuildFile; "
                f"fileRef = {ref_id} /* {name} */; }};\n")
  # Names with characters outside [A-Za-z0-9._/] (for example "+") must be quoted in the project file.
  path = name if re.fullmatch(r"[A-Za-z0-9._/]+", name) else f'"{name}"'
  ref_line = (f"\t\t{ref_id} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; "
              f"path = {path}; sourceTree = \"<group>\"; }};\n")

  text = text.replace("/* End PBXBuildFile section */", build_line + "/* End PBXBuildFile section */", 1)
  text = text.replace("/* End PBXFileReference section */", ref_line + "/* End PBXFileReference section */", 1)

  group_child = f"\t\t\t\t{sibling_ref.group(1)} /* {sibling} */,\n"
  phase_child = f"\t\t\t\t{sibling_build.group(1)} /* {sibling} in Sources */,\n"
  if text.count(group_child) != 1 or text.count(phase_child) != 1:
    sys.exit("could not locate the sibling's group or build phase uniquely")

  text = text.replace(group_child, group_child + f"\t\t\t\t{ref_id} /* {name} */,\n", 1)
  text = text.replace(phase_child, phase_child + f"\t\t\t\t{build_id} /* {name} in Sources */,\n", 1)

  original = open(PROJECT).read()
  open(PROJECT, "w").write(text)
  # Never leave an unreadable project behind.
  if subprocess.run(["plutil", "-lint", PROJECT], capture_output=True).returncode != 0:
    open(PROJECT, "w").write(original)
    sys.exit(f"adding {name} produced an invalid project file; nothing was changed")
  print(f"added {name} next to {sibling}")


if __name__ == "__main__":
  main()
