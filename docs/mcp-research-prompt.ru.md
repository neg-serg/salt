<research>
<meta>
  <methodology>GRACE</methodology>
  <expected_duration>extended</expected_duration>
  <output_format>structured_report</output_format>
</meta>

<goal>
  Найти MCP (Model Context Protocol) серверы, предоставляющие действительно уникальные
  возможности, недоступные через встроенный набор инструментов Claude Code. Результатом
  должен быть курированный каталог MCP серверов, расширяющих функционал Claude Code,
  а не дублирующих его. Фокус на бесплатных, локально запускаемых серверах, не требующих
  платных API-ключей или внешних сервисных аккаунтов.
</goal>

<requirements>
  <hard_constraints>
    <constraint id="free">Без платных API-ключей, подписок или банковских карт. Собственные токены для локальных сервисов (например, собственный экземпляр Grafana) допустимы.</constraint>
    <constraint id="local">Должен запускаться локально через npx, uvx, pip, cargo, go или как единый бинарник. Никаких облачных SaaS-серверов.</constraint>
    <constraint id="no_duplication">НЕ должен дублировать встроенные инструменты Claude Code, если только MCP-версия не обеспечивает измеримое, качественное улучшение. См. список исключений ниже.</constraint>
    <constraint id="maintained">Коммиты за последние 6 месяцев. Никаких архивированных или заброшенных проектов.</constraint>
    <constraint id="stable">Должен быть функционален — не proof-of-concept, не демо, не запись из awesome-листа без рабочего кода.</constraint>
  </hard_constraints>

  <soft_preferences>
    <preference priority="high">Серверы, открывающие совершенно новые домены (оборудование, медиа, протоколы, форматы данных), а не оборачивающие CLI-инструменты, уже доступные Claude Code через Bash.</preference>
    <preference priority="high">Серверы со структурированным выводом, который было бы непрактично воспроизвести через парсинг CLI (например, инспекция бинарных форматов, манипуляция AST, взаимодействие на уровне протоколов).</preference>
    <preference priority="medium">Серверы, релевантные стеку Linux-опытного пользователя: Arch Linux, systemd, Salt, chezmoi, podman, btrfs, Hyprland/Wayland, PipeWire, neovim, QML/Qt, Grafana/Loki/Prometheus, MPD, DNS (Unbound/AdGuard).</preference>
    <preference priority="medium">Серверы, обеспечивающие агентные рабочие процессы: оркестрация задач, многоэтапные пайплайны, шлюзы одобрения, конечные автоматы.</preference>
    <preference priority="low">Новизна и креативность — необычные или неожиданные возможности, расширяющие представление о том, что может делать Claude Code.</preference>
  </soft_preferences>

  <exclusion_list>
    <explanation>
      Claude Code уже имеет эти встроенные инструменты. Любой MCP-сервер, который
      в основном оборачивает ту же функциональность, должен быть ИСКЛЮЧЁН, если
      он не добавляет качественный скачок (а не просто JSON-обёртку над тем же CLI).
    </explanation>
    <excluded tool="Bash">Полный доступ к shell с таймаутами, фоновым выполнением, пайпами, heredoc. Покрывает: git, podman, curl, systemctl, journalctl, ip, ss, date, sqlite3, python3, cargo, make и любой CLI-инструмент в PATH.</excluded>
    <excluded tool="Read">Чтение файлов со смещением строк, просмотр изображений (PNG/JPG), чтение PDF (с диапазонами страниц), рендеринг Jupyter notebook.</excluded>
    <excluded tool="Write">Создание файлов и полная перезапись.</excluded>
    <excluded tool="Edit">Точная замена строк в файлах с проверкой уникальности.</excluded>
    <excluded tool="Glob">Быстрый поиск файлов по шаблону (например, **/*.sls, src/**/*.qml).</excluded>
    <excluded tool="Grep">Поиск содержимого на базе ripgrep: регулярные выражения, фильтры glob/type, многострочный режим, контекстные строки, режимы вывода (content/files/count), пагинация head/offset.</excluded>
    <excluded tool="WebFetch">Загрузка URL с конвертацией HTML в markdown и AI-извлечением контента.</excluded>
    <excluded tool="WebSearch">Веб-поиск с фильтрацией по доменам.</excluded>
    <excluded tool="Task/Agent">Запуск подагентов для параллельных исследований, исследования кода, планирования. Включает изоляцию через git worktree.</excluded>
    <excluded tool="Playwright MCP">Уже настроен. Автоматизация браузера, скриншоты, взаимодействие с DOM, дерево доступности.</excluded>
    <excluded tool="code-rag MCP">Уже настроен. Гибридный векторный + полнотекстовый поиск по индексированным проектам кода.</excluded>
    <excluded tool="context7 MCP">Уже настроен. Получение актуальной документации библиотек.</excluded>
    <excluded tool="memory MCP">Уже настроен. Постоянный граф знаний между сессиями.</excluded>
    <excluded tool="sequential-thinking MCP">Уже настроен. Расширенное пошаговое рассуждение.</excluded>
  </exclusion_list>
