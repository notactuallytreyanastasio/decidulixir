# Goal 8: Telemetry & Observability

## Rust Source Replaced
Nothing — this is NEW functionality leveraging Elixir/Phoenix ecosystem strengths.

## Elixir Modules to Create

```
lib/decidulixir/
  telemetry.ex                # Event definitions and handler attachment
  telemetry/
    graph_events.ex           # Node/edge create/update/delete timing
    query_events.ex           # Query performance (slow queries, N+1)
    cli_events.ex             # Command execution tracking
    archaeology_events.ex     # Exploration layer tracking
    health_monitor.ex         # Periodic health checks (GenServer)
    alerts.ex                 # Alert definitions
    metrics.ex                # Custom metric aggregations

lib/decidulixir_web/live/
  dashboard_live.ex           # Custom LiveDashboard page
  health_live.ex              # Real-time health (PubSub-driven)
```

## Key Contracts

```elixir
# All graph operations emit telemetry
:telemetry.execute(
  [:decidulixir, :graph, :create_node],
  %{duration: duration},
  %{node_type: type, confidence: conf}
)

:telemetry.execute(
  [:decidulixir, :graph, :query],
  %{duration: duration},
  %{query_name: name, result_count: count}
)

# HealthMonitor GenServer
HealthMonitor.check_orphans() :: [%Node{}]
HealthMonitor.check_stale_goals(days) :: [%Node{}]
HealthMonitor.check_coverage_gaps() :: [%CoverageGap{}]
HealthMonitor.graph_growth_rate() :: %{nodes_per_day: float(), edges_per_day: float()}
```

## Leverages Existing Phoenix Infrastructure
- `:telemetry` (already in deps)
- `:telemetry_metrics` (already in deps)
- `:telemetry_poller` (already in deps)
- Phoenix LiveDashboard (already in deps)
- Phoenix PubSub (already in deps)

## Done When
- Graph operations emit telemetry with timing
- LiveDashboard custom page shows graph metrics
- Health monitor alerts on orphans, stale goals, gaps
- Slow queries flagged
- Tests cover handler registration and event emission
