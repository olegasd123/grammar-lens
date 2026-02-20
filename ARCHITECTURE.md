# GrammarLens: Cross-Platform Local AI Grammar Checker

## Context

Build a privacy-first grammar checker (like Grammarly) that runs entirely on-device using local AI models. No server dependency, no subscription fees, full offline support. Target all major platforms: Windows, macOS, Linux, iOS, Android + browser extension.

**Decisions made:**
- **UI**: Flutter (single codebase, all 5 platforms)
- **AI Model**: Fine-tuned Phi-3-mini via llama.cpp (GGUF quantized)
- **Languages**: English, Spanish, French, German, Portuguese
- **Name**: GrammarLens

---

## 1. Monorepo Structure (Melos)

```
grammarlens/
├── melos.yaml
├── pubspec.yaml
├── analysis_options.yaml
├── .gitmodules                          # llama.cpp submodule
│
├── apps/
│   └── grammarlens/                     # Main Flutter app (all platforms)
│       ├── lib/
│       │   ├── main.dart
│       │   ├── app.dart                 # Router, DI, MaterialApp
│       │   ├── di/injection.dart        # GetIt + Injectable setup
│       │   └── features/
│       │       ├── editor/              # Main text editor + corrections
│       │       │   ├── presentation/bloc/editor_bloc.dart
│       │       │   ├── presentation/pages/editor_page.dart
│       │       │   ├── presentation/widgets/{correction_card, diff_text_view, suggestion_panel}.dart
│       │       │   ├── domain/usecases/{analyze_text, apply_correction}.dart
│       │       │   ├── domain/entities/{correction, analysis_result}.dart
│       │       │   └── data/repositories/grammar_repository_impl.dart
│       │       ├── model_manager/       # Download, delete, switch models
│       │       ├── settings/
│       │       └── statistics/          # Writing stats dashboard
│       ├── android/
│       ├── ios/
│       │   └── GrammarLensKeyboard/     # iOS keyboard extension (native Swift)
│       ├── macos/
│       ├── windows/
│       └── linux/
│
├── packages/
│   ├── grammar_engine/                  # Core analysis logic (pure Dart)
│   │   └── lib/src/
│   │       ├── analyzer/{grammar_analyzer, sentence_splitter, correction_parser, prompt_builder}.dart
│   │       ├── models/{correction, correction_type, analysis_result, language}.dart
│   │       ├── language_detection/{language_detector, language_profiles}.dart
│   │       ├── statistics/{readability_scorer, text_statistics}.dart
│   │       └── diff/{text_differ, diff_result}.dart
│   │
│   ├── llama_inference/                 # llama.cpp FFI bindings (Flutter plugin)
│   │   ├── ffigen.yaml
│   │   ├── lib/src/
│   │   │   ├── bindings/llama_bindings.dart     # Auto-generated via ffigen
│   │   │   ├── llama_model.dart                 # Load/unload, mmap
│   │   │   ├── llama_context.dart               # Context management
│   │   │   ├── llama_session.dart               # High-level prompt+generate
│   │   │   ├── isolate_inference.dart           # Runs inference in Dart Isolate
│   │   │   ├── inference_config.dart            # Temperature, top_p, etc.
│   │   │   ├── memory_manager.dart
│   │   │   └── gpu_backend.dart                 # Metal/Vulkan/CUDA detection
│   │   └── native/CMakeLists.txt                # Builds llama.cpp per platform
│   │
│   ├── model_repository/               # Model download, storage, integrity
│   │   └── lib/src/{model_manifest, model_downloader, model_storage, model_integrity, model_registry}.dart
│   │
│   ├── grammarlens_ui/                 # Shared design system
│   │   └── lib/src/
│   │       ├── theme/{app_theme, app_colors, app_typography}.dart
│   │       └── widgets/{correction_highlight, diff_text_span, model_download_tile, language_selector}.dart
│   │
│   └── platform_integration/           # Platform-specific text access
│       ├── lib/src/{platform_text_service, clipboard_service, accessibility_service}.dart
│       ├── android/.../ime/GrammarLensIME.kt
│       ├── ios/Classes/KeyboardExtensionBridge.swift
│       ├── macos/Classes/AccessibilityBridge.swift
│       ├── windows/ui_automation_bridge.cpp
│       └── linux/ibus_bridge.cc
│
├── extensions/
│   └── browser/                         # Chrome/Edge/Firefox extension (TypeScript)
│       ├── manifest.json                # Manifest V3
│       ├── src/
│       │   ├── content/content-script.ts
│       │   ├── background/service-worker.ts
│       │   └── native-host/host.dart    # Compiled Dart native messaging host
│       └── webpack.config.js
│
├── vendor/llama.cpp/                    # Git submodule (pinned)
│
├── models/
│   ├── manifest.json                    # Model catalog (URLs, sizes, hashes)
│   ├── prompts/{grammar_en, grammar_es, grammar_fr, grammar_de, grammar_pt}.txt
│   └── fine_tuning/eval/{benchmark_suite.py, test_cases.jsonl}
│
└── scripts/{build_llama.sh, generate_bindings.sh, package_model.sh, setup_dev.sh}
```

