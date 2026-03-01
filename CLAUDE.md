# Project Instructions

## Decision Graph Workflow

**THIS IS MANDATORY. Log decisions IN REAL-TIME, not retroactively.**

### Available Slash Commands

| Command | Purpose |
|---------|---------|
| `/decision` | Manage decision graph - add nodes, link edges, sync |
| `/recover` | Recover context from decision graph on session start |
| `/work` | Start a work transaction - creates goal node before implementation |
| `/document` | Generate comprehensive documentation for a file or directory |
| `/build-test` | Build the project and run the test suite |
| `/serve-ui` | Start the decision graph web viewer |
| `/sync-graph` | Export decision graph to GitHub Pages |
| `/decision-graph` | Build a decision graph from commit history |
| `/sync` | Multi-user sync - pull events, rebuild, push |

### Available Skills

| Skill | Purpose |
|-------|---------|
| `/pulse` | Map current design as decisions (Now mode) |
| `/narratives` | Understand how the system evolved (History mode) |
| `/archaeology` | Transform narratives into queryable graph |

### The Node Flow Rule - CRITICAL

The canonical flow through the decision graph is:

```
goal -> options -> decision -> actions -> outcomes
```

- **Goals** lead to **options** (possible approaches to explore)
- **Options** lead to a **decision** (choosing which option to pursue)
- **Decisions** lead to **actions** (implementing the chosen approach)
- **Actions** lead to **outcomes** (results of the implementation)
- **Observations** attach anywhere relevant
- Goals do NOT lead directly to decisions -- there must be options first
- Options do NOT come after decisions -- options come BEFORE decisions
- Decision nodes should only be created when an option is actually chosen, not prematurely

### The Core Rule

```
BEFORE you do something -> Log what you're ABOUT to do
AFTER it succeeds/fails -> Log the outcome
CONNECT immediately -> Link every node to its parent
AUDIT regularly -> Check for missing connections
```

### Behavioral Triggers - MUST LOG WHEN:

| Trigger | Log Type | Example |
|---------|----------|---------|
| User asks for a new feature | `goal` **with -p** | "Add dark mode" |
| Exploring possible approaches | `option` | "Use Redux for state" |
| Choosing between approaches | `decision` | "Choose state management" |
| About to write/edit code | `action` | "Implementing Redux store" |
| Something worked or failed | `outcome` | "Redux integration successful" |
| Notice something interesting | `observation` | "Existing code uses hooks" |

### Document Attachments

Attach files (images, PDFs, diagrams, specs, screenshots) to decision graph nodes for rich context.

```bash
# Attach a file to a node
deciduous doc attach <node_id> <file_path>
deciduous doc attach <node_id> <file_path> -d "Architecture diagram"
deciduous doc attach <node_id> <file_path> --ai-describe

# List documents
deciduous doc list              # All documents
deciduous doc list <node_id>    # Documents for a specific node

# Manage documents
deciduous doc show <doc_id>     # Show document details
deciduous doc describe <doc_id> "Updated description"
deciduous doc describe <doc_id> --ai   # AI-generate description
deciduous doc open <doc_id>     # Open in default application
deciduous doc detach <doc_id>   # Soft-delete (recoverable)
deciduous doc gc                # Remove orphaned files from disk
```

**When to suggest document attachment:**

| Situation | Action |
|-----------|--------|
| User shares an image or screenshot | Ask: "Want me to attach this to the current goal/action node?" |
| User references an external document | Ask: "Should I attach a copy to the decision graph?" |
| Architecture diagram is discussed | Suggest attaching it to the relevant goal node |
| Files not in the project are dropped in | Attach to the most relevant active node |

**Do NOT aggressively prompt for documents.** Only suggest when files are directly relevant to a decision node. Files are stored in `.deciduous/documents/` with content-hash naming for deduplication.

### CRITICAL: Capture VERBATIM User Prompts

**Prompts must be the EXACT user message, not a summary.** When a user request triggers new work, capture their full message word-for-word.

