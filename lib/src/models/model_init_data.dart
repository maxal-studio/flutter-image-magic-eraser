// Data class to pass to isolate
import 'dart:typed_data';

/// Represents the current state of model loading
enum ModelLoadingState {
  /// Model is not loaded
  notLoaded,

  /// Model is currently loading
  loading,

  /// Model has been loaded successfully
  loaded,

  /// Model loading failed
  error
}

class ModelInitData {
  final String modelPath;
  final Uint8List modelBytes;

  ModelInitData(this.modelPath, this.modelBytes);
}
