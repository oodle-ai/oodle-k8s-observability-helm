#!/usr/bin/env python3
"""Assert the vector-agent renders with high-cardinality log metadata suppressed.

Vector's `kubernetes_logs` source attaches pod/namespace/node metadata to every
log line. Pod labels and annotations are unbounded maps (pod-template hashes,
controller revisions, injected sidecar config) repeated on each event, so this
chart suppresses them by setting the field to `""` (see values.yaml).

Those defaults live in a *subchart's* values tree, which is exactly the kind of
thing that regresses silently: a `vector` chart bump that restructures
`customConfig`, or a values refactor, drops the keys and nobody notices until a
log bill arrives. This check renders the chart and fails loudly instead.

Usage: helm template <args> | check-log-metadata-fields.py <label>
"""

import sys

import yaml

# field group -> field names that must render as "" (suppressed).
SUPPRESSED = {
    "pod_annotation_fields": ("pod_labels", "pod_annotations", "pod_ip", "pod_ips"),
    "namespace_annotation_fields": ("namespace_labels",),
    "node_annotation_fields": ("node_labels",),
}


def agent_configs(docs):
    """Yield (name, parsed vector config) for every rendered Vector ConfigMap."""
    for doc in docs:
        if not isinstance(doc, dict) or doc.get("kind") != "ConfigMap":
            continue
        raw = (doc.get("data") or {}).get("vector.yaml")
        if not raw:
            continue
        config = yaml.safe_load(raw)
        if isinstance(config, dict) and "kubernetes_logs" in (config.get("sources") or {}):
            yield (doc.get("metadata") or {}).get("name", "?"), config


def find_leaks(docs):
    failures, checked = [], 0
    for name, config in agent_configs(docs):
        checked += 1
        source = config["sources"]["kubernetes_logs"]
        for group, fields in SUPPRESSED.items():
            rendered = source.get(group) or {}
            for field in fields:
                # Absent is a failure too: Vector falls back to its own default
                # path, which is precisely the metadata we mean to drop.
                value = rendered.get(field, "<missing>")
                if value != "":
                    failures.append(f"{name}: {group}.{field} = {value!r}, want ''")
    if not checked:
        failures.append("no rendered kubernetes_logs source found -- check is not covering anything")
    return failures


def main():
    label = sys.argv[1] if len(sys.argv) > 1 else "render"
    docs = list(yaml.safe_load_all(sys.stdin.read()))
    failures = find_leaks(docs)
    if failures:
        print(f"FAIL [{label}] log metadata not suppressed:", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        return 1
    print(f"ok [{label}] high-cardinality log metadata suppressed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
