import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'language.dart';

class Narration extends StatefulWidget {
  final String text;
  const Narration(this.text, {super.key});
  @override
  State<Narration> createState() => _NarrationState();
}

class _NarrationState extends State<Narration> with WidgetsBindingObserver {
  FlutterTts? engine;
  bool playing = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.isCurrentOf(context) == false && playing) stop();
  }

  void stop() {
    generation++;
    engine?.stop();
    if (mounted && playing) setState(() => playing = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) stop();
  }

  @override
  void didUpdateWidget(Narration old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) stop();
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    engine?.stop();
    super.dispose();
  }

  Future<void> toggle() async {
    if (playing) {
      stop();
      return;
    }
    final current = ++generation;
    setState(() => playing = true);
    try {
      final speech = engine ??= FlutterTts();
      final locale = appLanguage.value == 'es' ? 'es-ES' : 'en-US';
      if (await speech.isLanguageAvailable(locale) != true)
        throw StateError('voice');
      await speech.setLanguage(locale);
      await speech.awaitSpeakCompletion(true);
      if (!mounted || generation != current) return;
      if (await speech.speak(widget.text) != 1) throw StateError('speech');
    } catch (_) {
      if (mounted && generation == current)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'Comprueba las voces instaladas en el dispositivo.',
                'Check the voices installed on your device.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted && generation == current) setState(() => playing = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: toggle,
    icon: Icon(playing ? Icons.stop : Icons.volume_up_outlined),
    label: Text(
      playing
          ? tr('Detener lectura', 'Stop audio')
          : tr('Escuchar el caso', 'Listen to the brief'),
    ),
  );
}
