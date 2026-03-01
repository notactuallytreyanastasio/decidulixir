# Goal 4: Web Layer (Phoenix LiveView)

## Rust Source Replaced
- `src/serve.rs` (1,233 LOC) — tiny_http server with 12+ API endpoints
- `web/` React SPA (~3,000 LOC TypeScript) — graph processing, D3 visualization, components

## Elixir Modules to Create

```
lib/decidulixir_web/
  live/
    graph_live/
      index.ex               # Main graph viewer (narratives, tree, D3)
      show.ex                # Node detail view
      components.ex          # Node cards, edge rendering
    archaeology_live/
      index.ex               # Narrative exploration, pivot chains
      timeline.ex            # Chronological node timeline
    pulse_live.ex            # Health dashboard
    command_log_live.ex      # Command history
    qa_live.ex               # Q&A viewer
  components/
    graph_components.ex      # Reusable: node badges, confidence bars, pivot markers
  controllers/api/
    graph_controller.ex      # GET /api/graph
    commands_controller.ex   # GET /api/commands
    qa_controller.ex         # GET/POST /api/qa
    git_history_controller.ex # GET /api/git-history
```

## Key Decisions
- Graph layout: LiveView hook + client-side D3/dagre JS (server provides data, browser does layout)
- Real-time: Phoenix.PubSub on "graph:updates" — no polling
- Theme: Dark purple (daisyUI custom theme matching current viewer)
- Archaeology LiveView: dedicated view for narrative exploration + pivot chains
- JSON API: backward compat with Rust viewer consumers

## Boundary Rule
- Web layer calls ONLY Context modules (Goal 2)
- Web NEVER touches Ecto directly

## React → LiveView Migration Notes
- React state → LiveView assigns
- React hooks → LiveView hooks (phx-hook)
- D3 SVG manipulation → LiveView JS hook calling D3
- Client-side BFS for narratives → Server-side in Elixir (faster, simpler)
- Polling (30s) → PubSub (instant)

## Done When
- `mix phx.server` shows working graph at localhost:4000
- Node detail, branch filtering, real-time updates work
- Archaeology view shows narratives and pivot chains
- JSON API endpoints functional
