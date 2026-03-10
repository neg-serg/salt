"""ctypes bindings to libwhisper.so for HIPBLAS-accelerated inference."""

import ctypes
import ctypes.util
from pathlib import Path
from typing import Optional

# --- C type aliases ---
c_whisper_context_p = ctypes.c_void_p
c_whisper_state_p = ctypes.c_void_p


class WhisperContextParams(ctypes.Structure):
    _fields_ = [
        ("use_gpu", ctypes.c_bool),
        ("flash_attn", ctypes.c_bool),
        ("gpu_device", ctypes.c_int),
        ("dtw_token_timestamps", ctypes.c_bool),
        ("dtw_aheads_preset", ctypes.c_int),
        ("dtw_n_top", ctypes.c_int),
        # whisper_aheads struct (n_heads + pointer)
        ("dtw_aheads_n_heads", ctypes.c_size_t),
        ("dtw_aheads_heads", ctypes.c_void_p),
        ("dtw_mem_size", ctypes.c_size_t),
    ]


class WhisperVadParams(ctypes.Structure):
    _fields_ = [
        ("threshold", ctypes.c_float),
        ("min_speech_duration_ms", ctypes.c_int),
        ("min_silence_duration_ms", ctypes.c_int),
        ("max_speech_duration_s", ctypes.c_float),
        ("speech_pad_ms", ctypes.c_int),
        ("samples_overlap", ctypes.c_float),
    ]


# Callback types
WHISPER_NEW_SEGMENT_CALLBACK = ctypes.CFUNCTYPE(
    None, c_whisper_context_p, c_whisper_state_p, ctypes.c_int, ctypes.c_void_p
)
WHISPER_PROGRESS_CALLBACK = ctypes.CFUNCTYPE(
    None, c_whisper_context_p, c_whisper_state_p, ctypes.c_int, ctypes.c_void_p
)
WHISPER_ENCODER_BEGIN_CALLBACK = ctypes.CFUNCTYPE(
    ctypes.c_bool, c_whisper_context_p, c_whisper_state_p, ctypes.c_void_p
)


class WhisperFullParams(ctypes.Structure):
    """Maps to struct whisper_full_params from whisper.h."""

    _fields_ = [
        ("strategy", ctypes.c_int),
        ("n_threads", ctypes.c_int),
        ("n_max_text_ctx", ctypes.c_int),
        ("offset_ms", ctypes.c_int),
        ("duration_ms", ctypes.c_int),
        ("translate", ctypes.c_bool),
        ("no_context", ctypes.c_bool),
        ("no_timestamps", ctypes.c_bool),
        ("single_segment", ctypes.c_bool),
        ("print_special", ctypes.c_bool),
        ("print_progress", ctypes.c_bool),
        ("print_realtime", ctypes.c_bool),
        ("print_timestamps", ctypes.c_bool),
        ("token_timestamps", ctypes.c_bool),
        ("thold_pt", ctypes.c_float),
        ("thold_ptsum", ctypes.c_float),
        ("max_len", ctypes.c_int),
        ("split_on_word", ctypes.c_bool),
        ("max_tokens", ctypes.c_int),
        ("debug_mode", ctypes.c_bool),
        ("audio_ctx", ctypes.c_int),
        ("tdrz_enable", ctypes.c_bool),
        ("suppress_regex", ctypes.c_char_p),
        ("initial_prompt", ctypes.c_char_p),
        ("carry_initial_prompt", ctypes.c_bool),
        ("prompt_tokens", ctypes.c_void_p),
        ("prompt_n_tokens", ctypes.c_int),
        ("language", ctypes.c_char_p),
        ("detect_language", ctypes.c_bool),
        ("suppress_blank", ctypes.c_bool),
        ("suppress_nst", ctypes.c_bool),
        ("temperature", ctypes.c_float),
        ("max_initial_ts", ctypes.c_float),
        ("length_penalty", ctypes.c_float),
        ("temperature_inc", ctypes.c_float),
        ("entropy_thold", ctypes.c_float),
        ("logprob_thold", ctypes.c_float),
        ("no_speech_thold", ctypes.c_float),
        # greedy
        ("greedy_best_of", ctypes.c_int),
        # beam_search
        ("beam_search_beam_size", ctypes.c_int),
        ("beam_search_patience", ctypes.c_float),
        # callbacks
        ("new_segment_callback", WHISPER_NEW_SEGMENT_CALLBACK),
        ("new_segment_callback_user_data", ctypes.c_void_p),
        ("progress_callback", WHISPER_PROGRESS_CALLBACK),
        ("progress_callback_user_data", ctypes.c_void_p),
        ("encoder_begin_callback", WHISPER_ENCODER_BEGIN_CALLBACK),
        ("encoder_begin_callback_user_data", ctypes.c_void_p),
        ("abort_callback", ctypes.c_void_p),
        ("abort_callback_user_data", ctypes.c_void_p),
        ("logits_filter_callback", ctypes.c_void_p),
        ("logits_filter_callback_user_data", ctypes.c_void_p),
        # grammar
        ("grammar_rules", ctypes.c_void_p),
        ("n_grammar_rules", ctypes.c_size_t),
        ("i_start_rule", ctypes.c_size_t),
        ("grammar_penalty", ctypes.c_float),
        # VAD
        ("vad", ctypes.c_bool),
        ("vad_model_path", ctypes.c_char_p),
        ("vad_params", WhisperVadParams),
    ]


