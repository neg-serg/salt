{% from '_imports.jinja' import host %}
{% from '_macros_pkg.jinja' import pacman_install %}
{% from '_macros_install.jinja' import curl_extract_tar %}
{% import_yaml 'data/versions.yaml' as ver %}
{% import_yaml 'data/installers.yaml' as tools %}

{% if not host.features.get('music_analysis') %}
music_analysis_feature_disabled:
  test.nop:
    - comment: music_analysis feature disabled for this host
{% else %}
# Python dependencies for Annoy-based analysis scripts
{{ pacman_install('music_analysis_python', 'python-annoy python-orjson python-numpy') }}

# Essentia streaming extractor (binary tarball)
{% set tar_defs = tools.get('curl_extract_tar', {}) %}
{% set essentia = tar_defs.get('essentia') %}
{% if essentia %}
{% set _ver = ver.get('essentia', '') %}
{% set resolved_url = essentia.url | replace('${VER}', _ver) %}
{{ curl_extract_tar('essentia', resolved_url, binary_pattern=essentia.binary_pattern, bin=essentia.get('bin'), hash=essentia.get('hash'), version=_ver if _ver else None) }}
{% endif %}
{% endif %}
