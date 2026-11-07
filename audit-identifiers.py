#!/usr/bin/env python3
"""Advisory: find identifiers in a stack's backend docs that resolve nowhere in that stack's source.

    ./audit-identifiers.py <stack> <source-dir> [<source-dir> ...]
    ./audit-identifiers.py <stack> ~/projects/<framework>

WHY THIS EXISTS. The dominant defect in this kit is a class, method or annotation name from one
stack surviving into another stack's docs — a base class, a test helper or a cache method that
exists only in the first stack's framework. Prose review catches these one at a time and misses most;
this catches them mechanically. It is the identifier analogue of verify.sh's messaging_doc_coverage.

WHY IT IS ADVISORY, NOT A GATE. An illustrative placeholder in a naming-convention table
(`MediaTypeEnum`, `ExternalApiClientService`) is legitimate and looks identical to a wrong name.
No heuristic separates them, so this prints a short list for a human to judge rather than failing a
build. It is also machine-dependent: it needs the stack's source checked out, which verify.sh cannot
assume. Run it when you touch a stack's docs, or after the framework moves.

SCOPE, and why each narrowing earns its place — the unfiltered form returns ~180 hits, which nobody
reads. Only ```java fences (an identifier there is meant to compile; one in prose may be
illustrative). Only conventions/backend/** plus context/architecture.md (frontend docs are TS, and
build-commands.md is shell — both resolve nowhere in .java source by construction). Comments
stripped (prose inside a fence is still prose). Obvious placeholders dropped. That takes it to ~13,
of which roughly a third are real.
"""
import os, re, subprocess, sys

PLACEHOLDER = re.compile(
    r"Foo|Bar|Xxx|XXX|Custom|Example|MyVo|MyClass|MyResponse|MyEvent|Target(Module|Package)|Domain")


def source_symbols(paths):
    """Every identifier appearing anywhere in the stack's Java source."""
    chunks = []
    for p in paths:
        if not os.path.isdir(p):
            print(f"  ! not a directory, skipped: {p}", file=sys.stderr)
            continue
        chunks.append(subprocess.run(
            ["grep", "-rhoE", "[A-Za-z_][A-Za-z0-9_]*", "--include=*.java", p],
            capture_output=True, text=True).stdout)
    return set("\n".join(chunks).split())


def unresolved(stack_dir, symbols):
    hits = {}
    for root, _, files in os.walk(stack_dir):
        if "frontend" in root:
            continue
        for f in files:
            if not f.endswith(".md") or f == "build-commands.md":
                continue
            fp = os.path.join(root, f)
            fence = None
            for ln, line in enumerate(open(fp), 1):
                if line.startswith("```"):
                    fence = line.strip("`\n ").lower() if fence is None else None
                    continue
                if fence != "java":
                    continue
                line = re.sub(r"//.*$", "", line)
                for tok in re.findall(r"\b([A-Z][A-Za-z0-9]{3,})\b|\b([a-z][A-Za-z0-9]{4,})\s*\(", line):
                    name = next(x for x in tok if x)
                    if PLACEHOLDER.search(name) or name in symbols:
                        continue
                    hits.setdefault(name, []).append(f"{fp}:{ln}")
    return hits


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    stack, paths = sys.argv[1], sys.argv[2:]
    stack_dir = os.path.join("stacks", stack)
    if not os.path.isdir(stack_dir):
        print(f"no such stack: {stack}", file=sys.stderr)
        return 2
    symbols = source_symbols(paths)
    if not symbols:
        print("no Java source found in the given paths — nothing to check against", file=sys.stderr)
        return 2
    hits = unresolved(stack_dir, symbols)
    if not hits:
        print(f"{stack}: every identifier in a java fence resolves in source.")
        return 0
    print(f"{stack}: {len(hits)} identifier(s) in a java fence resolve nowhere in source.")
    print("Judge each: a wrong name is a defect; an illustrative placeholder is fine.\n")
    for name in sorted(hits):
        print(f"  {name:38} {hits[name][0]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
