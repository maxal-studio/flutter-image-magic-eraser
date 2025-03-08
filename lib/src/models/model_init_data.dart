// Data class to pass to isolate
import 'dart:typed_data';

/// Represents the current state of model loading
enum ModelLoadingState {
  /// Model is not loaded
  notLoaded,

  /// Model is currently downloading
  downloading,

  /// Model is currently loading
  loading,

  /// Model has been loaded successfully
  loaded,

  /// Model loading failed
  error
}

/// Structure to hold model data for initialization
class ModelInitData {
  final String modelPath;
  final Uint8List modelBytes;

  ModelInitData(this.modelPath, this.modelBytes);
}

/// Structure to hold download progress information
class DownloadProgress {
  final int downloaded;
  final int total;
  final double progress;

  DownloadProgress({
    required this.downloaded,
    required this.total,
    required this.progress,
  });
}
