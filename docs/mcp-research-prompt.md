<research>
<meta>
  <methodology>GRACE</methodology>
  <expected_duration>extended</expected_duration>
  <output_format>structured_report</output_format>
</meta>

<goal>
  Find MCP (Model Context Protocol) servers that provide genuinely unique capabilities
  not available through Claude Code's built-in toolset. The result should be a curated
  catalog of MCP servers that expand what Claude Code can do, rather than duplicate
  what it already does. Focus on free, locally-running servers that require no paid
  API keys or external service accounts.
</goal>

<requirements>
  <hard_constraints>
    <constraint id="free">No paid API keys, subscriptions, or credit cards required. Self-hosted tokens for local services (e.g. a Grafana instance you own) are acceptable.</constraint>
    <constraint id="local">Must run locally via npx, uvx, pip, cargo, go, or a single binary. No cloud-hosted SaaS-only servers.</constraint>
    <constraint id="no_duplication">Must NOT duplicate Claude Code's built-in tools unless the MCP version provides a measurable, qualitative improvement. See the exclusion list below.</constraint>
    <constraint id="maintained">Must have commits within the last 6 months. No archived or abandoned projects.</constraint>
    <constraint id="stable">Must be functional — not a proof-of-concept, demo, or "awesome-list-only" entry with no working code.</constraint>
  </hard_constraints>

  <soft_preferences>
    <preference priority="high">Servers that unlock entirely new domains (hardware, media, protocols, data formats) rather than wrapping CLI tools Claude Code can already call via Bash.</preference>
    <preference priority="high">Servers with structured output that would be impractical to replicate via CLI parsing (e.g. binary format inspection, AST manipulation, protocol-level interaction).</preference>
    <preference priority="medium">Servers relevant to a Linux power-user stack: Arch Linux, systemd, Salt, chezmoi, podman, btrfs, Hyprland/Wayland, PipeWire, neovim, QML/Qt, Grafana/Loki/Prometheus, MPD, DNS (Unbound/AdGuard).</preference>
    <preference priority="medium">Servers that enable agentic workflows: task orchestration, multi-step pipelines, approval gates, state machines.</preference>
    <preference priority="low">Novelty and creativity — unusual or unexpected capabilities that expand the imagination of what Claude Code can do.</preference>
  </soft_preferences>

  <exclusion_list>
    <explanation>
      Claude Code already has these built-in tools. Any MCP server that primarily
      wraps the same functionality should be EXCLUDED unless it adds a qualitative
      leap (not just a JSON wrapper around the same CLI).
    </explanation>
    <excluded tool="Bash">Full shell access with timeout, background execution, piping, heredoc. Covers: git, podman, curl, systemctl, journalctl, ip, ss, date, sqlite3, python3, cargo, make, and any CLI tool on PATH.</excluded>
    <excluded tool="Read">File reading with line offsets, image viewing (PNG/JPG), PDF reading (with page ranges), Jupyter notebook rendering.</excluded>
    <excluded tool="Write">File creation and full overwrite.</excluded>
    <excluded tool="Edit">Exact string replacement in files with uniqueness validation.</excluded>
    <excluded tool="Glob">Fast file pattern matching (e.g. **/*.sls, src/**/*.qml).</excluded>
    <excluded tool="Grep">ripgrep-powered content search: regex, glob/type filters, multiline, context lines, output modes (content/files/count), head/offset pagination.</excluded>
    <excluded tool="WebFetch">URL fetching with HTML-to-markdown conversion and AI-powered content extraction.</excluded>
    <excluded tool="WebSearch">Web search with domain filtering.</excluded>
    <excluded tool="Task/Agent">Subagent spawning for parallel research, code exploration, planning. Includes git worktree isolation.</excluded>
    <excluded tool="Playwright MCP">Already configured. Browser automation, screenshots, DOM interaction, accessibility tree.</excluded>
    <excluded tool="code-rag MCP">Already configured. Vector + full-text hybrid search over indexed code projects.</excluded>
    <excluded tool="context7 MCP">Already configured. Live library documentation retrieval.</excluded>
    <excluded tool="memory MCP">Already configured. Persistent knowledge graph between sessions.</excluded>
    <excluded tool="sequential-thinking MCP">Already configured. Extended step-by-step reasoning.</excluded>
  </exclusion_list>
</requirements>

<audience>
  A single Linux power user managing a CachyOS (Arch-based) workstation with:
  - Salt states + chezmoi dotfiles for configuration management
  - Hyprland (Wayland compositor) + Quickshell (QML-based shell)
  - PipeWire audio, MPD for music
  - Podman containers (not Docker, not Kubernetes)
  - Grafana + Loki + Promtail + Prometheus monitoring stack
  - Unbound + AdGuardHome DNS
  - Btrfs with snapper snapshots
  - Neovim as primary editor
  - Gopass (GPG + Yubikey) for secrets
  - Ollama for local LLMs
  This is NOT an enterprise or team setup. No CI/CD, no cloud infrastructure, no web app development.
</audience>

