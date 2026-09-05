/// A drop-in replacement for the `audioplayers` API, backed by just_audio
/// (ExoPlayer on Android).
///
/// Why this exists: the previous engine decided for itself how much to buffer
/// before it would begin, which on a slow connection meant a long wait *after*
/// pressing play, with no way to tune it. ExoPlayer starts once
/// [AndroidLoadControl.bufferForPlaybackDuration] has buffered (~2s) and keeps
/// downloading while playing — the way streaming players normally behave.
///
/// The surface below deliberately mirrors `audioplayers` so the existing call
/// sites keep working unchanged; only their import needs to point here.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;

enum PlayerState { stopped, playing, paused, completed, disposed }

enum ReleaseMode { release, loop, stop }

abstract class Source {
  const Source();
}

class UrlSource extends Source {
  final String url;
  const UrlSource(this.url);
}

class DeviceFileSource extends Source {
  final String path;
  const DeviceFileSource(this.path);
}

class BytesSource extends Source {
  final Uint8List bytes;
  const BytesSource(this.bytes);
}

/// Feeds in-memory audio to ExoPlayer — just_audio has no bytes source of its
/// own, so replays from the cached copy go through this.
class _BytesAudioSource extends ja.StreamAudioSource {
  final Uint8List _bytes;

  _BytesAudioSource(this._bytes);

  @override
  Future<ja.StreamAudioResponse> request([int? start, int? end]) async {
    final from = start ?? 0;
    final to = end ?? _bytes.length;
    return ja.StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: to - from,
      offset: from,
      stream: Stream.value(_bytes.sublist(from, to)),
      contentType: 'audio/mp4',
    );
  }
}

class AudioPlayer {
  final ja.AudioPlayer _player;
  final StreamController<void> _completeController =
      StreamController<void>.broadcast();
  final StreamController<PlayerState> _stateController =
      StreamController<PlayerState>.broadcast();
  final List<StreamSubscription> _subscriptions = [];

  Source? _source;
  ja.ProcessingState? _lastProcessingState;
  Future<void>? _pendingLoad;

  /// Every live player. Only one should ever be audible: the old engine got
  /// that for free from Android's audio focus, but ExoPlayer instances are
  /// fully independent, so without this a section can play over the main hymn.
  static final Set<AudioPlayer> _live = <AudioPlayer>{};

  AudioPlayer()
      : _player = ja.AudioPlayer(
          audioLoadConfiguration: const ja.AudioLoadConfiguration(
            androidLoadControl: ja.AndroidLoadControl(
              // Begin playing once this much is buffered, rather than waiting
              // for some opaque internal threshold. This is the whole point of
              // moving off the old engine.
              bufferForPlaybackDuration: Duration(seconds: 2),
            ),
          ),
        ) {
    _live.add(this);
    // Both flags matter: just_audio leaves `playing` true when a track reaches
    // the end, so watching it alone means a replay never reports "playing"
    // again and the button stays stuck showing play instead of pause.
    _subscriptions.add(_player.playerStateStream.listen((state) {
      final reachedEnd = state.processingState == ja.ProcessingState.completed;
      final justFinished = reachedEnd &&
          _lastProcessingState != ja.ProcessingState.completed;
      _lastProcessingState = state.processingState;

      if (reachedEnd) {
        _stateController.add(PlayerState.completed);
        if (justFinished) _completeController.add(null);
      } else {
        _stateController.add(
          state.playing ? PlayerState.playing : PlayerState.paused,
        );
      }
    }));
  }

  /// The last source handed to this player, or null if it has none yet.
  Source? get source => _source;

  Stream<Duration> get onPositionChanged => _player.positionStream;

  Stream<Duration> get onDurationChanged =>
      _player.durationStream.where((d) => d != null).cast<Duration>();

  Stream<void> get onPlayerComplete => _completeController.stream;

  Stream<PlayerState> get onPlayerStateChanged => _stateController.stream;

