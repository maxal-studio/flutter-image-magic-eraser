import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_magic_eraser/image_magic_eraser.dart';
import 'package:example/polygon_inpainting_page.dart';

class ModelDownloadPage extends StatefulWidget {
  final String modelUrl;
  final String expectedChecksum;

  const ModelDownloadPage({
    super.key,
    required this.modelUrl,
    required this.expectedChecksum,
  });

  @override
  State<ModelDownloadPage> createState() => _ModelDownloadPageState();
}

class _ModelDownloadPageState extends State<ModelDownloadPage> {
  ModelLoadingState _loadingState = ModelLoadingState.notLoaded;
  double _downloadProgress = 0.0;
  String _statusMessage = 'Ready to download model';
  bool _isInitializing = false;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  late StreamSubscription<DownloadProgress> _downloadProgressSubscription;
  late StreamSubscription<ModelLoadingState> _stateSubscription;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _checkModelState();
  }

  @override
  void dispose() {
    _downloadProgressSubscription.cancel();
    _stateSubscription.cancel();
    super.dispose();
  }

  /// Check the current model state and handle it appropriately
  void _checkModelState() {
    if (InpaintingService.instance.modelLoadingState ==
        ModelLoadingState.loaded) {
      _navigateToInpaintingPage();
    } else {
      // Start download automatically
      _startModelInitialization();
    }
  }

  /// Sets up stream listeners for model loading state and download progress
  void _setupListeners() {
    // Subscribe to download progress updates
    _downloadProgressSubscription = InpaintingService
        .instance.downloadProgressStream
        .listen(_handleProgressUpdate);

    // Subscribe to model loading state changes
    _stateSubscription = InpaintingService.instance.modelLoadingStateStream
        .listen(_handleStateChange);
  }

  /// Handles download progress updates
  void _handleProgressUpdate(DownloadProgress progress) {
    if (!mounted) return;

    setState(() {
      _downloadProgress = progress.progress;
      _downloadedBytes = progress.downloaded;
      _totalBytes = progress.total;
      _updateDownloadStatusMessage();
    });
  }

  /// Updates the download status message based on current progress
  void _updateDownloadStatusMessage() {
    if (_downloadProgress > 0) {
      final downloadedMB =
          (_downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
      final totalMB = (_totalBytes / (1024 * 1024)).toStringAsFixed(1);
      _statusMessage =
          'Downloading: $downloadedMB MB / $totalMB MB (${(_downloadProgress * 100).toStringAsFixed(1)}%)';
    } else {
      _statusMessage = 'Downloading model...';
    }
  }

  /// Handles model loading state changes
  void _handleStateChange(ModelLoadingState state) {
    if (!mounted) return;

    setState(() {
      _loadingState = state;
      _updateStatusMessage(state);
    });

    // Navigate to inpainting page once model is loaded
    if (state == ModelLoadingState.loaded) {
      _navigateToInpaintingPage();
    }
  }

  /// Updates status message based on the current state
  void _updateStatusMessage(ModelLoadingState state) {
    switch (state) {
      case ModelLoadingState.notLoaded:
        _statusMessage = 'Ready to download';
        break;
      case ModelLoadingState.downloading:
        _updateDownloadStatusMessage();
        break;
      case ModelLoadingState.loading:
        _statusMessage = 'Loading model...';
        break;
      case ModelLoadingState.loaded:
        _statusMessage = 'Model loaded successfully!';
        break;
      case ModelLoadingState.error:
        _statusMessage = 'Error loading model';
        break;
      case ModelLoadingState.downloadError:
        _statusMessage =
            'Error downloading model. Please check your internet connection.';
        break;
      case ModelLoadingState.checksumError:
        _statusMessage =
            'Model file integrity check failed. The downloaded file may be corrupted.';
        break;
      case ModelLoadingState.loadingError:
        _statusMessage =
            'Error loading model. The model file might be incompatible.';
        break;
    }
  }

  /// Navigates to the inpainting page
  void _navigateToInpaintingPage() {
    if (!mounted) return;

    // Use a short delay to ensure UI has updated first
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const PolygonInpaintingPage(),
          ),
        );
      }
    });
  }

  /// Initializes the model by downloading from URL and loading it
  Future<void> _startModelInitialization() async {
    // Prevent multiple initialization attempts
    if (_isInitializing) return;

    // Set the initializing state
    _setInitializing(true);

    try {
      await InpaintingService.instance.initializeOrtFromUrl(
        widget.modelUrl,
        widget.expectedChecksum,
      );
    } catch (e) {
      // Log error but don't handle UI state here - the state stream will handle it
      if (kDebugMode) {
        print('Model initialization error: $e');
      }
    } finally {
      _setInitializing(false);
    }
  }

  /// Updates the initializing state
  void _setInitializing(bool initializing) {
    if (!mounted) return;

    setState(() {
      _isInitializing = initializing;
      if (initializing) {
        _statusMessage = 'Checking AI model...';
      }
    });
  }

  /// Renders the UI based on current state
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Model Download'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _buildContent(),
        ),
      ),
    );
  }

  /// Builds the main content based on the current state
  Widget _buildContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildModelInfo(),
        const SizedBox(height: 32),
        _buildProgressIndicator(),
        Text(
          _statusMessage,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 32),
        _buildActionButton(),
        _buildSuccessIndicator(),
      ],
    );
  }

  /// Builds the model info section
  Widget _buildModelInfo() {
    return Column(
      children: [
        Text(
          'Model URL:',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          widget.modelUrl,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  /// Builds the progress indicator when downloading or loading
  Widget _buildProgressIndicator() {
    if (_loadingState == ModelLoadingState.downloading ||
        _loadingState == ModelLoadingState.loading) {
      return Column(
        children: [
          LinearProgressIndicator(
            value: _loadingState == ModelLoadingState.downloading
                ? _downloadProgress
                : null,
          ),
          const SizedBox(height: 16),
        ],
      );
    }
    return const SizedBox(height: 0);
  }

  /// Builds the action button
  Widget _buildActionButton() {
    final bool showButton = _loadingState == ModelLoadingState.notLoaded ||
        _loadingState == ModelLoadingState.error ||
        _loadingState == ModelLoadingState.downloadError ||
        _loadingState == ModelLoadingState.checksumError ||
        _loadingState == ModelLoadingState.loadingError;

    if (!showButton) return const SizedBox.shrink();

    return ElevatedButton(
      onPressed: _isInitializing ? null : _startModelInitialization,
      child: Text(_loadingState == ModelLoadingState.notLoaded
          ? 'Download & Initialize Model'
          : 'Retry'),
    );
  }

  /// Builds the success indicator
  Widget _buildSuccessIndicator() {
    if (_loadingState == ModelLoadingState.loaded) {
      return const Padding(
        padding: EdgeInsets.only(top: 16.0),
        child: Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 48,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
