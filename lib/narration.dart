import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';

import 'language.dart';
import 'news.dart';

/// Prefer a higher quality installed voice over changing the system default arbitrarily.
Map<String, String>? enhancedVoice(List voices, String locale) {
  Map<String, String>? selected;
  var quality = 0;
  for (final voice in voices.whereType<Map>()) {
    if (voice['locale']?.toString().replaceAll('_', '-') != locale ||
        voice['network_required'] == '1' ||
        (voice['features']?.toString() ?? '').contains('notInstalled'))
      continue;
    final score = switch (voice['quality']) {
      'premium' || 'very high' => 2,
      'enhanced' || 'high' => 1,
      _ => 0,
    };
    if (score <= quality || voice['name'] is! String) continue;
    quality = score;
    selected = {
      'name': voice['name'],
      'locale': voice['locale'],
      if (voice['identifier'] is String) 'identifier': voice['identifier'],
    };
  }
  return selected;
}

class Narration extends StatefulWidget {
  final String text, title, caseId;
  final Map<String, dynamic>? scene;
  const Narration(
    this.text, {
    required this.title,
    required this.caseId,
    this.scene,
    super.key,
  });
  @override
  State<Narration> createState() => _NarrationState();
}

class _NarrationState extends State<Narration>
    with AutomaticKeepAliveClientMixin {
  static Future<void>? _mediaService;
  AudioPlayer? _player;
  Directory? _temporary;
  bool _loading = false, _sceneFailed = false;
  String? _error;
  int _generation = 0;

  @override
  bool get wantKeepAlive => _loading || _player != null;

  @override
  void didUpdateWidget(Narration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.scene?['file'] != widget.scene?['file'])
      _reset();
  }

  Future<File> _synthesize(
    Directory temporary,
    String locale,
    String text,
  ) async {
    final speech = FlutterTts();
    if (await speech.isLanguageAvailable(locale) != true)
      throw StateError('voice');
    await speech.setLanguage(locale);
    final voices = await speech.getVoices;
    if (voices is List) {
      final voice = enhancedVoice(voices, locale);
      if (voice != null) await speech.setVoice(voice);
    }
    await speech.awaitSynthCompletion(true);
    final file = File(
      '${temporary.path}/brief.${Platform.isIOS ? 'caf' : 'wav'}',
    );
    final result = await speech
        .synthesizeToFile(text, file.path, true)
        .timeout(const Duration(seconds: 30));
    if (result != 1 || !await file.exists() || await file.length() == 0)
      throw StateError('speech');
    return file;
  }

  // File-backed speech uses the platform's media player even while the UI sleeps.
  Future<void> _prepare({bool useDevice = false}) async {
    final scene = useDevice ? null : widget.scene;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    updateKeepAlive();
    Directory? temporary;
    AudioPlayer? player;
    try {
      _mediaService ??= JustAudioBackground.init(
        androidNotificationChannelId: 'com.msiciliag.casegen.narration',
        androidNotificationChannelName: 'CaseGen',
        androidStopForegroundOnPause: false,
      );
      try {
        await _mediaService;
      } catch (_) {
        _mediaService = null;
        rethrow;
      }
      if (generation != _generation) return;
      final locale = appLanguage.value == 'es' ? 'es-ES' : 'en-US';
      final tag = MediaItem(
        id: '${widget.caseId}/$locale',
        title: widget.title,
        artist: 'CaseGen',
      );
      late final AudioSource source;
      if (scene != null) {
        final path = 'editorial/audio/${scene['file']}';
        final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
        source = manifest.listAssets().contains(path)
            ? AudioSource.asset(path, tag: tag)
            : AudioSource.uri(
                NewsFeed.endpoint.resolve('audio/${scene['file']}'),
                tag: tag,
              );
      } else {
        temporary = await (await getTemporaryDirectory()).createTemp(
          'casegen-voice-',
        );
        if (generation != _generation) return;
        final file = await _synthesize(temporary, locale, widget.text);
        source = AudioSource.file(file.path, tag: tag);
      }
      if (generation != _generation) return;
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      if (generation != _generation) return;
      player = AudioPlayer();
      await player.setAudioSource(source).timeout(const Duration(seconds: 20));
      if (generation != _generation) return;
      final ready = player;
      _temporary = temporary;
      _player = ready;
      temporary = null;
      player = null;
      setState(() => _loading = false);
      await ready.play();
    } catch (_) {
      if (mounted && generation == _generation) {
        _reset();
        _sceneFailed = scene != null;
        setState(
          () => _error = _sceneFailed
              ? tr(
                  'No se ha podido cargar la escena.',
                  'Could not load the scene.',
                )
              : tr(
                  'No se pudo reproducir. Comprueba que tienes una voz instalada para este idioma.',
                  'Could not play the brief. Check that a voice is installed for this language.',
                ),
        );
      }
    } finally {
      await _release(player, temporary);
      if (mounted && generation == _generation && _loading) {
        setState(() => _loading = false);
        updateKeepAlive();
      }
    }
  }

  static Future<void> _release(
    AudioPlayer? player,
    Directory? temporary,
  ) async {
    await player?.dispose();
    if (temporary != null && await temporary.exists()) {
      try {
        await temporary.delete(recursive: true);
      } on FileSystemException {
        /* The OS can clear its cache. */
      }
    }
  }

  void _reset() {
    ++_generation;
    unawaited(_release(_player, _temporary));
    _player = null;
    _temporary = null;
    _loading = false;
    _error = null;
    _sceneFailed = false;
    updateKeepAlive();
  }

  @override
  void dispose() {
    ++_generation;
    unawaited(_release(_player, _temporary));
    super.dispose();
  }

  String _time(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final player = _player;
    if (player == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: _loading ? null : () => _prepare(),
            icon: Icon(
              _loading ? Icons.hourglass_top : Icons.headphones_outlined,
            ),
            label: Text(
              _loading
                  ? tr('Preparando audio…', 'Preparing audio…')
                  : widget.scene != null
                  ? tr('Escuchar la reunión', 'Listen to the meeting')
                  : tr('Escuchar el caso', 'Listen to the brief'),
            ),
          ),
          if (_error != null) Text(_error!),
          if (_sceneFailed && !_loading)
            TextButton(
              onPressed: () => _prepare(useDevice: true),
              child: Text(
                tr('Leer con la voz del móvil', 'Read with device voice'),
              ),
            ),
        ],
      );
    }
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, _) {
        final done = player.processingState == ProcessingState.completed;
        final playing = player.playing && !done;
        final duration = player.duration ?? Duration.zero;
        return Column(
          children: [
            Row(
              children: [
                IconButton.filled(
                  tooltip: playing
                      ? tr('Pausar', 'Pause')
                      : done
                      ? tr('Repetir', 'Replay')
                      : tr('Continuar', 'Resume'),
                  icon: Icon(
                    playing
                        ? Icons.pause
                        : done
                        ? Icons.replay
                        : Icons.play_arrow,
                  ),
                  onPressed: () async {
                    if (playing) {
                      await player.pause();
                      return;
                    }
                    if (done) await player.seek(Duration.zero);
                    await player.play();
                  },
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      widget.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    const speeds = [1.0, 1.25, 1.5];
                    await player.setSpeed(
                      speeds[(speeds.indexOf(player.speed) + 1) %
                          speeds.length],
                    );
                    if (mounted) setState(() {});
                  },
                  child: Text('${player.speed}×'),
                ),
              ],
            ),
            if (duration > Duration.zero)
              StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (context, snapshot) {
                  final pos = snapshot.data ?? player.position;
                  return Row(
                    children: [
                      Text(_time(pos)),
                      Expanded(
                        child: Slider(
                          value: pos.inMilliseconds
                              .clamp(0, duration.inMilliseconds)
                              .toDouble(),
                          max: duration.inMilliseconds.toDouble(),
                          semanticFormatterCallback: (value) =>
                              _time(Duration(milliseconds: value.round())),
                          onChanged: (value) => player.seek(
                            Duration(milliseconds: value.round()),
                          ),
                        ),
                      ),
                      Text(_time(duration)),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
