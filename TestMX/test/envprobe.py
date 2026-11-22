#!/usr/bin/env python3
"""Write EnvDump/probe.txt: the globals and library members that EnvDump
looks up by name, because older firmware (DS-16 on 5.06) keeps them in ROM
tables that pairs() doesn't list. The names are the ones the emulator 6.06
and a DS-24 on 5.08 enumerate, plus a few library names.

usage: python3 -I TestMX/test/envprobe.py   (from Apps)

Format, one per line: "G name" (all of them first), then "M lib member"
grouped by library.
"""
import collections
import os

HERE = os.path.dirname(os.path.abspath(__file__))
DUMPS = ["envdump-emu606.txt", "envdump-ds24-508.txt"]
INTERNAL = {"globals", "globalVarList"}   # the emulator's own tables
EXTRA = {"math", "system", "lcd", "form", "gps", "json", "os", "io", "string",
         "table", "utf8", "coroutine", "debug", "bit32", "timer", "package"}

G, M = set(EXTRA), collections.defaultdict(set)
for fn in DUMPS:
    for line in open(os.path.join(HERE, fn), encoding="utf-8", errors="replace"):
        p = line.split()
        if len(p) >= 2 and p[0] == "G":
            G.add(p[1])
        elif len(p) >= 2 and p[0] == "M" and "." in p[1]:
            lib, mem = p[1].split(".", 1)
            M[lib].add(mem)
G -= INTERNAL
for x in INTERNAL:
    M.pop(x, None)
M.pop("package", None)
out = ["G " + g for g in sorted(G)]
for lib in sorted(M):
    out += ["M %s %s" % (lib, m) for m in sorted(M[lib])]
with open(os.path.join(HERE, "..", "..", "EnvDump", "probe.txt"), "w") as fh:
    fh.write("\n".join(out) + "\n")
print(len(G), "globals,", sum(len(v) for v in M.values()), "members")