**Package dependency graph:**
```
apps/grammarlens → grammar_engine → llama_inference
                 → model_repository
                 → grammarlens_ui
                 → platform_integration
```

---

## 2. Architecture Pattern: Clean Architecture + BLoC

```
PRESENTATION  →  Flutter Widgets ↔ BLoC/Cubit ↔ Use Cases
DOMAIN        →  Use Cases | Entities | Repository Interfaces (pure Dart)
DATA          →  Repository Impls | LlamaInference | Local Storage
```

**DI**: GetIt + Injectable for service locator pattern.

---

## 3. AI Inference Layer

### llama.cpp via dart:ffi
- Auto-generate FFI bindings with `ffigen` from `llama.h`
- **Never call llama.cpp on the main isolate** — all inference in a dedicated `Dart Isolate`
- `IsolateInference` class: spawns isolate, sends prompts via `SendPort`, streams tokens back
- Model loaded with `mmap` (critical on mobile — OS can page out weights)

### Prompt Format (XML output + GBNF grammar constraint)
```
<|system|> You are a precise {language} grammar checker. Output corrections in XML format...
<|user|> Analyze: """{sentences}"""
<|assistant|>
<corrections>
  <item>
    <original>...</original><corrected>...</corrected>
    <type>grammar|spelling|punctuation|style</type>
    <explanation>...</explanation><offset>N</offset>
  </item>
</corrections>
```
XML chosen over JSON: easier to stream-parse, simpler GBNF grammar, fewer model hallucinations.

### GPU Acceleration
| Platform | Backend | Fallback |
|----------|---------|----------|
| macOS/iOS | Metal | CPU |
| Windows | Vulkan | CUDA → CPU |
| Linux | Vulkan | CUDA → CPU |
| Android | Vulkan | CPU |

### Model Distribution
- Models NOT bundled in app (too large ~2-2.5GB per language)
- Hosted on CDN (Cloudflare R2 or GitHub Releases)
- Chunked download with resume, SHA-256 verification
- Users download only languages they need
- Quantization: Q4_K_M for mobile, Q5_K_M/Q8 for desktop

### Language Detection
- Trigram-based n-gram approach (pure Dart, <1ms, ~50KB profiles)
- No model required — runs before inference to select prompt template

---

## 4. Data Flow

```
User types → Debounce (300ms sentence / 800ms paragraph)
           → Language Detection (<1ms)
           → Sentence Splitting
           → Batch (3 sentences per inference call)
           → Build prompt + GBNF grammar
           → Isolate → llama.cpp inference (streaming tokens)
           → Stream-parse XML → Correction objects
           → Map offsets back to original text
           → Merge with existing corrections (avoid flicker)
           → BLoC state update → UI rebuilds RichText
```

