# Upstream update policy

Hermes Agent changes quickly, so upstream updates are candidates until this
repository's package and module contracts pass. Automation never pushes an
upstream pin directly to `main`.

## Channels

- **Stable** is the last reviewed, green Hermes release. Ordinary
  `nix flake check` validates this channel only.
- **Nightly** follows upstream `main`. Its checks are exposed at
  `legacyPackages.<system>.nightlyChecks.all` and run only from the nightly
  candidate workflow.

The scheduled workflows each own one replaceable branch:

- `automation/hermes-agent-stable-candidate`
- `automation/hermes-agent-nightly-candidate`

Do not put manual commits on those branches; the next scheduled run may
replace them. Promotion is a normal reviewed PR merge. A failed candidate stays
outside `main`, leaving the known-good stable pin usable.

## Candidate report

Each updater compares the old and new upstream sources and adds a report to its
PR. The report covers Python bounds, direct dependencies, optional dependency
groups, CLI entry points, config schema version, and source paths used by the
Nix package/module. A build failure is included in the report and marks the
updater job red, but does not discard the candidate.

## Repository token

Set the Actions secret `HERMES_UPDATE_TOKEN` to a fine-grained PAT or GitHub App
token with repository contents and pull-request write access. GitHub suppresses
new workflow runs for PRs created with the default `GITHUB_TOKEN`; the dedicated
token allows the candidate PR to receive normal required checks. Scheduled
updates fail clearly when this secret is absent rather than opening an unchecked
PR.

Protect `main` with the ordinary `CI / check` status and the
`Nightly Candidate / check` status. The latter passes without installing Nix
when a PR does not change `nightly.nix`, and builds the isolated nightly suite
when it does.

## Manual validation

```bash
# Known-good stable channel
nix flake check --keep-going

# Mutable upstream channel (replace the system when needed)
nix build .#legacyPackages.x86_64-linux.nightlyChecks.all
```
