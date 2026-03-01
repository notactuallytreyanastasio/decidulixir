# Goal 7: Retroactive Decision Graph (KEY FEATURE)

## Rust Source Replaced
- `src/archaeology.rs` (459 LOC) — atomic pivot/timeline/supersede operations
- `src/narratives.rs` (258 LOC) — narrative tracking and pivot detection
- `src/pulse.rs` (411 LOC) — graph health reporting
- `src/github.rs` (641 LOC) — GitHub CLI wrapper for PR mining
- `.claude/commands/decision-graph.md` (400+ lines) — 4-layer exploration methodology
- `src/export.rs` writeup portion (~300 LOC) — PR writeup generation

## THIS IS THE KEY FEATURE
The ability to take any git repository and retroactively construct a decision graph
from its commit history. "History Mode" — understanding how a system evolved.

## 5 Layers of the Feature

### Layer A: Git History Exploration Engine

```
lib/decidulixir/archaeology/
  explorer.ex                 # Orchestrate 4-layer exploration
  explorer/
    commit_scanner.ex         # Layer 1: Full commit visibility
    keyword_expander.ex       # Layer 2: Identifier lifecycle tracing
    author_follower.ex        # Layer 3: Follow key authors ±1 month
    pr_miner.ex               # Layer 4: GitHub PR context via gh CLI
```

**Layer 1** — Full commit scan: `git log --oneline --after --before -- path/`
**Layer 2** — Keyword expansion: "cache" → "caching", "cached", "LRU", "invalidate"
**Layer 3** — Author following: key author's commits ±1 month from known commits
**Layer 4** — PR mining: `gh pr list/view`, `gh api repos/.../pulls/N/comments`
  - PR descriptions contain rationale that NEVER appears in commit messages
  - Review threads capture alternatives, trade-offs, rejected approaches

### Layer B: Narrative Tracking

```
lib/decidulixir/archaeology/
  narratives.ex               # Narrative lifecycle management
  narratives/
    tracker.ex                # Track, merge related narratives
    hardener.ex               # Exhaustive concept search, fill gaps
    writer.ex                 # Generate .deciduous/narratives.md
    pivot_detector.ex         # Detect pivot points
```

Key principle: "Don't build the graph as you explore. First, collect commits into narratives."
Narratives are the INTERMEDIATE REPRESENTATION — curated raw material, not the final graph.

### Layer C: Archaeology Atomic Operations

```
lib/decidulixir/archaeology/
  builder.ex                  # Convert hardened narratives → graph nodes
  operations/
    pivot.ex                  # Atomic: observation → revisit → new decision (Ecto.Multi)
    timeline.ex               # Chronological node view
    supersede.ex              # Mark superseded with cascade
```

`create_pivot/3` — 7 steps in 1 Ecto.Multi transaction:
1. Create observation node
2. Link from_id → observation
3. Create revisit node
4. Link observation → revisit
5. Create new decision node
6. Link revisit → new decision
7. Mark old node as superseded

TEMPORAL DISCIPLINE: sequential attempts are chained decisions, NOT parallel options.

### Layer D: Pulse & Health

```
lib/decidulixir/archaeology/
  pulse.ex
  pulse/report.ex coverage.ex confidence.ex
```

### Layer E: Grounding Enforcement

```
lib/decidulixir/archaeology/
  grounding.ex
  grounding/validator.ex source_extractor.ex
```

Every action node MUST cite commit SHA. NO speculation.

## Also Includes (from eliminated Sync/Export)

```
lib/decidulixir/export/
  writeup.ex                  # PR writeup markdown
  json.ex                     # JSON graph export
  git_history.ex              # Commit info for linked nodes
```

## Key Contracts

```elixir
# Explorer behaviour
@callback explore(repo_path :: Path.t(), opts :: keyword()) :: {:ok, [%Commit{}]} | {:error, term()}

# Narrative struct
@type t :: %Narrative{
  name: String.t(),
  commits: [%Commit{}],
  concepts: [%Concept{}],
  pivot_points: [%PivotPoint{}],
  cross_references: [String.t()],
  hardened?: boolean()
}

# PivotChain struct
@type t :: %PivotChain{
  revisit: %Node{},
  observations: [%Node{}],
  old_approaches: [%Node{}],
  new_approaches: [%Node{}]
}
```

## GitHub Integration

```
lib/decidulixir/github/
  client.ex                   # gh CLI wrapper (System.cmd)
  pr.ex                       # PR struct and operations
  comment.ex                  # Review comment extraction
```

## Done When
- `mix decidulixir archaeology pivot` creates atomic pivot chains
- `mix decidulixir narratives init/show/pivots` work
- `mix decidulixir pulse` shows health report
- `mix decidulixir writeup` generates PR markdown
- GitHub PR mining extracts design rationale
- Grounding validator flags uncited nodes
- Round-trip: narratives → graph → detect pivots → verify
