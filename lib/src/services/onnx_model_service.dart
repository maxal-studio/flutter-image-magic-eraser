import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

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

  /// Stream controller for broadcasting download progress
  final _downloadProgressController =
      StreamController<DownloadProgress>.broadcast();

  /// Stream of download progress updates
  Stream<DownloadProgress> get downloadProgressStream =>
      _downloadProgressController.stream;

  /// Directory where downloaded models are stored
  String? _modelStorageDirectory;

  /// Get the directory where models are stored
  Future<String> get _modelDir async {
    if (_modelStorageDirectory != null) return _modelStorageDirectory!;

    final appDir = await getApplicationDocumentsDirectory();
    _modelStorageDirectory = '${appDir.path}/models';

    // Create the directory if it doesn't exist
    final directory = Directory(_modelStorageDirectory!);
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }

    return _modelStorageDirectory!;
  }

  /// Updates the current state and broadcasts it to listeners
  void _setState(ModelLoadingState newState) {
    _currentState = newState;
    _stateController.add(newState);
  }

  /// Initializes the ONNX environment and creates a session from a URL
  ///
  /// Downloads the model if it doesn't exist locally, then initializes it
  /// Provides progress updates via the downloadProgressStream
  ///
  /// - [modelUrl]: URL to download the model from
  /// - [expectedChecksum]: SHA-256 checksum to verify the downloaded file integrity.
  ///   This is required for security and integrity verification.
  Future<void> initializeModelFromUrl(
    String modelUrl,
    String expectedChecksum,
  ) async {
    try {
      // Use the checksum as the filename for better identification and verification
      final modelPath =
          await _ensureModelDownloaded(modelUrl, expectedChecksum);

      // Now initialize from the local file
      await initializeModel(modelPath, isAsset: false);

      if (kDebugMode) {
        log('Model initialized from URL successfully',
            name: "OnnxModelService");
      }
    } catch (e) {
      // The specific error state is already set by the method that threw the exception
      if (kDebugMode) {
        log('Error initializing model from URL: $e',
            name: "OnnxModelService", error: e);
      }
      rethrow;
    }
  }

  /// Static method for calculating file checksum in an isolate
  static Future<String> _calculateChecksumInIsolate(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $filePath');
    }

    final fileBytes = await file.readAsBytes();
    final digest = sha256.convert(fileBytes);
    return digest.toString();
  }

  /// Static method for verifying file integrity in an isolate
  static Future<bool> _verifyFileIntegrityInIsolate(
      FileIntegrityData data) async {
    // If no checksum is provided, assume file is valid
    if (data.expectedChecksum == null) {
      return true;
    }

    try {
      final actualChecksum = await _calculateChecksumInIsolate(data.filePath);
      return actualChecksum.toLowerCase() ==
          data.expectedChecksum!.toLowerCase();
    } catch (e) {
      // Return false on any error
      return false;
    }
  }

  /// Verifies if a file's checksum matches the expected value
  Future<bool> _verifyFileIntegrity(
      String filePath, String? expectedChecksum) async {
    // If no checksum is provided, assume file is valid
    if (expectedChecksum == null) {
      if (kDebugMode) {
        log('No checksum provided for verification, assuming file is valid: $filePath',
            name: "OnnxModelService");
      }
      return true;
    }

    try {
      if (kDebugMode) {
        log('Starting checksum verification for: $filePath',
            name: "OnnxModelService");
      }

      // Run the verification in a background isolate
      final isValid = await compute(_verifyFileIntegrityInIsolate,
          FileIntegrityData(filePath, expectedChecksum));

      if (kDebugMode) {
        if (isValid) {
          log('Checksum verification successful: $filePath',
              name: "OnnxModelService");
        } else {
          log('Checksum verification failed: $filePath',
              name: "OnnxModelService");
          log('Expected: $expectedChecksum', name: "OnnxModelService");
        }
      }

      return isValid;
    } catch (e) {
      if (kDebugMode) {
        log('Error verifying file integrity: $e',
            name: "OnnxModelService", error: e);
      }
      return false;
    }
  }

  /// Checks if the model exists locally, downloads if needed
  Future<String> _ensureModelDownloaded(String url, String checksum) async {
    final modelDir = await _modelDir;
    // Use checksum as the filename with a .onnx extension
    final file = File('$modelDir/$checksum.onnx');

    // Check if the file already exists
    if (await file.exists()) {
      // Verify file integrity with checksum
      final isValid = await _verifyFileIntegrity(file.path, checksum);

      if (!isValid) {
        if (kDebugMode) {
          log('Existing model file is corrupted, re-downloading: ${file.path}',
              name: "OnnxModelService");
        }

        // Delete corrupted file and download again
        await file.delete();
        _setState(ModelLoadingState.downloading);

        try {
          await _downloadModel(url, file.path);

          // Only verify integrity if download succeeded
          final isNewFileValid =
              await _verifyFileIntegrity(file.path, checksum);
          if (!isNewFileValid) {
            _setState(ModelLoadingState.checksumError);
            throw Exception(
                'Downloaded model file failed integrity check. Expected checksum: $checksum');
          }
        } catch (e) {
          // Set download error state and rethrow
          _setState(ModelLoadingState.downloadError);
          rethrow;
        }
      } else {
        if (kDebugMode) {
          log('Model already downloaded and verified: ${file.path}',
              name: "OnnxModelService");
        }
      }
      return file.path;
    }

    // File doesn't exist, download it
    _setState(ModelLoadingState.downloading);
    try {
      await _downloadModel(url, file.path);

      // Only verify downloaded file integrity after successful download
      final isValid = await _verifyFileIntegrity(file.path, checksum);
      if (!isValid) {
        // Clean up invalid file
        await file.delete();
        _setState(ModelLoadingState.checksumError);
        throw Exception(
            'Downloaded model file failed integrity check. Expected checksum: $checksum');
      }

      return file.path;
    } catch (e) {
      // Set download error state and clean up any partial file
      _setState(ModelLoadingState.downloadError);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // Ignore errors when deleting partial files
        }
      }
      rethrow;
    }
  }

  /// Downloads a model from the given URL with progress tracking
  Future<void> _downloadModel(String url, String savePath) async {
    try {
      // Make a HEAD request to get the content length
      final request = await http.head(Uri.parse(url));
      final contentLength = int.parse(request.headers['content-length'] ?? '0');

      if (kDebugMode) {
        final sizeInMB = contentLength > 0
            ? (contentLength / (1024 * 1024)).toStringAsFixed(2)
            : 'unknown';
        log('Downloading model from $url ($sizeInMB MB)',
            name: "OnnxModelService");
      }

      // Create a client for the download
      final client = http.Client();
      final response = await client.send(http.Request('GET', Uri.parse(url)));

      // Open the output file
      final file = File(savePath);
      final sink = file.openWrite();

      // Track download progress
      int downloaded = 0;

      // Create a completer to wait for the download to finish
      final completer = Completer<void>();

      // Process the response stream
      response.stream.listen(
        (List<int> chunk) {
          // Write the chunk to the file
          sink.add(chunk);

          // Update progress
          downloaded += chunk.length;
          final progress = contentLength > 0 ? downloaded / contentLength : 0.0;

          // Broadcast progress update
          _downloadProgressController.add(DownloadProgress(
            downloaded: downloaded,
            total: contentLength,
            progress: progress,
          ));

          if (kDebugMode && downloaded % (1024 * 1024) < chunk.length) {
            final downloadedMB =
                (downloaded / (1024 * 1024)).toStringAsFixed(2);
            final totalMB = contentLength > 0
                ? (contentLength / (1024 * 1024)).toStringAsFixed(2)
                : 'unknown';
            log('Downloaded $downloadedMB MB / $totalMB MB (${(progress * 100).toStringAsFixed(1)}%)',
                name: "OnnxModelService");
          }
        },
        onDone: () async {
          // Ensure all data is written to disk before closing
          await sink.flush();
          await sink.close();
          client.close();

          if (kDebugMode) {
            log('Download complete: $savePath', name: "OnnxModelService");
          }

          // Complete the future
          completer.complete();
        },
        onError: (e) {
          sink.close();
          client.close();
          file.deleteSync();
          completer.completeError(e);
        },
        cancelOnError: true,
      );

      // Wait for the download to complete
      await completer.future;
    } catch (e) {
      if (kDebugMode) {
        log('Error downloading model: $e', name: "OnnxModelService", error: e);
      }
      _setState(ModelLoadingState.downloadError);
      rethrow;
    }
  }

  /// Initializes the ONNX environment and creates a session
  ///
  /// This method should be called once before using the model for inference
  /// It runs in an isolate to prevent UI freezing
  Future<void> initializeModel(String modelPath, {bool isAsset = true}) async {
    try {
      _setState(ModelLoadingState.loading);

      if (kDebugMode) {
        log('Loading model from ${isAsset ? "asset" : "file"}: $modelPath',
            name: "OnnxModelService");
      }

      Uint8List bytes;

      if (isAsset) {
        // Load the model bytes from an asset in the main isolate
        if (kDebugMode) {
          log('Reading asset file: $modelPath', name: "OnnxModelService");
        }
        final rawAssetFile = await rootBundle.load(modelPath);
        bytes = rawAssetFile.buffer.asUint8List();
        if (kDebugMode) {
          final sizeMB = (bytes.length / (1024 * 1024)).toStringAsFixed(2);
          log('Asset loaded, size: $sizeMB MB', name: "OnnxModelService");
        }
      } else {
        // Load the model bytes from a file in the main isolate
        if (kDebugMode) {
          log('Reading file: $modelPath', name: "OnnxModelService");
        }
        final file = File(modelPath);
        bytes = await file.readAsBytes();
        if (kDebugMode) {
          final sizeMB = (bytes.length / (1024 * 1024)).toStringAsFixed(2);
          log('File loaded, size: $sizeMB MB', name: "OnnxModelService");
        }
      }

      // Initialize the ONNX runtime environment in the main isolate
      // This is required before creating a session
      if (kDebugMode) {
        log('Initializing ONNX runtime environment', name: "OnnxModelService");
      }
      OrtEnv.instance.init();

      // Create the session in a separate isolate
      if (kDebugMode) {
        log('Creating ONNX session in isolate', name: "OnnxModelService");
      }
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
      _setState(ModelLoadingState.loadingError);
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
