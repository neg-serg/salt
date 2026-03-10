{# stream-stt: streaming speech-to-text via PipeWire and whisper.cpp (HIPBLAS GPU).
   Installs from local source at ~/src/salt/stream-stt. Requires whisper.cpp build
   with HIPBLAS from speech-engines (feature 3 in @rag). CLI tool, no systemd service.
#}
{% from '_imports.jinja' import home %}
{% from '_macros_install.jinja' import pip_pkg %}

{{ pip_pkg('stream_stt', pkg=home ~ '/src/salt/stream-stt', bin='stream-stt') }}