**BAD - summaries are useless for context recovery:**
```bash
# DON'T DO THIS - this is a summary, not a prompt
deciduous add goal "Add auth" -p "User asked: add login to the app"
```

**GOOD - verbatim prompts enable full context recovery:**
```bash
# Use --prompt-stdin for multi-line prompts
deciduous add goal "Add auth" -c 90 --prompt-stdin << 'EOF'
I need to add user authentication to the app. Users should be able to sign up
with email/password, and we need OAuth support for Google and GitHub. The auth
should use JWT tokens with refresh token rotation.
EOF

# Or use the prompt command to update existing nodes
deciduous prompt 42 << 'EOF'
The full verbatim user message goes here...
EOF
```

**When to capture prompts:**
- Root `goal` nodes: YES - the FULL original request
- Major direction changes: YES - when user redirects the work
- Routine downstream nodes: NO - they inherit context via edges

**Updating prompts on existing nodes:**
```bash
deciduous prompt <node_id> "full verbatim prompt here"
cat prompt.txt | deciduous prompt <node_id>  # Multi-line from stdin
```

Prompts are viewable in the web viewer.

### CRITICAL: Maintain Connections

**The graph's value is in its CONNECTIONS, not just nodes.**

| When you create... | IMMEDIATELY link to... |
|-------------------|------------------------|
| `outcome` | The action that produced it |
| `action` | The decision that spawned it |
| `decision` | The option(s) it chose between |
| `option` | Its parent goal |
| `observation` | Related goal/action |
| `revisit` | The decision/outcome being reconsidered |

**Root `goal` nodes are the ONLY valid orphans.**

### Quick Commands

```bash
deciduous add goal "Title" -c 90 -p "User's original request"
deciduous add action "Title" -c 85
deciduous link FROM TO -r "reason"  # DO THIS IMMEDIATELY!
deciduous serve   # View live (auto-refreshes every 30s)
deciduous sync    # Export for static hosting

# Metadata flags
# -c, --confidence 0-100   Confidence level
# -p, --prompt "..."       Store the user prompt (use when semantically meaningful)
# -f, --files "a.rs,b.rs"  Associate files
# -b, --branch <name>      Git branch (auto-detected)
# --commit <hash|HEAD>     Link to git commit (use HEAD for current commit)
# --date "YYYY-MM-DD"      Backdate node (for archaeology)

# Branch filtering
deciduous nodes --branch main
deciduous nodes -b feature-auth
```

### CRITICAL: Link Commits to Actions/Outcomes

**After every git commit, link it to the decision graph!**

```bash
git commit -m "feat: add auth"
deciduous add action "Implemented auth" -c 90 --commit HEAD
deciduous link <goal_id> <action_id> -r "Implementation"
```

The `--commit HEAD` flag captures the commit hash and links it to the node. The web viewer will show commit messages, authors, and dates.

### Git History & Deployment

```bash
# Export graph AND git history for web viewer
deciduous sync

# This creates:
# - docs/graph-data.json (decision graph)
# - docs/git-history.json (commit info for linked nodes)
```

To deploy to GitHub Pages:
1. `deciduous sync` to export
2. Push to GitHub
3. Settings > Pages > Deploy from branch > /docs folder

Your graph will be live at `https://<user>.github.io/<repo>/`

### Branch-Based Grouping

Nodes are auto-tagged with the current git branch. Configure in `.deciduous/config.toml`:
```toml
[branch]
main_branches = ["main", "master"]
auto_detect = true
```

### Audit Checklist (Before Every Sync)

1. Does every **outcome** link back to what caused it?
2. Does every **action** link to why you did it?
3. Any **dangling outcomes** without parents?

### Git Staging Rules - CRITICAL

**NEVER use broad git add commands that stage everything:**
- ❌ `git add -A` - stages ALL changes including untracked files
- ❌ `git add .` - stages everything in current directory
- ❌ `git add -a` or `git commit -am` - auto-stages all tracked changes
- ❌ `git add *` - glob patterns can catch unintended files

**ALWAYS stage files explicitly by name:**
- ✅ `git add src/main.rs src/lib.rs`
- ✅ `git add Cargo.toml Cargo.lock`
- ✅ `git add .claude/commands/decision.md`

