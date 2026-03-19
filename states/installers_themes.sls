{% from '_imports.jinja' import home, user %}
{% from '_macros_install.jinja' import git_clone_deploy %}
{% import_yaml 'data/installers_themes.yaml' as themes %}
# Theme and icon installers (data-driven from data/installers_themes.yaml)

{% for name, cfg in themes.git_clone_deploy.items() %}
{{ git_clone_deploy(name, cfg.repo, cfg.dest, cfg.get('items'), creates=(home ~ cfg.creates) if cfg.get('creates') else None, user=user, home=home) }}

{% endfor %}
