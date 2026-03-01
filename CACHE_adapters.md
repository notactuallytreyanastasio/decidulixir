# Goal 6: Adapter Pattern for AI Backends

## Rust Source Replaced
- `src/hooks.rs` (501 LOC) — Claude Code hook management
- `src/opencode.rs` (3,599 LOC) — OpenCode adapter
- `src/git_guard/` (~1,000 LOC) — git safety enforcement

## Elixir Modules to Create

```
lib/decidulixir/
  adapters.ex                 # Public API: list_adapters, detect_installed
  adapters/
    adapter.ex                # Behaviour definition
    claude.ex                 # Claude Code adapter
    opencode.ex               # OpenCode adapter
    windsurf.ex               # Windsurf adapter
    codex.ex                  # Codex adapter (new)
    git_guard/
      checker.ex              # Command safety checking
      config.ex               # git-guard.toml parsing
      rules.ex                # Declarative rule definitions
```

## Key Contract: Adapter Behaviour

```elixir
defmodule Decidulixir.Adapters.Adapter do
  @callback name() :: String.t()
  @callback slug() :: atom()
  @callback detect?(project_root :: Path.t()) :: boolean()
  @callback install(project_root :: Path.t(), config :: map()) :: :ok | {:error, String.t()}
  @callback uninstall(project_root :: Path.t()) :: :ok | {:error, String.t()}
  @callback status(project_root :: Path.t()) :: %{installed: boolean(), hooks: list(), commands: list()}
  @callback update(project_root :: Path.t()) :: :ok | {:error, String.t()}
end
```

## GitGuard Contract

```elixir
GitGuard.Checker.check(command, opts) :: {:allow, reason} | {:block, reason} | {:warn, reason}
```

Rules as declarative structs:
```elixir
%Rule{pattern: ~r/git push --force/, action: :block, reason: "Force push to protected branch"}
%Rule{pattern: ~r/git add -A/, action: :warn, reason: "Broad staging — use explicit file names"}
```

## Design Rule
- Adding a new backend = implement one behaviour module
- Each adapter is fully self-contained and independently testable

## Done When
- Each adapter can install/uninstall/status/update independently
- GitGuard blocks dangerous git commands, passes safe ones
- `Adapters.list_adapters()` returns all known adapters
- `Adapters.detect_installed(path)` auto-detects
