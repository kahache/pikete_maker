"""Supply-chain lock (security audit Q2, 2026-10-01): CI + build-tool hygiene.

Breaks the build if the Gradle wrapper loses its https URL or SHA-256 pin
(last test), or if any workflow in ``.github/workflows/``:

- uses an action by tag or branch instead of a full 40-hex commit SHA (a tag
  can be moved by whoever controls the action repo; a SHA cannot);
- lacks a top-level ``permissions:`` block, or grants any ``write`` scope;
- switches to ``pull_request_target`` / ``workflow_run`` (they run fork code
  with the base repo's token and secrets);
- references ``secrets.`` (none are needed: the CI only lints and tests);
- checks out without ``persist-credentials: false``.

Plain-text checks (no YAML dependency in the pinned CI install).
"""

import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = sorted((REPO_ROOT / ".github" / "workflows").glob("*.y*ml"))

USES_RE = re.compile(r"^\s*-?\s*uses:\s*([^\s#]+)", re.MULTILINE)
PINNED_RE = re.compile(r"^[\w.-]+/[\w./-]+@[0-9a-f]{40}$")
DANGEROUS_TRIGGERS = ("pull_request_target", "workflow_run")


@pytest.fixture(params=WORKFLOWS, ids=lambda p: p.name)
def workflow(request) -> tuple[Path, str]:
    return request.param, request.param.read_text(encoding="utf-8")


def test_there_is_at_least_one_workflow():
    assert WORKFLOWS, "no workflow found — did .github/workflows move?"


def test_every_action_is_pinned_to_a_commit_sha(workflow):
    path, text = workflow
    uses = USES_RE.findall(text)
    assert uses, f"{path.name}: no `uses:` found — regex drifted?"
    for ref in uses:
        if ref.startswith("./"):  # local action in this repo
            continue
        assert PINNED_RE.match(ref), f"{path.name}: `{ref}` is not pinned to a SHA"


def test_top_level_permissions_are_read_only(workflow):
    path, text = workflow
    assert re.search(r"^permissions:", text, re.MULTILINE), (
        f"{path.name}: no top-level `permissions:` block (default token may be write)"
    )
    assert not re.search(r"^\s+[\w-]+:\s*write\b", text, re.MULTILINE), (
        f"{path.name}: grants a write scope"
    )
    assert not re.search(r"permissions:\s*write-all", text), path.name


def test_no_dangerous_triggers_and_no_secrets(workflow):
    path, text = workflow
    for trigger in DANGEROUS_TRIGGERS:
        assert trigger not in text, f"{path.name}: uses `{trigger}`"
    assert "secrets." not in text, f"{path.name}: references a secret"


def test_checkout_does_not_persist_the_token(workflow):
    path, text = workflow
    n_checkout = len(re.findall(r"uses:\s*actions/checkout@", text))
    n_no_persist = len(re.findall(r"persist-credentials:\s*false", text))
    assert n_no_persist >= n_checkout, (
        f"{path.name}: every checkout needs `persist-credentials: false`"
    )


GRADLE_WRAPPER = (
    REPO_ROOT / "app" / "android" / "gradle" / "wrapper" / "gradle-wrapper.properties"
)


def test_gradle_wrapper_distribution_is_https_and_hash_pinned():
    """The Gradle distribution runs with the signing key in reach: pin it."""
    text = GRADLE_WRAPPER.read_text(encoding="utf-8")
    url = re.search(r"^distributionUrl=(\S+)$", text, re.MULTILINE)
    assert url and url.group(1).startswith(r"https\://services.gradle.org/"), (
        "distributionUrl must be the official https Gradle host"
    )
    assert re.search(r"^distributionSha256Sum=[0-9a-f]{64}\s*$", text, re.MULTILINE), (
        "distributionSha256Sum missing: take it from <distributionUrl>.sha256"
    )
