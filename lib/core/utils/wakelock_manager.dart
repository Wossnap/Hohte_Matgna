import 'package:wakelock_plus/wakelock_plus.dart';

/// Ref-counted wrapper around [WakelockPlus] so independent features can each
/// request that the screen stay on without switching it off out from under one
/// another.
///
/// Several things keep the screen awake during a practice session — alternating
/// playback, main-audio playback while the karaoke is on screen, and recording.
/// If each toggled the wakelock directly, one feature ending (e.g. recording
/// stopping) would disable it even though another (main audio) still needs it.
/// Instead, each holds a named "reason"; the wakelock is enabled while at least
/// one reason is active and disabled only when the last one is released.
class WakelockManager {
  WakelockManager._();

  static final Set<String> _reasons = <String>{};

  /// Request the screen stay on for [reason]. Idempotent per reason.
  static void acquire(String reason) {
    final wasEmpty = _reasons.isEmpty;
    _reasons.add(reason);
    if (wasEmpty) {
      WakelockPlus.enable().catchError((_) {});
    }
  }

  /// Release [reason]. The screen is allowed to dim/lock again only once every
  /// reason has been released.
  static void release(String reason) {
    if (_reasons.remove(reason) && _reasons.isEmpty) {
      WakelockPlus.disable().catchError((_) {});
    }
  }
}
