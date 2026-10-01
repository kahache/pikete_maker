# Contributing

Honest expectations first: **this is a showcase repository.** It is a
curated snapshot of a private main repo, refreshed at milestones (releases,
signed quality gates) — not a live mirror. Day-to-day development, the full
commit history, the issue tracker and the decision process live in the
private repo (see "About this repository" in the [README](README.md)).

What that means for you:

- **Issues are welcome.** Bug reports, questions about the approach, and
  reproduction cases are genuinely useful — file them here.
- **PRs are read, not merged directly.** Because history flows one way
  (private → public snapshot), a PR can't land here as-is. If a change is
  adopted, it is ported into the private repo and appears in the next
  snapshot, with credit to you in the commit/notes.
- **Don't expect daily commits.** The public repo lags the private one
  between milestones by design. If you're reviewing the project and need
  the current state, request access to the private repo via the author's
  GitHub profile.
- **License.** The repo is source-available under the PolyForm
  Noncommercial License 1.0.0 (see [LICENSE](LICENSE)); anything you
  submit is understood to be offered under terms compatible with it.

Running the test suites before reporting an engine bug helps a lot:

```bash
cd cv_core && pytest -m "not slow"   # Python canonical engine
cd app && flutter test               # Dart engine + parity fixtures
```

If both suites are green and you still see wrong colours on a photo, that's
exactly the kind of issue we want — attach the photo (only if you have the
rights to share it) or describe the scene (garment colours, background,
lighting).
