# Goal 5: Initialization System (Explicit Boundaries)

## Rust Source Replaced
- `src/init/mod.rs` (600+ LOC) — project initialization (the "nightmare")
- `src/init/templates.rs` (~5,000 LOC) — embedded template strings
- `src/changelog.rs` (329 LOC) — version changelog

## The Problem Being Solved
The Rust init.rs is a monolithic nightmare because it:
- Handles multiple assistants (Claude, OpenCode, Windsurf) in one function
- Mixes file I/O, template rendering, and logic
- Has complex idempotency requirements (safe to run twice)
- Manages ~5,000 lines of embedded template constants

## Elixir Solution: Explicit Boundaries

```
lib/decidulixir/
  init.ex                     # Thin orchestrator ONLY
  init/
    validator.ex              # Pre-flight checks (pure)
    database_setup.ex         # Migration runner
    file_writer.ex            # Single-responsibility file I/O
    version.ex                # Version tracking
    changelog.ex              # Release notes
    templates/
      claude.ex               # Claude Code templates (pure data)
      opencode.ex             # OpenCode templates (pure data)
      windsurf.ex             # Windsurf templates (pure data)
      shared.ex               # Shared: config, workflows (pure data)
  update.ex                   # Detect installed, regenerate
  check_update.ex             # Version comparison
```

## Key Contract: Init.Backend Behaviour

```elixir
defmodule Decidulixir.Init.Backend do
  @callback name() :: String.t()
  @callback detect?(project_root :: Path.t()) :: boolean()
  @callback files(project_root :: Path.t()) :: [{Path.t(), String.t()}]
  @callback post_init(project_root :: Path.t()) :: :ok | {:error, String.t()}
end
```

## Design Rules
- Template modules return `[{path, content}]` tuples — NO side effects
- FileWriter handles ALL disk I/O
- Init orchestrator is a thin pipeline: validate → setup DB → get files from backends → write files
- Update is a SEPARATE module from Init (explicit boundary)

## CRITICAL: Template Compatibility
Generated slash command templates (.claude/commands/*.md, etc.) MUST call `decidulixir`
with the SAME flags and arguments as the Rust `deciduous` binary. The CLI API is 1:1.
Templates can reference `decidulixir` instead of `deciduous` as the binary name but
all arguments, flags, and output formats remain identical.

## Done When
- `mix decidulixir init --claude` creates all files correctly
- `mix decidulixir update` regenerates only changed files
- Templates individually testable (render → assert content)
- Running init twice is safe (idempotent)
- Generated templates use correct binary name but same API
