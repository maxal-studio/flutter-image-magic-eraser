import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

import '../models/model_init_data.dart';

/// Service for handling ONNX model operations
class OnnxModelService {
  OnnxModelService._internal();

  static final OnnxModelService _instance = OnnxModelService._internal();

  /// Returns the singleton instance of the service
  static OnnxModelService get instance => _instance;

  /// The ONNX session used for inference
  OrtSession? _session;

  /// Stream controller for broadcasting model loading state changes
  final _stateController = StreamController<ModelLoadingState>.broadcast();

  /// Current state of model loading
  ModelLoadingState _currentState = ModelLoadingState.notLoaded;

  /// Stream of model loading state changes
  Stream<ModelLoadingState> get stateStream => _stateController.stream;

  /// Current state of model loading
  ModelLoadingState get currentState => _currentState;

  /// Updates the current state and broadcasts it to listeners
  void _setState(ModelLoadingState newState) {
    _currentState = newState;
    _stateController.add(newState);
  }

  /// Initializes the ONNX environment and creates a session
  ///
  /// This method should be called once before using the model for inference
  /// It runs in an isolate to prevent UI freezing
  Future<void> initializeModel(String modelPath) async {
    try {
      _setState(ModelLoadingState.loading);

      // Load the model bytes in the main isolate
      final rawAssetFile = await rootBundle.load(modelPath);
      final bytes = rawAssetFile.buffer.asUint8List();

      // Initialize the ONNX runtime environment in the main isolate
      // This is required before creating a session
      OrtEnv.instance.init();

      // Create the session in a separate isolate
      final session =
          await compute(_createSession, ModelInitData(modelPath, bytes));

      // The session will not be null as the _createSession method will throw an exception if it fails
      _session = session;

      _setState(ModelLoadingState.loaded);

      if (kDebugMode) {
        log('ONNX session created successfully in isolate.',
            name: "OnnxModelService");
      }
    } catch (e) {
      _setState(ModelLoadingState.error);
      if (kDebugMode) {
        log('Error initializing ONNX model: $e',
            name: "OnnxModelService", error: e);
      }
      rethrow;
    }
  }

  /// Static method to create an ONNX session in an isolate
  static Future<OrtSession> _createSession(ModelInitData data) async {
    try {
      // Initialize ORT environment in the isolate
      OrtEnv.instance.init();

      // Create session options
      final sessionOptions = OrtSessionOptions();

      // Create the session from the model bytes
      final session = OrtSession.fromBuffer(data.modelBytes, sessionOptions);

      return session;
    } catch (e) {
      if (kDebugMode) {
        log('Error creating ONNX session in isolate: $e');
      }
      throw Exception('Error creating ONNX session in isolate: $e');
    }
  }

  /// Runs inference on the model with the given inputs
  ///
  /// [inputs] is a map of input names to OrtValueTensor objects
  /// Returns a list of output values
  Future<List<OrtValue?>?> runInference(Map<String, OrtValue> inputs) async {
    if (_session == null) {
      throw Exception("ONNX session not initialized");
    }

    OrtRunOptions? runOptions;
    List<OrtValue?>? outputs;

    try {
      runOptions = OrtRunOptions();
      outputs = await _session!.runAsync(runOptions, inputs);
      return outputs;
    } catch (e) {
      if (kDebugMode) {
        log('Error running inference: $e', name: "OnnxModelService", error: e);
      }
      rethrow;
    } finally {
      // Always release run options
      runOptions?.release();
    }
  }

  /// Checks if the model is loaded
  bool isModelLoaded() {
    return _session != null;
  }

  /// Disposes of resources when the service is no longer needed
  void dispose() {
    if (_session != null) {
      _session!.release();
      _session = null;
      _setState(ModelLoadingState.notLoaded);
      if (kDebugMode) {
        log('ONNX session released.', name: "OnnxModelService");
      }
    }
    _stateController.close();
  }
}