<context>
  <what_is_mcp>
    MCP (Model Context Protocol) is an open standard by Anthropic that lets AI assistants
    connect to external tools and data sources. An MCP server exposes "tools" (functions
    the AI can call), "resources" (data the AI can read), and "prompts" (templates).
    Servers communicate via stdio (local process) or HTTP/SSE (remote).
  </what_is_mcp>

  <current_state>
    As of March 2026, the MCP ecosystem has grown significantly beyond the original
    reference servers at github.com/modelcontextprotocol/servers. There are hundreds
    of community servers across GitHub, npm, PyPI, and crates.io. Many are thin wrappers
    around CLI tools (which are useless for Claude Code), but some provide genuinely
    novel capabilities.
  </current_state>

  <known_dead_ends>
    The following have already been evaluated and rejected. Do NOT re-recommend them:
    - mcp-server-git (subset of git CLI)
    - @modelcontextprotocol/server-filesystem (subset of Read/Write/Edit/Glob)
    - mcp-server-fetch (subset of WebFetch)
    - @modelcontextprotocol/server-puppeteer (archived, replaced by Playwright)
    - mcp-server-time (date command via Bash)
    - @modelcontextprotocol/server-everything (test harness)
    - @modelcontextprotocol/server-brave-search (paid API key)
    - exa-mcp-server (paid API key)
    - podman-mcp-server (already have podman via Bash)
    - kubernetes-mcp-server (not in stack)
    - mcp-ripgrep (built-in Grep is ripgrep)
    - DesktopCommanderMCP (built for Claude Desktop, 95% overlap)
    - mcp-server-sqlite (sqlite3 via Bash suffices)
    - loki-mcp (subset of mcp-grafana, needs Go build)
  </known_dead_ends>
</context>

<search_strategy>
  <phase id="1" name="discovery">
    <instruction>Cast a wide net across these sources:</instruction>
    <source>github.com/punkpeye/awesome-mcp-servers — the largest curated list</source>
    <source>github.com/modelcontextprotocol/servers — official reference servers (check for new additions since Jan 2026)</source>
    <source>github.com topics: mcp-server, model-context-protocol</source>
    <source>npm search: "mcp-server", "@modelcontextprotocol"</source>
    <source>PyPI search: "mcp-server", "mcp-"</source>
    <source>Reddit: r/ClaudeAI, r/LocalLLaMA — MCP server recommendations</source>
    <source>Hacker News discussions about MCP servers</source>
    <source>smithery.ai — MCP server registry</source>
    <source>glama.ai/mcp/servers — another MCP registry</source>
    <source>mcp.so — MCP server directory</source>
  </phase>

  <phase id="2" name="categorization">
    <instruction>Group discovered servers into capability domains:</instruction>
    <domain>System introspection (hardware, sensors, kernel, network topology)</domain>
    <domain>Media processing (audio, video, image analysis/manipulation)</domain>
    <domain>Data formats and protocols (binary inspection, protocol debugging, serialization)</domain>
    <domain>Development tooling (AST, linting, testing, profiling, debugging)</domain>
    <domain>Knowledge and documentation (wikis, man pages, RFCs, standards)</domain>
    <domain>Communication and notifications (email, IRC, Matrix, RSS)</domain>
    <domain>Security and cryptography (certificate inspection, GPG, vulnerability scanning)</domain>
    <domain>Monitoring and observability (metrics, logs, tracing — beyond Grafana)</domain>
    <domain>Automation and orchestration (workflows, schedulers, state machines)</domain>
    <domain>AI/ML integration (local model interaction, embedding, RAG pipelines)</domain>
    <domain>Desktop/window manager integration (Wayland, D-Bus, notifications)</domain>
    <domain>Any other domain not listed above</domain>
  </phase>

  <phase id="3" name="deep_evaluation">
    <instruction>For each candidate that passes the hard constraints, evaluate:</instruction>
    <criterion>What specific tools does it expose? List them.</criterion>
    <criterion>Can the same result be achieved via Bash + existing CLI tools? If yes, what is the qualitative difference (structured output, stateful interaction, performance)?</criterion>
    <criterion>What is the installation method? (npx, uvx, pip, cargo, binary, container)</criterion>
    <criterion>What are the runtime dependencies? (runtime, libraries, system packages)</criterion>
    <criterion>How active is development? (last commit, stars, open issues, contributors)</criterion>
    <criterion>Are there known issues or limitations?</criterion>
  </phase>

  <phase id="4" name="synthesis">
    <instruction>Produce the final report with servers ranked by uniqueness score:</instruction>
    <tier name="must_have">Unlocks an entirely new capability domain. No built-in equivalent exists, even approximately.</tier>
    <tier name="strong_add">Provides significant improvement over Bash workarounds. Structured interaction that would be fragile or impractical to replicate via CLI parsing.</tier>
    <tier name="nice_to_have">Convenience improvement. Same result achievable via Bash but with more effort or less reliability.</tier>
    <tier name="niche">Useful only in specific scenarios relevant to this user's stack.</tier>
  </phase>
</search_strategy>

<output_format>
  <section name="executive_summary">
    Top 5-10 recommendations with one-line descriptions, sorted by uniqueness.
  </section>

  <section name="detailed_catalog">
    For each recommended server:
    - Name, repository URL, package name
    - Installation command (exact, copy-pasteable)
    - .mcp.json configuration block (exact JSON)
    - Capability domain
    - Tools exposed (full list)
    - Why it's not a duplicate (specific comparison to Claude Code built-ins)
    - Relevance to user's stack
    - Tier (must_have / strong_add / nice_to_have / niche)
    - Caveats or limitations
  </section>

  <section name="honorable_mentions">
    Servers that almost made the cut but were excluded, with brief reasons why.
  </section>

  <section name="ecosystem_trends">
    Notable patterns or emerging categories in the MCP ecosystem that may
    produce useful servers in the near future.
  </section>
</output_format>

<quality_checks>
  <check>Every recommended server must have been verified to exist at its stated URL.</check>
  <check>Every installation command must be tested or verified from official documentation.</check>
  <check>No server from the known_dead_ends list appears in recommendations.</check>
  <check>No server requiring a paid API key appears in recommendations.</check>
  <check>Every server has a clear explanation of why it is NOT a duplicate of built-in tools.</check>
  <check>The report contains at least 3 domains beyond "development tooling".</check>
</quality_checks>
</research>
