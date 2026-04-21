# twig-conductor-workflows

Conductor workflow registry for [twig](https://github.com/PolyphonyRequiem/twig) SDLC automation.

## Workflows

| Workflow | Registry Name | Purpose |
|----------|---------------|---------|
| **Full SDLC** | `twig-sdlc-full@twig` | Planning → implementation (composite) |
| **Planning only** | `twig-sdlc-planning@twig` | Architect + review + seed + per-issue task planning |
| **Implementation only** | `twig-sdlc-implement@twig` | Coding, review, PR lifecycle, close-out |
| **Closeout Filing** | `closeout-filing@twig` | File closeout observations as ADO work items |
| **Legacy** | `twig-sdlc-legacy@twig` | Original monolithic pipeline (deprecated) |

## Installation

```bash
conductor registry add twig --source github://PolyphonyRequiem/twig-conductor-workflows
```

## Updating

```bash
conductor registry update twig
```

## Development Workflow

1. **Edit** files directly in `~/.conductor/registries/twig/` for fast iteration
2. **Test** by running `conductor run <workflow>@twig --web`
3. **Commit** stable changes back to this repo
4. **Pull** latest: `conductor registry update twig`

## Structure

```
index.yaml                  # Registry manifest
recursive/                  # Recursive decomposition workflows
  twig-sdlc-planning.yaml   # Epic/Issue planning orchestrator
  twig-sdlc-implement.yaml  # Implementation orchestrator
  twig-sdlc-full.yaml       # Composite: planning → implementation
  plan-issue.yaml            # Sub-workflow: Issue → Tasks
  task-implementation.yaml   # Sub-workflow: single task
  issue-review.yaml          # Sub-workflow: post-issue review
  integration-fix.yaml       # Sub-workflow: cross-PR fixes
  recursive-dispatcher.yaml  # Epic planning dispatcher
  recursive-implementer.yaml # Implementation dispatcher
  prompts/                   # Recursive-specific prompts
  scripts/                   # Helper scripts
twig-sdlc/                  # Legacy monolithic workflow
  twig-sdlc.yaml            # Single-file SDLC pipeline
  prompts/                   # Shared prompt library (43 files)
  scripts/                   # Utility scripts
closeout-filing/            # Closeout observation filing
  closeout-filing.yaml
  prompts/
```
