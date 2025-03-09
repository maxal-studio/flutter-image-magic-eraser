import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/model_init_data.dart';

/// Service for handling model downloads with proper validation and error handling
class ModelDownloadService {
  ModelDownloadService._internal();

  static final ModelDownloadService _instance =
      ModelDownloadService._internal();

  /// Returns the singleton instance of the service
  static ModelDownloadService get instance => _instance;

  /// Stream controller for broadcasting download progress
  final _downloadProgressController =
      StreamController<DownloadProgress>.broadcast();

  /// Stream of download progress updates
  Stream<DownloadProgress> get downloadProgressStream =>
      _downloadProgressController.stream;

  /// Downloads a file from the given URL with validation and progress tracking
  ///
  /// Performs proper validation of HTTP status codes and content size
  /// Progress updates are provided via the downloadProgressStream
  ///
  /// - [url]: The URL to download from
  /// - [savePath]: The local path to save the file to
  /// - [minSize]: Minimum expected file size in bytes (default: 1024)
  /// - Returns: A File object pointing to the downloaded file
  Future<File> downloadFile(String url, String savePath,
      {int minSize = 1024}) async {
    try {
      // Make a HEAD request to get the content length and verify URL validity
      final headRequest = await http.head(Uri.parse(url));

      // Verify the HTTP status code is successful (200-299)
      if (headRequest.statusCode < 200 || headRequest.statusCode >= 300) {
        throw Exception(
            'Invalid URL or resource not found (HTTP ${headRequest.statusCode}): $url');
      }

      final contentLength =
          int.parse(headRequest.headers['content-length'] ?? '0');

      // Validate that content length is reasonable for the expected file
      if (contentLength <= minSize) {
        throw Exception(
            'Invalid file: Content length is too small ($contentLength bytes). The URL might be invalid or the resource is not available.');
      }

      if (kDebugMode) {
        final sizeInMB = (contentLength / (1024 * 1024)).toStringAsFixed(2);
        log('Downloading file from $url ($sizeInMB MB)',
            name: "ModelDownloadService");
      }

      // Create a client for the download
      final client = http.Client();
      final getRequest = http.Request('GET', Uri.parse(url));
      final response = await client.send(getRequest);

      // Verify the HTTP status code for the GET request is successful
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'Failed to download file (HTTP ${response.statusCode}): $url');
      }

      // Open the output file
      final file = File(savePath);
      final sink = file.openWrite();

      // Track download progress
      int downloaded = 0;

      // Create a completer to wait for the download to finish
      final completer = Completer<File>();

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
                name: "ModelDownloadService");
          }
        },
        onDone: () async {
          // Ensure all data is written to disk before closing
          await sink.flush();
          await sink.close();
          client.close();

          // Verify the file size matches the expected content length
          final downloadedFile = File(savePath);
          final fileSize = await downloadedFile.length();
          if (contentLength > 0 && fileSize != contentLength) {
            throw Exception(
                'Downloaded file size ($fileSize bytes) does not match expected size ($contentLength bytes). The download may be incomplete.');
          }

          if (kDebugMode) {
            final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);
            log('Download complete: $savePath (Size: $fileSizeMB MB)',
                name: "ModelDownloadService");
          }

          // Complete the future with the downloaded file
          completer.complete(downloadedFile);
        },
        onError: (e) {
          sink.close();
          client.close();
          try {
            file.deleteSync();
          } catch (_) {
            // Ignore errors when deleting files
          }
          completer.completeError(e);
        },
        cancelOnError: true,
      );

      // Wait for the download to complete
      return await completer.future;
    } catch (e) {
      if (kDebugMode) {
        log('Error downloading file: $e',
            name: "ModelDownloadService", error: e);
      }
      rethrow;
    }
  }

  /// Validates a URL by making a HEAD request and checking response status
  ///
  /// - [url]: The URL to validate
  /// - Returns: A Future[bool] indicating if the URL is valid and accessible
  Future<bool> validateUrl(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }

  /// Gets the content length of a file at a URL without downloading it
  ///
  /// - [url]: The URL to check
  /// - Returns: The content length in bytes, or 0 if unable to determine
  Future<int> getContentLength(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return int.parse(response.headers['content-length'] ?? '0');
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Disposes of resources when the service is no longer needed
  void dispose() {
    _downloadProgressController.close();
  }
}
