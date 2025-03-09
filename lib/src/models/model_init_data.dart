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

  /// Generic error during model loading or downloading
  error,

  /// Error specifically during model download (network/URL issues)
  downloadError,

  /// Error during model loading/initialization
  loadingError,

  /// Error during checksum verification
  checksumError
}

/// Structure to hold detailed information about initialization errors
class ModelInitializationError {
  /// The type of error that occurred
  final ModelLoadingState errorType;

  /// Human-readable error message
  final String message;

  /// The original exception that caused the error
  final dynamic originalError;

  ModelInitializationError({
    required this.errorType,
    required this.message,
    this.originalError,
  });

  @override
  String toString() => 'ModelInitializationError: $message (${errorType.name})';
}

/// Structure to hold file integrity verification data for isolate
class FileIntegrityData {
  final String filePath;
  final String? expectedChecksum;

  FileIntegrityData(this.filePath, this.expectedChecksum);
}

/// Structure to hold minimal information for model loading from file path
class ModelPathData {
  final String modelPath;
  final bool isAsset;

  ModelPathData(this.modelPath, this.isAsset);
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
