import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/hymn_detail_model.dart';
import '../models/attempt_model.dart';

/// Service responsible for handling practice-related operations.
///
/// This includes fetching hymn details for practice, managing play/practice counts,
/// fetching audio breakpoints, and submitting audio for comparison.
class PracticeService {
  /// Get complete hymn details with sections for practice mode
  Future<HymnDetail> getHymnDetail(int hymnId) async {
    final response = await ApiClient.get('${ApiEndpoints.practiceDetail}/$hymnId');

    if (response.statusCode != 200) {
      throw Exception('Failed to load hymn details');
    }

    final decoded = jsonDecode(response.body);
    return HymnDetail.fromJson(decoded);
  }

  /// Increment the play count for a hymn
  Future<void> incrementHymnPlay(int hymnId) async {
    final response = await ApiClient.post(ApiEndpoints.incrementHymnPlay(hymnId));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to increment hymn play count');
    }
  }

  /// Increment the practice count for a hymn
  Future<void> incrementHymnPractice(int hymnId) async {
    final response = await ApiClient.post(ApiEndpoints.incrementHymnPractice(hymnId));
    
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to increment hymn practice count');
    }
  }

  /// Increment the play count for a section
  Future<void> incrementSectionPlay(int sectionId) async {
    final response = await ApiClient.post(ApiEndpoints.incrementSectionPlay(sectionId));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to increment section play count');
    }
  }

  /// Increment the practice count for a section
  Future<void> incrementSectionPractice(int sectionId) async {
    final response = await ApiClient.post(ApiEndpoints.incrementSectionPractice(sectionId));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to increment section practice count');
    }
  }

  /// Get audio breakpoints for comparison
  Future<List<double>> getBreakpoints({
    required String playableType,
    required int playableId,
  }) async {
    final response = await ApiClient.get(
      ApiEndpoints.breakpoints,
      queryParams: {
        'playable_type': playableType,
        'playable_id': playableId,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load breakpoints');
    }

    final decoded = jsonDecode(response.body);
    
    if (decoded['breakpoints'] != null && decoded['breakpoints'] is List) {
      return (decoded['breakpoints'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
    }

    return [];
  }

  /// Submit audio for comparison analysis
  /// Returns true if successfully queued
  Future<bool> submitAudioComparison({
    required String audioFilePath,
    required String playableType,
    required int playableId,
    String algorithm = 'default',
  }) async {
    http.MultipartFile audioFile;

    if (kIsWeb) {
      // On Web, audioFilePath is a Blob URL
      http.Response response;
      try {
        response = await http.get(Uri.parse(audioFilePath));
        if (response.statusCode != 200) {
          throw Exception('Failed to fetch recorded audio bytes: ${response.statusCode}');
        }
      } catch (e) {
        throw Exception('CORS or Network error fetching recorded Blob. Please check server configuration. Error: $e');
      }
      
      // Determine content type from headers or default to webm
      final contentType = response.headers['content-type'] ?? 'audio/webm';
      final extension = contentType.contains('wav') ? 'wav' : 'webm';
      
      audioFile = http.MultipartFile.fromBytes(
        'audio',
        response.bodyBytes,
        filename: 'recording.$extension',
      );
    } else {
      audioFile = await http.MultipartFile.fromPath(
        'audio',
        audioFilePath,
      );
    }

    final response = await ApiClient.postMultipart(
      ApiEndpoints.compareAudio,
      fields: {
        'playable_type': playableType,
        'playable_id': playableId.toString(),
        'algorithm': algorithm,
      },
      files: [audioFile],
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to submit audio comparison: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    return decoded['queued'] == true || decoded['success'] == true;
  }

  /// Get the latest comparison attempt for a playable item
  Future<Attempt?> getLatestAttempt({
    required String playableType,
    required int playableId,
  }) async {
    final response = await ApiClient.get(
      ApiEndpoints.latestAttempt,
      queryParams: {
        'playable_type': playableType,
        'playable_id': playableId,
      },
    );

    if (response.statusCode == 404) {
      return null; // No attempt found
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to get latest attempt');
    }

    final decoded = jsonDecode(response.body);
    
    // Handle both direct object and wrapped response
    if (decoded is Map<String, dynamic>) {
      if (decoded['attempt'] != null) {
        return Attempt.fromJson(decoded['attempt']);
      }
      return Attempt.fromJson(decoded);
    }

    return null;
  }

  /// Poll for comparison results after submission
  /// Polls every [intervalSeconds] until a result with an ID different from [baselineAttemptId] is found
  /// or until [maxAttempts] reached.
  Future<Attempt?> pollForResults({
    required String playableType,
    required int playableId,
    required int? baselineAttemptId,
    int intervalSeconds = 2,
    int maxAttempts = 210, // ~7 minutes like the website
  }) async {
    int attempts = 0;

    while (attempts < maxAttempts) {
      attempts++;

      try {
        final attempt = await getLatestAttempt(
          playableType: playableType,
          playableId: playableId,
        );

        // Check if we got a new result (different ID)
        if (attempt != null && attempt.id != baselineAttemptId) {
          return attempt;
        }
      } catch (e) {
        // Continue polling even if there's an error
        debugPrint('Polling error: $e');
      }

      // Wait before next poll
      if (attempts < maxAttempts) {
        await Future.delayed(Duration(seconds: intervalSeconds));
      }
    }

    return null; // Timeout
  }
}