**Streaming strategy**: Corrections appear progressively as each XML `</item>` closes. For a 500-word doc (~25 sentences, 9 batches): first corrections in ~1-2s, full analysis ~10-15s mobile / ~3-5s desktop.

**Cancellation**: `restartable()` BLoC transformer cancels in-flight analysis if user modifies text.

---

## 5. Platform-Specific Integration

### iOS Keyboard Extension
- **Problem**: 40MB memory limit, Flutter can't run in extension
- **Solution**: Thin native Swift keyboard + App Groups IPC to main app
- Main app runs model, keyboard extension reads corrections from shared UserDefaults
- Darwin Notification Center for real-time signaling between processes

### Android Custom Keyboard
- `InputMethodService` runs in app's process — full memory access
- Native Kotlin suggestion bar view (not Flutter)
- Model loaded once, shared between app and IME
- `InputConnection.commitCorrection()` to apply fixes

### macOS Accessibility API
- `AXUIElement` to read/write text in any focused text field
- `AXObserver` for focus change notifications
- Global hotkey (Cmd+Shift+G) to trigger check
- Floating correction overlay

### Windows UI Automation
- `IUIAutomation` COM interface for text field access
- `ITextProvider` / `ITextRangeProvider` for read/write
- Global hotkey + system tray icon
- `SetWinEventHook` for focus tracking

### Browser Extension
- Manifest V3, content script with MutationObserver
- Native messaging host (compiled Dart exe) runs the model
- Extension → Service Worker → Native Host → llama.cpp → corrections back
- Requires desktop app installed (for native host + model files)

---

## 6. Testing Strategy

| Layer | Tool | Location |
|-------|------|----------|
| Unit (grammar_engine) | `flutter_test` + mocks | `packages/grammar_engine/test/` |
| FFI Integration | Real model fixtures | `packages/llama_inference/test/` |
| Widget/BLoC | `bloc_test` + `mocktail` | `apps/grammarlens/test/` |
| Platform Integration | Device/emulator tests | `apps/grammarlens/integration_test/` |
| Model Quality | Python benchmark suite | `models/fine_tuning/eval/` |

**Model quality targets**: Precision >0.90, Recall >0.80, Latency p95 <2s per sentence on Pixel 7/iPhone 14.

---

## 7. CI/CD (GitHub Actions)

- **ci.yml**: Lint + test on every PR (`melos analyze && melos test`)
- **build_{platform}.yml**: Platform-specific builds (android, ios, macos, windows, linux, extension)
- **model_benchmark.yml**: Weekly model quality regression tests on GPU runner
- **Release**: Fastlane for iOS/Android stores, notarytool for macOS, MSIX for Windows, AppImage/.deb for Linux

---

## 8. Implementation Phases

### Phase 1: MVP (Weeks 1-8)
| Week | Deliverable |
|------|------------|
| 1-2 | Monorepo setup, llama.cpp submodule, FFI bindings, basic model load/unload on macOS |
| 3-4 | `grammar_engine`: sentence splitter, prompt builder, correction parser, English prompt |
| 5-6 | Flutter app: Editor page, EditorBloc with debounce, DiffTextView, Model Manager UI |
| 7 | Browser extension: content script, service worker, native messaging host |
| 8 | Android + iOS builds, GPU acceleration (Metal/Vulkan), beta release |

### Phase 2: System Integration (Weeks 9-16)
| Week | Deliverable |
|------|------------|
| 9-10 | macOS Accessibility API + floating overlay |
| 11-12 | Windows UI Automation + system tray |
| 13-14 | Android custom keyboard (InputMethodService) |
| 15-16 | Multi-language support (ES, FR, DE, PT), language detection, fine-tuning pipeline |

### Phase 3: Full Platform Coverage (Weeks 17-24)
| Week | Deliverable |
|------|------------|
| 17-18 | iOS keyboard extension (Swift, App Groups IPC) |
| 19-20 | Linux IBus IME integration |
| 21-22 | Desktop IME integration (macOS Input Sources, Windows TSF) |
| 23-24 | Performance optimization, model quality improvements, app store submissions |
