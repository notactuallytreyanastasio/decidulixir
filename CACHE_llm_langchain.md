# Goal 9: Generic LLM Adapter (Stretch Goal)

## Rust Source Replaced
Nothing — new functionality.

## Elixir Modules to Create

```
lib/decidulixir/
  adapters/
    llm.ex                    # LLM adapter behaviour
    llm/
      provider.ex             # Provider behaviour
      providers/
        ollama.ex             # Local Ollama
        openai.ex             # OpenAI API
        anthropic.ex          # Anthropic API
        lm_studio.ex          # LM Studio
      router.ex               # Route to configured provider
      config.ex               # Provider configuration
    langchain.ex              # LangChain-style adapter
    langchain/
      chain.ex                # Prompt chain abstraction
      tools.ex                # Graph ops as function-calling tools
      prompts/
        suggest_themes.ex     # Theme suggestion prompt
        describe_doc.ex       # Document description prompt
        summarize.ex          # Graph summarization prompt
```

## Key Contracts

```elixir
defmodule Decidulixir.Adapters.LLM.Provider do
  @callback chat(messages :: [%{role: String.t(), content: String.t()}], opts :: keyword()) ::
    {:ok, String.t()} | {:error, term()}
  @callback configured?() :: boolean()
  @callback name() :: String.t()
end
```

## Graceful Degradation
- No provider configured → skip LLM features entirely
- Theme suggestion → falls back to keyword matching
- Doc describe → falls back to file metadata
- All LLM calls are OPTIONAL enhancements

## Configuration
```elixir
config :decidulixir, :llm,
  provider: :ollama,
  model: "llama3",
  endpoint: "http://localhost:11434"
```

## Uses
- `Req` HTTP client (already in deps)
- `Mox` or `Req.Test` for testing

## Done When
- Ollama provider sends prompts and parses responses
- Theme suggestion uses LLM when available
- Doc `--ai-describe` generates descriptions
- Tests mock HTTP layer
- Provider behaviour makes new providers trivial to add
