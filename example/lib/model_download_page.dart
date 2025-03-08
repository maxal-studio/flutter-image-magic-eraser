import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _setupListeners();

    // Check if the model is already loaded
    if (InpaintingService.instance.modelLoadingState ==
        ModelLoadingState.loaded) {
      // If model is already loaded, redirect to inpainting page immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const PolygonInpaintingPage(),
            ),
          );
        }
      });
    } else {
      // Otherwise start the download/initialization process
      _startDownloadAndInitialization();
    }
  }

  void _setupListeners() {
    // Listen to model loading state changes
    InpaintingService.instance.modelLoadingStateStream.listen((state) {
      if (!mounted) return;

      setState(() {
        _loadingState = state;
        _updateStatusMessage();
      });

      // Navigate to the inpainting page immediately after model is loaded
      if (state == ModelLoadingState.loaded) {
        // Use a very short delay to ensure UI has updated first
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
    });

    // Listen to download progress updates
    InpaintingService.instance.downloadProgressStream.listen((progress) {
      if (!mounted) return;

      setState(() {
        _downloadProgress = progress.progress;
        _updateStatusMessage(
          downloaded: progress.downloaded,
          total: progress.total,
        );
      });
    });
  }

  void _updateStatusMessage({int? downloaded, int? total}) {
    switch (_loadingState) {
      case ModelLoadingState.notLoaded:
        _statusMessage = 'Ready to download model';
        break;
      case ModelLoadingState.downloading:
        if (downloaded != null && total != null) {
          final downloadedMB = (downloaded / (1024 * 1024)).toStringAsFixed(1);
          final totalMB = (total / (1024 * 1024)).toStringAsFixed(1);
          _statusMessage =
              'Downloading: $downloadedMB MB / $totalMB MB (${(_downloadProgress * 100).toStringAsFixed(1)}%)';
        } else {
          _statusMessage = 'Downloading model...';
        }
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
    }
  }

  Future<void> _startDownloadAndInitialization() async {
    if (_isInitializing) return;

    try {
      setState(() {
        _isInitializing = true;
        _statusMessage = 'Starting download...';
      });

      await InpaintingService.instance.initializeOrtFromUrl(
        widget.modelUrl,
        widget.expectedChecksum,
      );
    } catch (e) {
      if (!mounted) return;

      // Format the error message to be more user-friendly
      String errorMessage = e.toString();
      if (errorMessage.contains('integrity check')) {
        errorMessage =
            'The downloaded model file is corrupted. Please try again.';
      } else if (errorMessage.contains('Connection')) {
        errorMessage =
            'Network error: Please check your internet connection and try again.';
      } else if (errorMessage.contains('Permission')) {
        errorMessage =
            'Storage permission error: Please check app permissions.';
      }

      setState(() {
        _statusMessage = 'Error: $errorMessage';
        _loadingState = ModelLoadingState.error;
      });

      // Show a snackbar with the error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load model: $errorMessage'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              _startDownloadAndInitialization();
            },
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Model Download'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
              const SizedBox(height: 32),
              if (_loadingState == ModelLoadingState.downloading ||
                  _loadingState == ModelLoadingState.loading)
                Column(
                  children: [
                    LinearProgressIndicator(
                      value: _loadingState == ModelLoadingState.downloading
                          ? _downloadProgress
                          : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _loadingState == ModelLoadingState.loaded ||
                        _loadingState == ModelLoadingState.downloading ||
                        _loadingState == ModelLoadingState.loading ||
                        _isInitializing
                    ? null
                    : _startDownloadAndInitialization,
                child: const Text('Download & Initialize Model'),
              ),
              if (_loadingState == ModelLoadingState.loaded)
                const Padding(
                  padding: EdgeInsets.only(top: 16.0),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 48,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
