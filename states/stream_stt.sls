{# stream-stt: streaming speech-to-text via PipeWire and whisper.cpp (HIPBLAS GPU).
   Installs from local source at ~/src/speech/stream-stt. Requires whisper.cpp build
   with HIPBLAS from ~/src/speech/engines. CLI tool, no systemd service.
#}
{% from '_imports.jinja' import home %}
{% from '_macros_install.jinja' import pip_pkg %}

{{ pip_pkg('stream_stt', pkg=home ~ '/src/speech/stream-stt', bin='stream-stt') }}