# Sampling strategies
WHISPER_SAMPLING_GREEDY = 0
WHISPER_SAMPLING_BEAM_SEARCH = 1

# --- Library discovery ---

_SPEECH_ENGINES = Path.home() / "src" / "1st-level" / "@rag" / "speech-engines"

_LIBWHISPER_SEARCH_PATHS = [
    _SPEECH_ENGINES / "whisper.cpp" / "build" / "src" / "libwhisper.so",
    _SPEECH_ENGINES / "whisper.cpp" / "build" / "src" / "libwhisper.so.1",
    _SPEECH_ENGINES / "whisper.cpp" / "build" / "src" / "libwhisper.so.1.8.3",
]

_MODEL_SEARCH_PATHS = [
    _SPEECH_ENGINES / "voices" / "ggml-large-v3-turbo.bin",
]

_VAD_MODEL_SEARCH_PATHS = [
    _SPEECH_ENGINES / "whisper.cpp" / "models" / "for-tests-silero-v6.2.0-ggml.bin",
]


def find_libwhisper() -> str:
    """Find libwhisper.so, searching build paths and system."""
    for p in _LIBWHISPER_SEARCH_PATHS:
        if p.exists():
            return str(p)
    # Fall back to system search
    found = ctypes.util.find_library("whisper")
    if found:
        return found
    raise FileNotFoundError(
        "libwhisper.so not found. Expected at: " + str(_LIBWHISPER_SEARCH_PATHS[0])
    )


def find_model(model_path: Optional[str] = None) -> str:
    """Find whisper model file. Uses explicit path or auto-detects."""
    if model_path:
        p = Path(model_path)
        if p.exists():
            return str(p)
        raise FileNotFoundError(f"Model not found: {model_path}")
    for p in _MODEL_SEARCH_PATHS:
        if p.exists():
            return str(p)
    raise FileNotFoundError("Whisper model not found. Expected at: " + str(_MODEL_SEARCH_PATHS[0]))


def find_vad_model() -> Optional[str]:
    """Find Silero VAD model file, or return None."""
    for p in _VAD_MODEL_SEARCH_PATHS:
        if p.exists():
            return str(p)
    return None


