import 'dart:async';
import 'dart:isolate';

import 'package:logging/logging.dart';

import 'package:llama_inference/src/bindings/llama_bindings.dart';
import 'package:llama_inference/src/gpu_backend.dart';
import 'package:llama_inference/src/inference_config.dart';
import 'package:llama_inference/src/inference_result.dart';
import 'package:llama_inference/src/llama_context.dart';
import 'package:llama_inference/src/llama_model.dart';

final _log = Logger('IsolateInference');

/// Runs llama.cpp inference in a separate Dart Isolate.
///
/// This is the recommended way to use the inference engine in Flutter.
/// All model loading and inference happens off the main isolate,
/// ensuring the UI remains responsive.
///
/// Usage:
/// ```dart
/// final engine = IsolateInference();
/// await engine.initialize(
///   modelPath: '/path/to/model.gguf',
/// );
///
/// // Batch completion
/// final result = await engine.complete('prompt text');
///
/// // Streaming completion
/// await for (final token in engine.completeStream('prompt text')) {
///   print(token.text);
/// }
///
/// engine.dispose();
/// ```
class IsolateInference {
  Isolate? _isolate;
  SendPort? _commandPort;
  final _responseController = StreamController<_IsolateMessage>.broadcast();
  bool _isInitialized = false;

  /// Whether the inference engine is ready.
  bool get isInitialized => _isInitialized;

  /// Initialize the inference engine by spawning a worker isolate
  /// and loading the model.
  ///
  /// This may take several seconds for large models.
  Future<void> initialize({
    required String modelPath,
    int contextSize = 2048,
    int gpuLayers = 99,
    GpuBackend? gpuBackend,
  }) async {
    if (_isInitialized) {
      throw StateError('IsolateInference is already initialized');
    }

    _log.info('Initializing isolate inference engine');

    final receivePort = ReceivePort();

    _isolate = await Isolate.spawn(
      _isolateEntryPoint,
      _InitMessage(
        sendPort: receivePort.sendPort,
        modelPath: modelPath,
        contextSize: contextSize,
        gpuLayers: gpuLayers,
        gpuBackend: gpuBackend ?? GpuBackendDetector.detect(),
      ),
    );

    // Wait for the isolate to send back its command port
    final completer = Completer<SendPort>();

    receivePort.listen((message) {
      if (message is SendPort && !completer.isCompleted) {
        completer.complete(message);
      } else if (message is _IsolateMessage) {
        _responseController.add(message);
      }
    });

    _commandPort = await completer.future;
    _isInitialized = true;

    _log.info('Isolate inference engine initialized');
  }

  /// Run a complete inference and return the full result.
  Future<InferenceResult> complete(
    String prompt, {
    InferenceConfig config = const InferenceConfig.grammar(),
  }) async {
    _assertInitialized();

    final requestId = DateTime.now().microsecondsSinceEpoch;
    final completer = Completer<InferenceResult>();

    late final StreamSubscription<_IsolateMessage> sub;
    sub = _responseController.stream
        .where((msg) => msg.requestId == requestId)
        .listen((msg) {
      if (msg is _CompletionResult) {
        completer.complete(msg.result);
        sub.cancel();
      } else if (msg is _ErrorResult) {
        completer.completeError(
          InferenceException(msg.error),
        );
        sub.cancel();
      }
    });

    _commandPort!.send(_CompleteRequest(
      requestId: requestId,
      prompt: prompt,
      config: config,
    ));

    return completer.future;
  }

  /// Run a streaming inference, yielding tokens progressively.
  Stream<StreamedToken> completeStream(
    String prompt, {
    InferenceConfig config = const InferenceConfig.grammar(),
  }) {
    _assertInitialized();

    final requestId = DateTime.now().microsecondsSinceEpoch;
    final controller = StreamController<StreamedToken>();

    final sub = _responseController.stream
        .where((msg) => msg.requestId == requestId)
        .listen((msg) {
      if (msg is _TokenResult) {
        controller.add(msg.token);
        if (msg.token.isLast) {
          controller.close();
        }
      } else if (msg is _ErrorResult) {
        controller.addError(InferenceException(msg.error));
        controller.close();
      }
    });

    controller.onCancel = () {
      sub.cancel();
      // Send cancel signal to isolate
      _commandPort!.send(_CancelRequest(requestId: requestId));
    };

    _commandPort!.send(_StreamRequest(
      requestId: requestId,
      prompt: prompt,
      config: config,
    ));

    return controller.stream;
  }

