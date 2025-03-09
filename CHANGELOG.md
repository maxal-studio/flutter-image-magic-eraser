## 1.0.3

### Improved:

- Optimized file integrity verification:
  - Implemented memory-efficient chunked file reading for checksum calculation
  - Improved integrity check flow to only verify after successful downloads
  - Added automatic cleanup of partial files when downloads fail
  - Enhanced progress reporting with detailed size information
  - Fixed memory leak between verification and model loading

- Reduced memory usage:
  - Optimized model loading process to minimize memory footprint
  - Implemented separate optimized paths for asset and file loading
  - Eliminated redundant memory copies when loading large model files
  - Added explicit memory management to help garbage collection
  - Added file existence check before loading to prevent errors
  - Improved thread management during model initialization
  - Added explicit garbage collection hints between operations

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