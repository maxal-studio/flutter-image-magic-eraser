## 1.0.4

### Improver:

  - Added option to do Image processing using CPU and GPU
  - Refactored ImageProcessingService

## 1.0.3

### Improved:

  - Implemented dedicated ModelDownloadService for improved separation of concerns
  - Added HTTP status code validation to detect invalid URLs or unavailable resources
  - Implemented file size validation to detect incomplete downloads
  - Implemented memory-efficient chunked file reading for checksum calculation
  - Improved integrity check flow to only verify after successful downloads
  - Added automatic cleanup of partial files when downloads fail

## 1.0.2

### Improved:

- Enhanced error handling for model initialization
- Added specific error states to better identify issues:
  - `ModelLoadingState.downloadError`: For network and download issues
  - `ModelLoadingState.checksumError`: For model integrity verification failures
  - `ModelLoadingState.loadingError`: For model loading and compatibility issues
- Improved error state management to provide more meaningful feedback

## 1.0.1

### Added:

- New method: initializeOrtFromUrl allowing users to load the model from URL

## 1.0.0

### Added
- Initial release of the **Image Magic Eraser** Flutter package.
- ONNX Runtime integration for image inpainting using the `onnx` model.