  /// Shut down the inference isolate and release resources.
  void dispose() {
    _log.info('Disposing isolate inference engine');

    _commandPort?.send(const _ShutdownRequest());
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _commandPort = null;
    _isInitialized = false;
    _responseController.close();
  }

  void _assertInitialized() {
    if (!_isInitialized) {
      throw StateError('IsolateInference is not initialized. Call initialize() first.');
    }
  }
}

// ── Isolate Entry Point ──────────────────────────────────────────────────────

/// Entry point for the worker isolate.
///
/// Loads the model and processes inference requests in a loop.
Future<void> _isolateEntryPoint(_InitMessage init) async {
  final commandPort = ReceivePort();

  // Send our command port back to the main isolate
  init.sendPort.send(commandPort.sendPort);

  _log.info(
    'Worker isolate started. Loading model: ${init.modelPath}',
  );

  // Initialize backend and load model
  final bindings = LlamaBindings.instance;
  bindings.backendInit();

  late final LlamaModel model;
  late final LlamaContext context;

  try {
    model = await LlamaModel.load(
      init.modelPath,
      gpuLayers: init.gpuLayers,
      gpuBackend: init.gpuBackend,
    );
    context = LlamaContext.create(
      model,
      contextSize: init.contextSize,
    );
  } catch (e) {
    _log.severe('Failed to initialize model: $e');
    init.sendPort.send(_ErrorResult(requestId: 0, error: e.toString()));
    bindings.backendFree();
    return;
  }

  // Process requests
  await for (final message in commandPort) {
    if (message is _CompleteRequest) {
      try {
        context.reset();
        final result = await context.complete(
          message.prompt,
          config: message.config,
        );
        init.sendPort.send(_CompletionResult(
          requestId: message.requestId,
          result: result,
        ));
      } catch (e) {
        init.sendPort.send(_ErrorResult(
          requestId: message.requestId,
          error: e.toString(),
        ));
      }
    } else if (message is _StreamRequest) {
      try {
        context.reset();
        await for (final token in context.completeStream(
          message.prompt,
          config: message.config,
        )) {
          init.sendPort.send(_TokenResult(
            requestId: message.requestId,
            token: token,
          ));
        }
      } catch (e) {
        init.sendPort.send(_ErrorResult(
          requestId: message.requestId,
          error: e.toString(),
        ));
      }
    } else if (message is _CancelRequest) {
      _log.fine('Cancel request received for ${message.requestId}');
    } else if (message is _ShutdownRequest) {
      context.dispose();
      model.dispose();
      bindings.backendFree();
      _log.info('Worker isolate shutting down');
      break;
    }
  }
}

// ── Message Types ────────────────────────────────────────────────────────────

class _InitMessage {
  final SendPort sendPort;
  final String modelPath;
  final int contextSize;
  final int gpuLayers;
  final GpuBackend gpuBackend;

  const _InitMessage({
    required this.sendPort,
    required this.modelPath,
    required this.contextSize,
    required this.gpuLayers,
    required this.gpuBackend,
  });
}

abstract class _IsolateMessage {
  int get requestId;
}

class _CompleteRequest {
  final int requestId;
  final String prompt;
  final InferenceConfig config;

  const _CompleteRequest({
    required this.requestId,
    required this.prompt,
    required this.config,
  });
}

class _StreamRequest {
  final int requestId;
  final String prompt;
  final InferenceConfig config;

  const _StreamRequest({
    required this.requestId,
    required this.prompt,
    required this.config,
  });
}

class _CancelRequest {
  final int requestId;
  const _CancelRequest({required this.requestId});
}

class _ShutdownRequest {
  const _ShutdownRequest();
}

class _CompletionResult implements _IsolateMessage {
  @override
  final int requestId;
  final InferenceResult result;

  const _CompletionResult({
    required this.requestId,
    required this.result,
  });
}

class _TokenResult implements _IsolateMessage {
  @override
  final int requestId;
  final StreamedToken token;

  const _TokenResult({
    required this.requestId,
    required this.token,
  });
}

class _ErrorResult implements _IsolateMessage {
  @override
  final int requestId;
  final String error;

  const _ErrorResult({
    required this.requestId,
    required this.error,
  });
}

/// Exception thrown during inference.
class InferenceException implements Exception {
  final String message;
  const InferenceException(this.message);

  @override
  String toString() => 'InferenceException: $message';
}