  /// The old engine surfaced native log lines; ExoPlayer errors arrive through
  /// the player's own error handling instead, so this stays empty.
  Stream<String> get onLog => const Stream<String>.empty();

  Future<void> setReleaseMode(ReleaseMode mode) async {
    // The old engine needed ReleaseMode.stop to keep the source loaded after
    // completion so it could be replayed; just_audio keeps it loaded anyway.
    await _player.setLoopMode(
      mode == ReleaseMode.loop ? ja.LoopMode.one : ja.LoopMode.off,
    );
  }

  Future<void> setSource(Source source) async {
    _source = source;
    await _load(source);
  }

  /// Starting a load while another is still in flight makes just_audio abort
  /// the first one with "Loading interrupted", so they are serialised here.
  /// The old engine simply tolerated overlapping loads.
  Future<void> _load(Source source) async {
    final inFlight = _pendingLoad;
    if (inFlight != null) {
      try {
        await inFlight;
      } catch (_) {
        // The earlier load's failure is its caller's problem, not ours.
      }
    }
    final operation = _doLoad(source);
    _pendingLoad = operation;
    try {
      await operation;
    } finally {
      if (identical(_pendingLoad, operation)) _pendingLoad = null;
    }
  }

  Future<void> _doLoad(Source source) async {
    if (source is UrlSource) {
      if (kIsWeb) {
        await _player.setUrl(source.url);
      } else {
        // Streams and caches to disk in the same pass, so a replay costs
        // nothing: the bytes are already on the device. Downloading a second
        // copy in parallel instead (as we used to) fetched everything twice and
        // stole bandwidth from the audio actually being listened to.
        await _player.setAudioSource(
          ja.LockCachingAudioSource(Uri.parse(source.url)),
        );
      }
    } else if (source is DeviceFileSource) {
      await _player.setFilePath(source.path);
    } else if (source is BytesSource) {
      await _player.setAudioSource(_BytesAudioSource(source.bytes));
    }
  }

  static bool _sameSource(Source? a, Source? b) {
    if (a == null || b == null) return false;
    if (a is UrlSource && b is UrlSource) return a.url == b.url;
    if (a is DeviceFileSource && b is DeviceFileSource) return a.path == b.path;
    if (a is BytesSource && b is BytesSource) return identical(a.bytes, b.bytes);
    return false;
  }

  Future<void> play(Source source) async {
    // Re-loading something already loaded is both wasteful and a way to trip
    // the "Loading interrupted" error, so replays just rewind instead.
    if (!_sameSource(source, _source)) {
      _source = source;
      await _load(source);
    }
    await _player.seek(Duration.zero);
    _startPlayback();
  }

  Future<void> resume() async {
    // Starting again after the end: rewind first, otherwise the player sits at
    // the end and appears to do nothing.
    if (_player.processingState == ja.ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    _startPlayback();
  }

  /// just_audio's `play()` does not complete until playback *finishes*, so it
  /// must never be awaited here — callers expect control back as soon as
  /// playback has been kicked off.
  void _startPlayback() {
    _pauseOthers();
    unawaited(_player.play().catchError((Object e) {
      debugPrint('Audio play error: $e');
    }));
  }

  void _pauseOthers() {
    for (final other in _live) {
      if (identical(other, this)) continue;
      if (other._player.playing) {
        unawaited(other._player.pause().catchError((Object e) {
          debugPrint('Could not pause the other player: $e');
        }));
      }
    }
  }

  Future<void> pause() => _player.pause();

  Future<void> stop() async {
    await _player.stop();
    _stateController.add(PlayerState.stopped);
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setPlaybackRate(double rate) => _player.setSpeed(rate);

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  Future<Duration?> getDuration() async => _player.duration;

  Future<Duration?> getCurrentPosition() async => _player.position;

  Future<void> release() async {
    _source = null;
    await _player.stop();
  }

  Future<void> dispose() async {
    _live.remove(this);
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _completeController.close();
    await _stateController.close();
    await _player.dispose();
  }
}
