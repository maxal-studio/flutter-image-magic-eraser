import 'package:flutter/material.dart';
import 'package:image_magic_eraser/image_magic_eraser.dart';
import 'package:example/polygon_inpainting_page.dart';

class ModelAssetPage extends StatefulWidget {
  final String assetModelPath;

  const ModelAssetPage({
    super.key,
    required this.assetModelPath,
  });

  @override
  State<ModelAssetPage> createState() => _ModelAssetPageState();
}

class _ModelAssetPageState extends State<ModelAssetPage> {
  ModelLoadingState _loadingState = ModelLoadingState.notLoaded;
  String _statusMessage = 'Preparing to load model from assets...';
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
      // Otherwise start the initialization process
      _initializeModel();
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
  }

  void _updateStatusMessage() {
    switch (_loadingState) {
      case ModelLoadingState.notLoaded:
        _statusMessage = 'Ready to load model';
        break;
      case ModelLoadingState.downloading:
        _statusMessage = 'Preparing assets...';
        break;
      case ModelLoadingState.loading:
        _statusMessage = 'Loading model from assets...';
        break;
      case ModelLoadingState.loaded:
        _statusMessage = 'Model loaded successfully!';
        break;
      case ModelLoadingState.error:
        _statusMessage = 'Error loading model';
        break;
      case ModelLoadingState.downloadError:
        _statusMessage = 'Error preparing assets';
        break;
      case ModelLoadingState.checksumError:
        _statusMessage = 'Model file integrity check failed';
        break;
      case ModelLoadingState.loadingError:
        _statusMessage = 'Error loading model from assets';
        break;
    }
  }

  Future<void> _initializeModel() async {
    if (_isInitializing) return;

    try {
      setState(() {
        _isInitializing = true;
        _statusMessage = 'Loading model from assets...';
      });

      await InpaintingService.instance.initializeOrt(widget.assetModelPath);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
        _loadingState = ModelLoadingState.error;
      });

      // Show a snackbar with the error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load model: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              _initializeModel();
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
        title: const Text('Loading Model'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Asset Path:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                widget.assetModelPath,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              if (_loadingState == ModelLoadingState.downloading ||
                  _loadingState == ModelLoadingState.loading)
                Column(
                  children: [
                    const CircularProgressIndicator(),
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
                    : _initializeModel,
                child: const Text('Load Model'),
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