**Why this matters:**
- Prevents accidentally committing sensitive files (.env, credentials)
- Prevents committing large binaries or build artifacts
- Forces you to review exactly what you're committing
- Catches unintended changes before they enter git history

### Session Start Checklist

```bash
deciduous check-update    # Update needed? Run 'deciduous update' if yes
deciduous nodes           # What decisions exist?
deciduous edges           # How are they connected? Any gaps?
deciduous doc list        # Any attached documents to review?
git status                # Current state
```

### Multi-User Sync

Sync decisions with teammates via event logs:

```bash
# Check sync status
deciduous events status

# Apply teammate events (after git pull)
deciduous events rebuild

# Compact old events periodically
deciduous events checkpoint --clear-events
```

Events auto-emit on add/link/status commands. Git merges event files automatically.

## Design Philosophy

### Functional core, imperative shell

Structure every application as a **pure functional core** wrapped by a **thin imperative shell**.

- **Functional core**: Pure functions that take data in, return data out. No side effects, no process state, no I/O. All business rules, data transformations, and validations live here. These functions are trivially testable -- pass in structs, assert on returned structs.
- **Imperative shell**: LiveViews, GenServers, controllers, Ecto operations, external API calls. The shell orchestrates side effects and calls into the functional core. Keep it as thin as possible.

### Type-first design

Always start by defining types that expose boundaries and compose into explicit contracts. Before writing implementation, define the `@type`, `@typedoc`, `defstruct`, and `@spec` that describe data flowing through the system.

**In practice, for every new module:**

1. Define `@type t` -- what IS this thing?
2. Define `defstruct` with defaults -- what fields does it have?
3. Define `@spec` on public functions -- what goes in, what comes out?
4. THEN write the implementation

### No OO constructors

Do NOT create `.new()` constructor functions. Elixir structs are data -- construct them directly with `%Module{field: value}`. The `defstruct` defaults are the single source of truth.

## Work Transactions -- ALWAYS USE /work

**Every meaningful unit of work MUST start with `/work "description"`.** A "meaningful unit" is any change a future session would want to understand. Only trivial one-line typo fixes skip this.

### Flow

1. User asks for something (or you identify work)
2. `/work "short description"` -- creates a goal node with verbatim user request
3. Before each file edit, create an action node linked to the goal
4. After completing work, create an outcome node, commit, link with `--commit HEAD`
5. `deciduous sync` to export

### Multiple changes = multiple transactions

```
User: "fix the tile contrast and slow down the scanner"

-> /work "Fix light tile contrast"    # goal + actions + outcome + commit
-> /work "Slow scanner speed 8x"     # separate goal + actions + outcome + commit
```

One `/work` = one logical change = one commit.

## Rebase Only -- No Merge Commits

**ALWAYS** rebase. Never `git merge`. History must be linear.

## Project Guidelines

- Use `mix precommit` alias to verify all changes before committing
- Use `:req` (`Req`) for HTTP requests. Never use `:httpoison`, `:tesla`, or `:httpc`

### Phoenix v1.8

- LiveView templates start with `<Layouts.app flash={@flash} ...>` wrapping all content. `Layouts` is already aliased in the app web module
- `current_scope` errors mean your routes are in the wrong `live_session` or you forgot to pass `current_scope` to `<Layouts.app>`
- `<.flash_group>` lives in `Layouts` only -- never call it elsewhere
- Use `<.icon name="hero-x-mark" class="w-5 h-5"/>` for icons (from `core_components.ex`). Never use `Heroicons` modules
- Use `<.input>` for form inputs (imported from `core_components.ex`). When overriding classes, no defaults are inherited -- you must fully style the input

### JS & CSS

- Tailwind CSS v4: no `tailwind.config.js`. Uses import syntax in `app.css`
- Never use `@apply` in raw CSS
- Only `app.js` and `app.css` bundles exist. Import vendor deps into these files. No external `<script src>` or `<link href>` in layouts. No inline `<script>` tags in templates

## Elixir guidelines

