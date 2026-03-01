# Goal 3: CLI as Isolated Module

## CRITICAL: 1:1 API Compatibility
The CLI MUST be a drop-in replacement for the Rust `deciduous` binary.
Every existing command, flag, and output format must work identically so that:
- Existing `.claude/commands/*.md` templates work without changes
- Existing `.opencode/commands/*.md` templates work without changes
- AI tools (Claude, OpenCode, Windsurf) can call `decidulixir` with the same args
- The binary should be named `decidulixir` but accept all `deciduous` commands

### Commands That MUST Be Identical
```
decidulixir add <type> "title" [-c N] [-p "prompt"] [--prompt-stdin] [-f "files"] [-b branch] [--commit hash|HEAD] [--date "YYYY-MM-DD"]
decidulixir link <from> <to> [-r "reason"] [-t edge_type]
decidulixir unlink <from> <to>
decidulixir delete <id> [--dry-run]
decidulixir status <id> <status>
decidulixir prompt <id> "text" (also accepts stdin pipe)
decidulixir nodes [--branch B] [--status S] [--type T]
decidulixir edges
decidulixir show <id>
decidulixir graph
decidulixir backup [--output path]
decidulixir commands [--limit N]
decidulixir serve [--port N]
decidulixir pulse [--branch B] [--recent N] [--summary]
decidulixir writeup [-t title] [-r roots] [-n nodes] [-o output] [--png file] [--auto]
decidulixir audit [--associate-commits] [--min-score N]
decidulixir doc attach|list|show|describe|detach|open|gc [args...]
decidulixir themes create|list|delete [args...]
decidulixir tag add|remove|list|suggest|confirm [args...]
decidulixir init [--claude] [--opencode] [--windsurf] [--both]
decidulixir update
decidulixir check-update
decidulixir archaeology pivot|timeline|supersede [args...]
decidulixir narratives init|show|pivots
decidulixir hooks install|status|uninstall
decidulixir integration
```

## Rust Source Replaced
- `src/main.rs` (5,052 LOC) — 50+ Clap subcommands

## Elixir Modules to Create

```
lib/decidulixir/
  cli.ex                      # Entrypoint
  cli/
    parser.ex                 # OptionParser routing
    commands/
      add.ex link.ex unlink.ex delete.ex status.ex prompt.ex
      nodes.ex edges.ex show.ex graph.ex backup.ex commands.ex
      pulse.ex dot.ex writeup.ex audit.ex
      doc.ex themes.ex tag.ex
    formatter.ex              # IO.ANSI terminal output
lib/mix/tasks/
  decidulixir.ex              # `mix decidulixir <cmd>` entry
```

## Key Contract: CLI.Command Behaviour

```elixir
defmodule Decidulixir.CLI.Command do
  @callback name() :: String.t()
  @callback description() :: String.t()
  @callback parse(argv :: [String.t()]) :: {:ok, map()} | {:error, String.t()}
  @callback run(args :: map()) :: :ok | {:error, String.t()}
end
```

## Boundary Rule
- CLI modules call ONLY Context modules (Goal 2)
- CLI NEVER touches Ecto directly
- Formatter handles all terminal output (colors, tables)

## Done When
- `mix decidulixir add goal "test" -c 90` works end-to-end
- All core commands functional
- Each command has isolated tests
