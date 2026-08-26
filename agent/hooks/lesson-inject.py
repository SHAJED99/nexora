#!/usr/bin/env python3
"""Inject the relevant lessons into the agent's context. Rule 8, mechanized.

Claude Code UserPromptSubmit hook. Wire in .claude/settings.json:

  "hooks": {
    "UserPromptSubmit": [
      {"hooks": [{"type": "command", "command": "python3 agent/hooks/lesson-inject.py"}]}
    ]
  }

Reads the hook payload on stdin, finds a task id (E03-T07) in the prompt, loads
that task's `layer:` + `files:`, maps them to areas via
agent/memory/lessons/index.yaml, and prints the matching lessons on stdout —
Claude Code adds stdout to the model's context.

Why this exists: v1 wrote lessons to files and relied on agents remembering to
read them. The ones that mattered got hand-pasted into role files, where they
rotted out of sync. Learning that needs a human to copy it isn't learning
(L-process-001). Injection is once-per-session per task so it informs without
nagging.

Fails open, always. A memory aid must never block work.
"""
import fnmatch
import hashlib
import json
import os
import re
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LESSONS = os.path.join(ROOT, "agent", "memory", "lessons")
TASK_RE = re.compile(r"\bE(\d{2})-([TB]\d{2})\b")


def load_index():
    path = os.path.join(LESSONS, "index.yaml")
    try:
        import yaml
        with open(path, encoding="utf-8") as f:
            return yaml.safe_load(f) or {}
    except Exception:
        return {"always": ["process"], "by_layer": {}, "by_path": {}, "max_lessons_per_area": 8}


def find_task_file(task_id):
    epic = task_id.split("-")[0]
    epics = os.path.join(ROOT, "epics")
    if not os.path.isdir(epics):
        return None
    for d in os.listdir(epics):
        if not d.startswith(epic):
            continue
        p = os.path.join(epics, d, "tasks", f"{task_id}.md")
        if os.path.exists(p):
            return p
    return None


def frontmatter(path):
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
        m = re.match(r"\s*---\s*\n(.*?)\n---\s*\n", text, re.S)
        if not m:
            return {}
        import yaml
        data = yaml.safe_load(m.group(1))
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def task_paths(fm):
    files = fm.get("files") or {}
    if isinstance(files, dict):
        out = []
        for k in ("create", "update", "delete"):
            out += list(files.get(k) or [])
        return out
    return list(files) if isinstance(files, list) else []


def areas_for(fm, idx):
    """Most-specific areas first; `always` last.

    Ordering is not cosmetic — it decides what gets read. The lessons for the
    layer you're actually working in have to lead, or the always-on ones push
    them past the point where attention runs out.
    """
    areas = []
    layer = str(fm.get("layer", "") or "")
    areas += list((idx.get("by_layer") or {}).get(layer) or [])
    paths = task_paths(fm)
    for glob, mapped in (idx.get("by_path") or {}).items():
        if any(fnmatch.fnmatch(p, glob) for p in paths):
            areas += list(mapped or [])
    areas += list(idx.get("always") or [])
    seen, out = set(), []
    for a in areas:
        if a not in seen:
            seen.add(a)
            out.append(a)
    return out


def read_lessons(area, cap):
    path = os.path.join(LESSONS, f"{area}.md")
    if not os.path.exists(path):
        return []
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return []
    blocks = re.split(r"\n(?=## L-)", text)
    entries = [b.strip() for b in blocks if b.strip().startswith("## L-")]

    # Highest recurrence first — the ones that keep biting are the ones to read.
    def recurrence(b):
        m = re.search(r"recurrence:\s*(\d+)", b)
        return int(m.group(1)) if m else 1
    entries.sort(key=recurrence, reverse=True)
    return entries[:cap]


def already_sent(session_id, task_id):
    """Once per session per task — inform, don't nag."""
    key = hashlib.sha1(f"{session_id}:{task_id}".encode()).hexdigest()[:16]
    marker = os.path.join(tempfile.gettempdir(), f"harness-lessons-{key}")
    if os.path.exists(marker):
        return True
    try:
        open(marker, "w").close()
    except OSError:
        pass
    return False


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return
    prompt = str(payload.get("prompt") or "")
    m = TASK_RE.search(prompt)
    if not m:
        return
    task_id = m.group(0)

    if already_sent(str(payload.get("session_id") or "-"), task_id):
        return

    path = find_task_file(task_id)
    if not path:
        return
    fm = frontmatter(path)
    idx = load_index()
    cap = int(idx.get("max_lessons_per_area") or 8)

    chunks = []
    for area in areas_for(fm, idx):
        entries = read_lessons(area, cap)
        if entries:
            chunks.append(f"### {area}\n\n" + "\n\n".join(entries))
    if not chunks:
        return

    print(
        f"## Lessons for {task_id} (layer: {fm.get('layer', '?')}) — injected by "
        f"agent/hooks/lesson-inject.py\n\n"
        f"These are real findings from real reviews of this codebase, not general "
        f"advice. Rule 8: read them before you start. Each one shipped at least "
        f"once; the traps are traps because somebody already fell in.\n\n"
        + "\n\n".join(chunks)
        + f"\n\nHit one of these anyway? `skills/retro` increments its recurrence — "
        f"which is what decides whether it becomes a rule or a hook next.\n"
    )


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # A memory aid must never block work.
        pass