def _load_library() -> ctypes.CDLL:
    """Load libwhisper.so and set up function signatures."""
    path = find_libwhisper()
    lib = ctypes.CDLL(path)

    # whisper_context_default_params
    lib.whisper_context_default_params.restype = WhisperContextParams
    lib.whisper_context_default_params.argtypes = []

    # whisper_init_from_file_with_params
    lib.whisper_init_from_file_with_params.restype = c_whisper_context_p
    lib.whisper_init_from_file_with_params.argtypes = [ctypes.c_char_p, WhisperContextParams]

    # whisper_free
    lib.whisper_free.restype = None
    lib.whisper_free.argtypes = [c_whisper_context_p]

    # whisper_full_default_params
    lib.whisper_full_default_params.restype = WhisperFullParams
    lib.whisper_full_default_params.argtypes = [ctypes.c_int]

    # whisper_full
    lib.whisper_full.restype = ctypes.c_int
    lib.whisper_full.argtypes = [
        c_whisper_context_p,
        WhisperFullParams,
        ctypes.POINTER(ctypes.c_float),
        ctypes.c_int,
    ]

    # whisper_full_n_segments
    lib.whisper_full_n_segments.restype = ctypes.c_int
    lib.whisper_full_n_segments.argtypes = [c_whisper_context_p]

    # whisper_full_get_segment_text
    lib.whisper_full_get_segment_text.restype = ctypes.c_char_p
    lib.whisper_full_get_segment_text.argtypes = [c_whisper_context_p, ctypes.c_int]

    # whisper_full_get_segment_t0 / t1
    lib.whisper_full_get_segment_t0.restype = ctypes.c_int64
    lib.whisper_full_get_segment_t0.argtypes = [c_whisper_context_p, ctypes.c_int]
    lib.whisper_full_get_segment_t1.restype = ctypes.c_int64
    lib.whisper_full_get_segment_t1.argtypes = [c_whisper_context_p, ctypes.c_int]

    # whisper_full_lang_id
    lib.whisper_full_lang_id.restype = ctypes.c_int
    lib.whisper_full_lang_id.argtypes = [c_whisper_context_p]

    # whisper_lang_str
    lib.whisper_lang_str.restype = ctypes.c_char_p
    lib.whisper_lang_str.argtypes = [ctypes.c_int]

    # whisper_full_n_tokens
    lib.whisper_full_n_tokens.restype = ctypes.c_int
    lib.whisper_full_n_tokens.argtypes = [c_whisper_context_p, ctypes.c_int]

    # whisper_full_get_token_id
    lib.whisper_full_get_token_id.restype = ctypes.c_int32
    lib.whisper_full_get_token_id.argtypes = [c_whisper_context_p, ctypes.c_int, ctypes.c_int]

    # whisper_full_get_token_p
    lib.whisper_full_get_token_p.restype = ctypes.c_float
    lib.whisper_full_get_token_p.argtypes = [c_whisper_context_p, ctypes.c_int, ctypes.c_int]

    # whisper_vad_default_params
    lib.whisper_vad_default_params.restype = WhisperVadParams
    lib.whisper_vad_default_params.argtypes = []

    # whisper_print_timings
    lib.whisper_print_timings.restype = None
    lib.whisper_print_timings.argtypes = [c_whisper_context_p]

    # whisper_is_multilingual
    lib.whisper_is_multilingual.restype = ctypes.c_int
    lib.whisper_is_multilingual.argtypes = [c_whisper_context_p]

    # Log suppression
    GGML_LOG_CALLBACK = ctypes.CFUNCTYPE(None, ctypes.c_int, ctypes.c_char_p, ctypes.c_void_p)
    lib.whisper_log_set.restype = None
    lib.whisper_log_set.argtypes = [GGML_LOG_CALLBACK, ctypes.c_void_p]

    return lib


# Singleton library handle
_lib: Optional[ctypes.CDLL] = None


def get_lib() -> ctypes.CDLL:
    """Get or load the whisper shared library."""
    global _lib
    if _lib is None:
        _lib = _load_library()
    return _lib


