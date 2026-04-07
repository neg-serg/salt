{# code-rag: hybrid text+code RAG with AST-aware chunking and LanceDB vector search.
   Installs from local source at ~/src/1st-level/@rag/code-rag. Requires llama_embed for embeddings.
   MCP server configured in .mcp.json (not managed here — no systemd service).
#}
{% from '_imports.jinja' import home %}
{% from '_macros_install.jinja' import pip_pkg %}
{% from '_macros_pkg.jinja' import pacman_install %}

{% set _rag_shared = home ~ '/src/1st-level/@rag/rag-shared' %}
{{ pip_pkg('code_rag', pkg=home ~ '/src/1st-level/@rag/code-rag', bin='code-rag-index', preinstall=_rag_shared) }}

{# docs-rag: external documentation ingestion (web, manpages, local) into shared LanceDB.
   Provides docs-import, docs-manpages, docs-remove, docs-list CLI commands.
   Requires mandoc for man page → markdown rendering.
#}
replace_mandb_with_mandoc:
  cmd.run:
    - name: pacman -Rdd --noconfirm man-db; pacman -S --noconfirm --needed mandoc
    - unless: pacman -Qi mandoc
    - require:
      - cmd: pacman_db_warmup

{{ pacman_install('mandoc', pkgs='mandoc') }}
{{ pip_pkg('docs_rag', pkg=home ~ '/src/1st-level/@rag/docs-rag', bin='docs-import', preinstall=_rag_shared) }}
