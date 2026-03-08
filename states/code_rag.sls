{# code-rag: hybrid text+code RAG with AST-aware chunking and LanceDB vector search.
   Installs from local source at ~/src/code-rag. Requires llama_embed for embeddings.
   MCP server configured in .mcp.json (not managed here — no systemd service).
#}
{% from '_imports.jinja' import home %}
{% from '_macros_install.jinja' import pip_pkg %}

{{ pip_pkg('code_rag', pkg=home ~ '/src/code-rag', bin='code-rag-index') }}