class WhisperContext:
    """High-level wrapper around whisper context for streaming inference."""

    def __init__(
        self,
        model_path: Optional[str] = None,
        use_gpu: bool = True,
        flash_attn: bool = True,
    ):
        self._lib = get_lib()
        self._model_path = find_model(model_path)
        self._vad_model_path = find_vad_model()

        cparams = self._lib.whisper_context_default_params()
        cparams.use_gpu = use_gpu
        cparams.flash_attn = flash_attn

        self._ctx = self._lib.whisper_init_from_file_with_params(self._model_path.encode(), cparams)
        if not self._ctx:
            raise RuntimeError(f"Failed to load whisper model: {self._model_path}")

    def transcribe(
        self,
        samples,
        language: str = "auto",
        n_threads: int = 4,
        no_context: bool = True,
        single_segment: bool = True,
        max_tokens: int = 0,
        use_vad: bool = False,
        vad_threshold: float = 0.6,
        new_segment_callback=None,
        callback_user_data=None,
    ) -> list[dict]:
        """Run whisper inference on float32 PCM samples.

        Returns list of segments: [{text, t0, t1, lang, no_speech_prob}]
        """
        import numpy as np

        params = self._lib.whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.n_threads = n_threads
        params.print_progress = False
        params.print_special = False
        params.print_realtime = False
        params.print_timestamps = False
        params.no_timestamps = True
        params.single_segment = single_segment
        params.max_tokens = max_tokens
        params.no_context = no_context

        if language == "auto":
            params.language = b"auto"
            params.detect_language = True
        else:
            params.language = language.encode()
            params.detect_language = False

        # VAD settings
        if use_vad and self._vad_model_path:
            params.vad = True
            params.vad_model_path = self._vad_model_path.encode()
            params.vad_params.threshold = vad_threshold

        # Callbacks
        if new_segment_callback:
            params.new_segment_callback = new_segment_callback
            if callback_user_data is not None:
                params.new_segment_callback_user_data = callback_user_data

        # Run inference
        data = samples.astype(np.float32)
        data_ptr = data.ctypes.data_as(ctypes.POINTER(ctypes.c_float))

        ret = self._lib.whisper_full(self._ctx, params, data_ptr, len(data))
        if ret != 0:
            raise RuntimeError(f"whisper_full() failed with code {ret}")

        # Collect results
        n_segments = self._lib.whisper_full_n_segments(self._ctx)
        lang_id = self._lib.whisper_full_lang_id(self._ctx)
        lang_str_ptr = self._lib.whisper_lang_str(lang_id)
        lang = lang_str_ptr.decode() if lang_str_ptr else "unknown"

        results = []
        for i in range(n_segments):
            text_ptr = self._lib.whisper_full_get_segment_text(self._ctx, i)
            text = text_ptr.decode("utf-8") if text_ptr else ""
            text = text.strip()
            if not text:
                continue
            t0 = self._lib.whisper_full_get_segment_t0(self._ctx, i)
            t1 = self._lib.whisper_full_get_segment_t1(self._ctx, i)
            results.append(
                {
                    "text": text,
                    "t0": t0,
                    "t1": t1,
                    "lang": lang,
                }
            )

        return results

    def close(self) -> None:
        if self._ctx:
            self._lib.whisper_free(self._ctx)
            self._ctx = None

    def __del__(self):
        self.close()

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()


def suppress_whisper_logs() -> None:
    """Suppress ggml/whisper log output to stderr."""
    lib = get_lib()

    @ctypes.CFUNCTYPE(None, ctypes.c_int, ctypes.c_char_p, ctypes.c_void_p)
    def _noop_log(level, text, user_data):
        pass

    # Keep reference to prevent GC
    suppress_whisper_logs._callback = _noop_log
    lib.whisper_log_set(_noop_log, None)