</requirements>

<audience>
  Один опытный Linux-пользователь, управляющий рабочей станцией CachyOS (на базе Arch) с:
  - Salt states + chezmoi dotfiles для управления конфигурацией
  - Hyprland (Wayland-композитор) + Quickshell (QML-оболочка)
  - PipeWire аудио, MPD для музыки
  - Podman-контейнеры (не Docker, не Kubernetes)
  - Стек мониторинга Grafana + Loki + Promtail + Prometheus
  - Unbound + AdGuardHome DNS
  - Btrfs со снапшотами snapper
  - Neovim как основной редактор
  - Gopass (GPG + Yubikey) для секретов
  - Ollama для локальных LLM
  Это НЕ корпоративная или командная установка. Нет CI/CD, нет облачной инфраструктуры, нет разработки веб-приложений.
</audience>

<context>
  <what_is_mcp>
    MCP (Model Context Protocol) — открытый стандарт Anthropic, позволяющий AI-ассистентам
    подключаться к внешним инструментам и источникам данных. MCP-сервер предоставляет
    «инструменты» (функции, которые AI может вызывать), «ресурсы» (данные, которые AI
    может читать) и «промпты» (шаблоны). Серверы общаются через stdio (локальный процесс)
    или HTTP/SSE (удалённый).
  </what_is_mcp>

  <current_state>
    По состоянию на март 2026 года экосистема MCP значительно выросла за пределы
    оригинальных эталонных серверов на github.com/modelcontextprotocol/servers.
    Существуют сотни community-серверов на GitHub, npm, PyPI и crates.io. Многие
    являются тонкими обёртками над CLI-инструментами (бесполезны для Claude Code),
    но некоторые предоставляют действительно уникальные возможности.
  </current_state>

  <known_dead_ends>
    Следующие уже были оценены и отклонены. НЕ рекомендуйте их повторно:
    - mcp-server-git (подмножество git CLI)
    - @modelcontextprotocol/server-filesystem (подмножество Read/Write/Edit/Glob)
    - mcp-server-fetch (подмножество WebFetch)
    - @modelcontextprotocol/server-puppeteer (архивирован, заменён Playwright)
    - mcp-server-time (команда date через Bash)
    - @modelcontextprotocol/server-everything (тестовый стенд)
    - @modelcontextprotocol/server-brave-search (платный API-ключ)
    - exa-mcp-server (платный API-ключ)
    - podman-mcp-server (podman уже доступен через Bash)
    - kubernetes-mcp-server (не в стеке)
    - mcp-ripgrep (встроенный Grep — это ripgrep)
    - DesktopCommanderMCP (создан для Claude Desktop, 95% пересечение)
    - mcp-server-sqlite (sqlite3 через Bash достаточно)
    - loki-mcp (подмножество mcp-grafana, требует сборки Go)
  </known_dead_ends>
</context>