- Elixir lists **do not support index based access via the access syntax**. **Always** use `Enum.at`, pattern matching, or `List` for index based list access
- Elixir variables are immutable, but can be rebound. Block expressions like `if`, `case`, `cond` must bind the result to a variable
- **Never** nest multiple modules in the same file as it can cause cyclic dependencies
- **Never** use map access syntax (`changeset[:field]`) on structs. Use dot access or `Ecto.Changeset.get_field/2`
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should end in `?`, not start with `is_`. Reserve `is_` for guards
- OTP primitives like `DynamicSupervisor` and `Registry` require names in the child spec
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure. Almost always pass `timeout: :infinity`

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it

## Test guidelines

- **Always use `start_supervised!/1`** to start processes in tests as it guarantees cleanup between tests
- **Avoid** `Process.sleep/1` and `Process.alive?/1` in tests
- Use `Process.monitor/1` and assert on the DOWN message instead of sleep
- Use `_ = :sys.get_state/1` to synchronize before the next call

## Phoenix guidelines

- Router `scope` blocks include an optional alias prefixed for all routes within. **Always** be mindful of this
- You **never** need to create your own `alias` for route definitions -- the `scope` provides the alias
- `Phoenix.View` no longer exists. Don't use it

## Ecto Guidelines

- **Always** preload Ecto associations in queries when they'll be accessed in templates
- `Ecto.Schema` fields always use the `:string` type, even for `:text` columns
- `Ecto.Changeset.validate_number/2` **DOES NOT SUPPORT the `:allow_nil` option**
- You **must** use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields
- Fields set programmatically (like `user_id`) must not be listed in `cast` calls for security
- **Always** invoke `mix ecto.gen.migration migration_name_using_underscores` when generating migration files

## Phoenix HTML guidelines

- Phoenix templates **always** use `~H` or .html.heex files (HEEx), **never** use `~E`
- **Always** use `Phoenix.Component.form/1` and `Phoenix.Component.inputs_for/1`. **Never** use `Phoenix.HTML.form_for` or `Phoenix.HTML.inputs_for`
- **Always** use `Phoenix.Component.to_form/2` and `<.form for={@form}>`. Never pass changesets directly to templates
- **Always** add unique DOM IDs to key elements (forms, buttons, etc.)
- **Never** use `else if` or `elsif` in Elixir. Use `cond` or `case`
- HEEx class attrs support lists with conditional syntax: `class={["px-2", @flag && "py-5"]}`
- **Never** use `<% Enum.each %>`. Use `<%= for item <- @collection do %>`
- HEEx HTML comments: `<%!-- comment --%>`
- Use `{...}` for interpolation within tag attributes and tag bodies. Use `<%= ... %>` for block constructs (if, cond, case, for)

## Phoenix LiveView guidelines

- **Never** use deprecated `live_redirect` and `live_patch`. Use `<.link navigate={href}>` and `<.link patch={href}>`
- **Avoid LiveComponent's** unless you have a strong, specific need
- LiveViews should be named with a `Live` suffix: `DecidulixirWeb.GraphLive`
- **Always** use LiveView streams for collections (never assign raw lists -- they balloon memory)
- LiveView streams are *not* enumerable -- refetch and use `reset: true` to filter
- Streams don't support counting -- track with separate assign
- When updating an assign inside stream items, re-stream them
- **Never** use deprecated `phx-update="append"` or `phx-update="prepend"`
- Use colocated js hooks (`:type={Phoenix.LiveView.ColocatedHook}`) -- never raw `<script>` tags
- Colocated hook names **MUST** start with `.` prefix: `.PhoneNumber`
- External hooks in `assets/js/`, pass to `LiveSocket` constructor
- **Always** use `to_form/2` and `<.form for={@form}>`. **Never** use `<.form let={f}>`

## Code Quality

- `mix precommit` runs: compile (warnings-as-errors), credo --strict, test, dialyzer, format
- Eliminate every compiler warning
- Credo strict mode -- follow every rule
- Write pure functions that are easy to test
- TDD: test first, strict test-driven development
