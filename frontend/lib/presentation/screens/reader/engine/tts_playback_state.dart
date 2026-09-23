/// The three states on-device playback can be in.
///
/// Every `flutter_tts` callback collapses onto one of these from the UI's
/// point of view: `onStart`/`onContinue` -> [playing], `onPause` -> [paused],
/// `onCompletion`/`onCancel`/an error -> [stopped]. "Never started" and
/// "finished/cancelled/errored" are indistinguishable to the control bar.
enum TtsPlaybackState { stopped, playing, paused }