<search_strategy>
  <phase id="1" name="discovery">
    <instruction>Широкий поиск по следующим источникам:</instruction>
    <source>github.com/punkpeye/awesome-mcp-servers — крупнейший курированный список</source>
    <source>github.com/modelcontextprotocol/servers — официальные эталонные серверы (проверить новые дополнения с января 2026)</source>
    <source>Топики GitHub: mcp-server, model-context-protocol</source>
    <source>Поиск npm: "mcp-server", "@modelcontextprotocol"</source>
    <source>Поиск PyPI: "mcp-server", "mcp-"</source>
    <source>Reddit: r/ClaudeAI, r/LocalLLaMA — рекомендации MCP-серверов</source>
    <source>Обсуждения Hacker News об MCP-серверах</source>
    <source>smithery.ai — реестр MCP-серверов</source>
    <source>glama.ai/mcp/servers — ещё один реестр MCP</source>
    <source>mcp.so — каталог MCP-серверов</source>
  </phase>

  <phase id="2" name="categorization">
    <instruction>Группировка найденных серверов по доменам возможностей:</instruction>
    <domain>Системная интроспекция (оборудование, датчики, ядро, сетевая топология)</domain>
    <domain>Обработка медиа (аудио, видео, анализ/манипуляция изображений)</domain>
    <domain>Форматы данных и протоколы (инспекция бинарных файлов, отладка протоколов, сериализация)</domain>
    <domain>Инструменты разработки (AST, линтинг, тестирование, профилирование, отладка)</domain>
    <domain>Знания и документация (вики, man-страницы, RFC, стандарты)</domain>
    <domain>Коммуникации и уведомления (email, IRC, Matrix, RSS)</domain>
    <domain>Безопасность и криптография (инспекция сертификатов, GPG, сканирование уязвимостей)</domain>
    <domain>Мониторинг и наблюдаемость (метрики, логи, трассировка — помимо Grafana)</domain>
    <domain>Автоматизация и оркестрация (рабочие процессы, планировщики, конечные автоматы)</domain>
    <domain>Интеграция AI/ML (взаимодействие с локальными моделями, эмбеддинги, RAG-пайплайны)</domain>
    <domain>Интеграция десктопа/оконного менеджера (Wayland, D-Bus, уведомления)</domain>
    <domain>Любой другой домен не из списка выше</domain>
  </phase>

  <phase id="3" name="deep_evaluation">
    <instruction>Для каждого кандидата, прошедшего жёсткие ограничения, оценить:</instruction>
    <criterion>Какие конкретные инструменты он предоставляет? Перечислить.</criterion>
    <criterion>Можно ли достичь того же результата через Bash + существующие CLI-инструменты? Если да, в чём качественная разница (структурированный вывод, stateful-взаимодействие, производительность)?</criterion>
    <criterion>Каков метод установки? (npx, uvx, pip, cargo, бинарник, контейнер)</criterion>
    <criterion>Каковы runtime-зависимости? (среда выполнения, библиотеки, системные пакеты)</criterion>
    <criterion>Насколько активна разработка? (последний коммит, звёзды, открытые issues, контрибьюторы)</criterion>
    <criterion>Есть ли известные проблемы или ограничения?</criterion>
  </phase>

  <phase id="4" name="synthesis">
    <instruction>Подготовить финальный отчёт с серверами, ранжированными по баллу уникальности:</instruction>
    <tier name="must_have">Открывает совершенно новый домен возможностей. Встроенного эквивалента не существует даже приблизительно.</tier>
    <tier name="strong_add">Значительное улучшение по сравнению с обходными решениями через Bash. Структурированное взаимодействие, которое было бы хрупким или непрактичным для воспроизведения через парсинг CLI.</tier>
    <tier name="nice_to_have">Удобство. Тот же результат достижим через Bash, но с большими усилиями или меньшей надёжностью.</tier>
    <tier name="niche">Полезен только в специфических сценариях, релевантных стеку данного пользователя.</tier>
  </phase>
</search_strategy>

<output_format>
  <section name="executive_summary">
    Топ 5-10 рекомендаций с однострочными описаниями, отсортированные по уникальности.
  </section>

  <section name="detailed_catalog">
    Для каждого рекомендованного сервера:
    - Название, URL репозитория, имя пакета
    - Команда установки (точная, для копирования)
    - Блок конфигурации .mcp.json (точный JSON)
    - Домен возможностей
    - Предоставляемые инструменты (полный список)
    - Почему не является дубликатом (конкретное сравнение со встроенными инструментами Claude Code)
    - Релевантность стеку пользователя
    - Уровень (must_have / strong_add / nice_to_have / niche)
    - Ограничения и оговорки
  </section>

  <section name="honorable_mentions">
    Серверы, почти прошедшие отбор, но исключённые, с кратким обоснованием.
  </section>

  <section name="ecosystem_trends">
    Заметные паттерны и формирующиеся категории в экосистеме MCP, которые могут
    породить полезные серверы в ближайшем будущем.
  </section>
</output_format>

<quality_checks>
  <check>Каждый рекомендованный сервер должен быть проверен на существование по указанному URL.</check>
  <check>Каждая команда установки должна быть протестирована или верифицирована из официальной документации.</check>
  <check>Ни один сервер из списка known_dead_ends не появляется в рекомендациях.</check>
  <check>Ни один сервер, требующий платный API-ключ, не появляется в рекомендациях.</check>
  <check>Для каждого сервера есть чёткое объяснение, почему он НЕ является дубликатом встроенных инструментов.</check>
  <check>Отчёт содержит минимум 3 домена помимо «инструментов разработки».</check>
</quality_checks>
</research>
