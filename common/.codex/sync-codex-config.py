#!/usr/bin/env python3
"""Write the developer_instructions block into .codex/config.toml.

Called by .codex/Makefile's sync-codex-config target as:
    python3 sync-codex-config.py <config.toml path> <AGENTS.md path>

Text insertion only, never TOML re-serialization (same discipline as install.sh's
vscode_chat_keys_py, which this mirrors for BOM/CRLF/mode) — a project's own config.toml keys
and comments outside the generated block must survive byte-for-byte. The block is delimited by marker
comments so a later run can find and replace exactly its own output; install.sh's
strip_codex_config_block (same markers, kept in sync by hand) uses the same markers to exclude the
block from the seed's "is this file untouched" check.
"""
import os
import stat
import sys
import tempfile

OPEN = "# >>> agent-kit generated: do not edit — make -C .codex sync-agents"
CLOSE = "# <<< agent-kit generated"
KEY = "developer_instructions"
Q3 = "'" * 3  # the TOML literal multi-line string delimiter


def is_key_line(stripped, key):
    """True if `stripped` assigns top-level `key`, bare or quoted: `key = ...`, `key=...`,
    `"key" = ...`, `'key'=...`."""
    for quoted in (key, '"' + key + '"', "'" + key + "'"):
        if stripped == quoted:
            return True
        if stripped.startswith(quoted) and stripped[len(quoted):len(quoted) + 1] in (" ", "\t", "="):
            return True
    return False


def main():
    cfg_path, out_path = sys.argv[1], sys.argv[2]

    with open(out_path, "r", encoding="utf-8") as fh:
        body = fh.read()
    if Q3 in body:
        # Belt and suspenders: the Makefile recipe already checks every Tier-0 doc individually (and
        # can name the offender), so this should be unreachable. Kept in case a non-Tier-0 part of the
        # generated body (the header, a personal skill's description) ever grows one.
        sys.stderr.write(
            "ERROR: the generated AGENTS.md body contains " + Q3 + " — cannot build developer_instructions\n"
        )
        return 1

    # Read as BYTES first, exactly like vscode_chat_keys_py: a BOM must be detected before
    # decoding (utf-8-sig strips it; plain utf-8 would read it as content and corrupt the first line),
    # and the line ending must be read from the RAW text, before splitlines() erases it.
    if os.path.exists(cfg_path):
        with open(cfg_path, "rb") as fh:
            blob = fh.read()
        bom = blob.startswith(b"\xef\xbb\xbf")
        raw = blob.decode("utf-8-sig")
        nl = "\r\n" if "\r\n" in raw else "\n"
        old_lines = raw.splitlines()
    else:
        bom = False
        nl = "\n"
        old_lines = []

    # Block recognition is anchored to the TOP of the file: the OPEN marker counts only as the very
    # first line (right after the BOM, already stripped above). A look-alike OPEN/CLOSE pair anywhere
    # else — inside a project's own multi-line string, say — is file content, never touched.
    open_i = close_i = None
    if old_lines and old_lines[0] == OPEN:
        open_i = 0
        for i in range(1, len(old_lines)):
            if old_lines[i] == CLOSE:
                close_i = i
                break

    if open_i is not None and close_i is None:
        sys.stderr.write(
            "WARNING: " + cfg_path + " has a generated-block start marker with no matching end "
            "marker — left alone.\n"
            "  Remove the stray marker line by hand, or restore the file from git, then re-run "
            "`make -C .codex sync-agents`.\n"
        )
        return 0

    # Foreign-key scan: a root-scope `developer_instructions` OUTSIDE the recognized top block blocks
    # the write (a second key would be invalid TOML). "Root-scope" is a heuristic, not a parse — a
    # `[`-leading line inside a multi-line string or a nested array can misfire as a table header —
    # but the only failure direction is "do not write, warn", which is safe. Lines inside the
    # recognized top block are excluded from the scan.
    foreign_i = None
    seen_table = False
    for i in range(close_i + 1 if close_i is not None else 0, len(old_lines)):
        stripped = old_lines[i].strip()
        if stripped.startswith("["):
            seen_table = True
            continue
        if not seen_table and is_key_line(stripped, KEY):
            foreign_i = i
            break

    if foreign_i is not None:
        sys.stderr.write(
            "WARNING: " + cfg_path + " already sets " + KEY + " outside the generated block — "
            "left alone.\n"
            "  A second " + KEY + " key would be invalid TOML, so the kit will not add its own.\n"
            "  Remove that key, or delete the file, then re-run `make -C .codex sync-agents`.\n"
        )
        return 0

    # Always at the very top — never "before the first [table]". A no-longer-needed table scan for
    # PLACEMENT was the other place a `[`-leading line inside a string or a nested array
    # (`  [1, 2],`) could misfire; dropping it removes that failure mode entirely, since every
    # consumer's config.toml is rewritten the same way regardless of what follows.
    block_lines = [OPEN, KEY + " = " + Q3] + body.splitlines() + [Q3, CLOSE]
    rest = old_lines[close_i + 1:] if open_i is not None else old_lines
    new_lines = block_lines + rest
    new_content = nl.join(new_lines) + nl

    # Post-write verification, python >= 3.11 only (tomllib is stdlib there). The import is deferred
    # and conditional — never at module load — so this generator keeps working on an older python3;
    # verify.sh, run by a developer/CI on a modern python, is where the equivalent check is mandatory.
    try:
        import tomllib
    except ImportError:
        tomllib = None
    if tomllib is not None:
        try:
            parsed = tomllib.loads(new_content)
            verified = parsed.get(KEY) == body
        except Exception:
            verified = False
        if not verified:
            sys.stderr.write(
                "ERROR: the regenerated " + cfg_path + " would not parse back with " + KEY +
                " intact — left unchanged.\n"
            )
            return 1

    # Atomic replace: resolve the real path first (a dotfile manager may symlink config.toml), copy
    # its mode onto the temp file (mkstemp creates 0600; every sibling seed is 644), default to 0644
    # for a file that does not exist yet, and re-add the BOM on write only if the original had one.
    real = os.path.realpath(cfg_path)
    try:
        perm = stat.S_IMODE(os.stat(real).st_mode)
    except OSError:
        perm = 0o644
    real_dir = os.path.dirname(real) or "."
    os.makedirs(real_dir, exist_ok=True)
    tmp = None
    try:
        fd, tmp = tempfile.mkstemp(dir=real_dir, prefix=".config-", suffix=".toml")
        with os.fdopen(fd, "w", encoding="utf-8-sig" if bom else "utf-8", newline="") as fh:
            fh.write(new_content)
        os.chmod(tmp, perm)
        os.replace(tmp, real)
    except Exception:
        if tmp:
            try:
                os.unlink(tmp)
            except OSError:
                pass
        raise

    sys.stdout.write(cfg_path + " developer_instructions synced.\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
