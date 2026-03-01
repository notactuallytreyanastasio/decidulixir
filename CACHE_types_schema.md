# Goal 1: Core Types, Behaviours & Database Schema

## Rust Source Replaced
- `src/schema.rs` (218 LOC) — Diesel table definitions
- `src/db.rs` model structs (~450 LOC) — DecisionNode, DecisionEdge, etc.
- `src/config.rs` (382 LOC) — Config, BranchConfig

## Elixir Modules to Create

```
lib/decidulixir/
  types.ex                    # Ecto enums: NodeType, NodeStatus, EdgeType
  config.ex                   # App config (branch, github settings)
  graph/
    node.ex                   # decision_nodes schema + changeset
    edge.ex                   # decision_edges schema + changeset
    context.ex                # decision_context schema
    session.ex                # decision_sessions schema
    theme.ex                  # themes schema
    node_theme.ex             # node_themes join table
    document.ex               # node_documents schema
  command_log.ex              # command_log schema
  github/issue_cache.ex       # github_issue_cache schema
  qa/interaction.ex           # qa_interactions schema
priv/repo/migrations/
  *_create_decision_graph_tables.exs
  *_create_command_log.exs
  *_create_documents_and_themes.exs
  *_create_qa_interactions.exs
```

## Type Contracts

```elixir
# types.ex
@type node_type :: :goal | :decision | :option | :action | :outcome | :observation | :revisit
@type node_status :: :active | :superseded | :abandoned | :pending | :completed | :rejected
@type edge_type :: :leads_to | :requires | :chosen | :rejected | :blocks | :enables

# node.ex — key fields
- id: integer (PK)
- change_id: Ecto.UUID (generated on insert)
- node_type: node_type enum
- title: string (required)
- description: text (optional)
- status: node_status (default: :active)
- metadata_json: map (PostgreSQL jsonb — stores confidence, commit, prompt, files, branch)
- timestamps()

# edge.ex — key fields
- id: integer (PK)
- from_node_id: references(:decision_nodes)
- to_node_id: references(:decision_nodes)
- edge_type: edge_type (default: :leads_to)
- rationale: text (optional)
- weight: float (default: 1.0)
- timestamps()
```

## Key Improvement Over Rust
- `metadata_json` as native PostgreSQL `jsonb` (queryable!) vs Rust's text-serialized JSON
- PostgreSQL enums at DB level enforce valid values
- `change_id` UUID generated automatically via Ecto callback

## Done When
- All migrations run on fresh PostgreSQL
- All schemas compile with proper changesets
- CRUD tests pass for every schema type
- Enum types enforced at database level
