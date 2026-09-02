#!/usr/bin/env python3
"""Assert that no rendered container declares the same env var name twice.

Kubernetes treats `container.env` as a map keyed by `name`. Duplicate entries are
rejected by server-side apply with:

    failed to create typed patch object (...): .spec.template.spec.containers[name="x"].env:
    duplicate entries for key [name="..."]

Helm 3 (client-side apply) silently tolerates this and lets the last entry win, so
the bug is invisible until a user runs Helm 4 or `--server-side-apply`. This check
renders the chart and fails loudly instead.

Usage: helm template <args> | check-duplicate-env.py <label>
"""

import sys

import yaml

POD_SPEC_PARENTS = ("containers", "initContainers", "ephemeralContainers")


def pod_specs(doc):
    """Yield (path, pod_spec) for every pod template in a manifest."""
    kind = doc.get("kind", "?")
    name = (doc.get("metadata") or {}).get("name", "?")
    spec = doc.get("spec") or {}

    if kind == "Pod":
        yield f"{kind}/{name}", spec
    template = (spec.get("template") or {}).get("spec")
    if template:
        yield f"{kind}/{name}", template
    # CronJob nests one level deeper.
    job = ((spec.get("jobTemplate") or {}).get("spec") or {}).get("template") or {}
    if job.get("spec"):
        yield f"{kind}/{name}", job["spec"]


def find_duplicates(docs):
    failures = []
    for doc in docs:
        if not isinstance(doc, dict) or "kind" not in doc:
            continue
        for path, spec in pod_specs(doc):
            for parent in POD_SPEC_PARENTS:
                for container in spec.get(parent) or []:
                    seen, dupes = set(), []
                    for entry in container.get("env") or []:
                        key = entry.get("name")
                        if key in seen:
                            dupes.append(key)
                        seen.add(key)
                    if dupes:
                        failures.append(
                            f"{path} {parent}[{container.get('name')}] "
                            f"duplicate env: {', '.join(sorted(set(dupes)))}"
                        )
    return failures


def main():
    label = sys.argv[1] if len(sys.argv) > 1 else "render"
    docs = list(yaml.safe_load_all(sys.stdin.read()))
    failures = find_duplicates(docs)
    if failures:
        print(f"FAIL [{label}] duplicate container env names:", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        return 1
    print(f"ok [{label}] no duplicate container env names")
    return 0


if __name__ == "__main__":
    sys.exit(main())
