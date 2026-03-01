# Goal 2: Graph Context (Query Layer)

## Rust Source Replaced
- `src/db.rs` all 124 public functions (3,564 LOC) — the god-object `Database` struct

## Elixir Modules to Create

```
lib/decidulixir/
  graph.ex                    # Phoenix Context — public API
  graph/
    queries.ex                # Composable Ecto query builders
    metadata.ex               # Metadata JSON builders
    traversal.ex              # BFS/DFS graph traversal
    git.ex                    # Git helpers via System.cmd
```

## Key Contracts

```elixir
# graph.ex — Phoenix Context API
Graph.create_node(attrs) :: {:ok, %Node{}} | {:error, %Changeset{}}
Graph.create_edge(from_id, to_id, attrs) :: {:ok, %Edge{}} | {:error, term()}
Graph.get_graph(filters \\ []) :: %{nodes: [%Node{}], edges: [%Edge{}]}
Graph.get_node!(id) :: %Node{}
Graph.get_node(id) :: {:ok, %Node{}} | {:error, :not_found}
Graph.delete_node(id, opts) :: {:ok, %DeleteSummary{}} | {:error, term()}
Graph.update_node_status(id, status) :: {:ok, %Node{}} | {:error, term()}
Graph.update_node_prompt(id, prompt) :: {:ok, %Node{}} | {:error, term()}

# queries.ex — Composable fragments
Queries.by_branch(query, branch)
Queries.by_type(query, type)
Queries.by_status(query, status)
Queries.by_theme(query, theme_name)
Queries.recent(query, limit)

# traversal.ex — Graph algorithms
Traversal.bfs(start_id, direction) :: [%Node{}]
Traversal.connected_component(node_id) :: %{nodes: [%Node{}], edges: [%Edge{}]}
Traversal.children(node_id) :: [%Node{}]
Traversal.parents(node_id) :: [%Node{}]
```

## Philosophy
- The god-object `Database` gets decomposed into focused modules
- All functions return `{:ok, result} | {:error, reason}` tuples
- Queries are composable (pipe-friendly)
- Zero knowledge of CLI or web — pure data layer

## Done When
- Every Rust `Database` method has an Elixir equivalent
- Full test coverage via DataCase
- Traversal algorithms verified on known graph structures
