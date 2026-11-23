import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ai.dart';
import 'cases.dart';
import 'cover.dart';
import 'language.dart';
import 'narration.dart';
import 'game_style.dart';

class Reader extends StatefulWidget {
  final BusinessCase c;
  final History history;
  final String? answer;
  final bool hasNext;
  final int? previousMove, previousId, previousPick;
  final List<Map<String, String>> previousTurns;
  const Reader(
    this.c,
    this.history, {
    this.answer,
    this.hasNext = false,
    this.previousMove,
    this.previousId,
    this.previousPick,
    this.previousTurns = const [],
    super.key,
  });
  @override
  State<Reader> createState() => _ReaderState();
}

class _ReaderState extends State<Reader> {
  final input = TextEditingController();
  final scroll = ScrollController();
  late final interview = [...widget.previousTurns];
  late String? saved = widget.answer;
  bool busy = false, deciding = false, loading = true;
  late int? move = widget.previousMove,
      attemptId = widget.previousId,
      factPick = widget.previousPick;
  late BusinessCase round = widget.c;
  Future<void> chooseFact(int value) async {
    final id = attemptId;
    if (id == null || busy || factPick != null) return;
    setState(() => busy = true);
    try {
      await widget.history.recordCheck(id, value);
      if (mounted) setState(() => factPick = value);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'No se pudo guardar. Inténtalo de nuevo.',
                'Could not save. Please try again.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    try {
      if (saved != null) return;
      final state = await widget.history.draft(widget.c.id);
      if (!mounted || state == null) return;
      if (state['snapshot'] != null)
        round = BusinessCase(widget.c.id, state['snapshot']);
      input.text = state['answer'] as String? ?? '';
      final chosen = state['move'];
      if (chosen is int && chosen >= 0 && chosen < round.moves.length)
        move = chosen;
      deciding = state['deciding'] == true;
      for (final t in (state['turns'] as List? ?? [])) {
        interview.add(Map<String, String>.from(t));
      }
    } catch (_) {
      error = tr(
        'No se pudo recuperar el borrador.',
        'Could not restore the draft.',
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void keepDraft() {
    if (saved != null || loading || busy) return;
    final state = jsonEncode({
      'snapshot': round.data,
      'answer': input.text,
      'move': move,
      'deciding': deciding,
      'turns': interview,
    });
    widget.history.putDraft(widget.c.id, state).catchError((Object _) {
      if (mounted)
        setState(
          () => error = tr(
            'No se pudo guardar el borrador.',
            'Could not save the draft.',
          ),
        );
    });
  }

  void changeStage(bool decision) {
    setState(() => deciding = decision);
    keepDraft();
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  String? error;
  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || saved != null) return;
    final reason = input.text.trim();
    final c = round.localized(appLanguage.value);
    final answer = [
      if (move != null) c.moves[move!],
      if (reason.isNotEmpty) reason,
    ].join('\n\n');
    if (answer.isEmpty) {
      setState(
        () => error = tr(
          'Escribe tu propuesta para continuar.',
          'Write your proposal to continue.',
        ),
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      attemptId = await widget.history.save(
        c,
        answer,
        move: move,
        turns: interview,
      );
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      setState(() => saved = answer);
      scroll.jumpTo(0);
    } catch (_) {
      if (mounted)
        setState(
          () => error = tr(
            'No se pudo guardar. Puedes volver a intentarlo.',
            'Could not save. You can try again.',
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = round.localized(appLanguage.value);
    Localizations.localeOf(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: paper,
        title: Text(c.company),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 36),
                children: [
                  Row(
                    children: [
                      for (final (index, label) in [
                        tr('Reunión', 'Meeting'),
                        tr('Decisión', 'Decision'),
                        tr('Desenlace', 'Debrief'),
                      ].indexed)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  width: 3,
                                  color:
                                      (saved != null
                                              ? 2
                                              : deciding
                                              ? 1
                                              : 0) >=
                                          index
                                      ? orange
                                      : line,
                                ),
                              ),
                            ),
                            child: Text(label, style: meta),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(c.setting, style: meta.copyWith(color: muted)),
                  const SizedBox(height: 8),
                  Text(c.title, style: heading),
                  const SizedBox(height: 18),
                  if (saved == null && !deciding) ...[
                    Text(
                      tr('Tu papel', 'Your role'),
                      style: meta.copyWith(color: muted),
                    ),
                    Text(
                      c.playerRole,
                      style: body.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Narration(
                      '${c.title}. ${tr("Tu papel", "Your role")}: ${c.playerRole}. ${c.brief} ${tr("Hablarás con", "You will meet")} ${c.role}. ${c.remit} ${c.question}',
                      title: c.title,
                      caseId: c.id,
                      scene: c.scene,
                    ),
                    if (c.scene case final scene?)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.notes, size: 18),
                          label: Text(
                            tr(
                              'Dramatización · Ver guion',
                              'Dramatization · Read script',
                            ),
                          ),
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            showDragHandle: true,
                            isScrollControlled: true,
                            builder: (ctx) => SafeArea(
                              child: SizedBox(
                                height: MediaQuery.sizeOf(ctx).height * .66,
                                child: ListView(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    0,
                                    24,
                                    24,
                                  ),
                                  children: [
                                    Text(
                                      tr(
                                        'Dentro de la reunión',
                                        'Inside the meeting',
                                      ),
                                      style: heading,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      tr(
                                        'Diálogo ficticio con voces sintéticas, basado en los hechos del caso.',
                                        'A fictional dialogue with synthetic voices, based on the facts of the case.',
                                      ),
                                      style: meta,
                                    ),
                                    for (final line in scene['lines']) ...[
                                      const SizedBox(height: 16),
                                      Text(
                                        line['speaker'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(line['text'], style: body),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(c.brief, style: body),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ink,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(
                              'A quién puedes consultar',
                              'Who you can interview',
                            ),
                            style: meta.copyWith(color: orange),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            c.role,
                            style: const TextStyle(
                              fontSize: 22,
                              color: paper,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            c.remit,
                            style: const TextStyle(
                              color: paper,
                              height: 1.4,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: paper),
                            icon: const Icon(Icons.forum_outlined),
                            label: Text(
                              interview.isEmpty
                                  ? tr(
                                      'Entrevistar · 3 preguntas',
                                      'Interview · 3 questions',
                                    )
                                  : tr('Ver entrevista', 'Open interview'),
                            ),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => Scaffold(
                                    appBar: AppBar(title: Text(c.role)),
                                    body: SafeArea(
                                      child: ListView(
                                        padding: const EdgeInsets.all(20),
                                        children: [
                                          AiReview(
                                            c,
                                            '',
                                            interview: interview,
                                            onTurnSaved: keepDraft,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                              if (mounted) setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      c.question,
                      style: body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => changeStage(true),
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(tr('Tomar una decisión', 'Make a decision')),
                    ),
                    if (error != null) Text(error!),
                  ] else if (saved == null) ...[
                    Text(c.playerRole, style: meta),
                    const SizedBox(height: 10),
                    Text(c.question, style: body),
                    const SizedBox(height: 14),
                    if (c.moves.isNotEmpty) ...[
                      Text(
                        tr('¿Qué defenderías?', 'What would you advocate?'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      for (final (i, text) in c.moves.indexed)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            move == i
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: ink,
                          ),
                          title: Text(text),
                          onTap: busy
                              ? null
                              : () {
                                  setState(() {
                                    move = i;
                                    error = null;
                                  });
                                  keepDraft();
                                },
                        ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          move == null
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: ink,
                        ),
                        title: Text(
                          tr('Mi propia estrategia', 'My own strategy'),
                        ),
                        onTap: busy
                            ? null
                            : () {
                                setState(() => move = null);
                                keepDraft();
                              },
                      ),
                    ],
                    TextField(
                      controller: input,
                      minLines: 3,
                      maxLines: 10,
                      readOnly: busy,
                      onChanged: (_) => keepDraft(),
                      decoration: InputDecoration(
                        labelText: move == null
                            ? tr('Tu argumento', 'Your reasoning')
                            : tr(
                                'Tu argumento (opcional)',
                                'Your reasoning (optional)',
                              ),
                        hintText: tr(
                          '¿Qué ganarías y qué riesgo aceptarías?',
                          'What would you gain, and which risk would you accept?',
                        ),
                        alignLabelWithHint: true,
                        border: const OutlineInputBorder(),
                        errorText: error,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: busy ? null : save,
                      child: Text(
                        tr(
                          'Guardar y ver el desenlace',
                          'Save and see the outcome',
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => changeStage(false),
                      child: Text(
                        tr(
                          'Volver a la ficha y entrevista',
                          'Revisit brief and interview',
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(
                      c.isFde
                          ? tr('Un enfoque posible', 'One possible approach')
                          : tr('La decisión real', 'The actual decision'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(c.decision, style: body),
                    const SizedBox(height: 20),
                    Text(
                      c.isFde
                          ? tr(
                              'Cómo validar el piloto',
                              'How to test the pilot',
                            )
                          : tr('Qué ocurrió después', 'What happened next'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(c.outcome, style: body),
                    if (c.factCheck case final check?)
                      Container(
                        margin: const EdgeInsets.only(top: 18),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ink,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              tr('Comprueba el titular', 'Check the headline'),
                              style: meta.copyWith(color: orange),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              check['question'],
                              style: body.copyWith(
                                color: paper,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (factPick == null)
                              for (final (i, opt)
                                  in (check['options'] as List).indexed)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: paper,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: busy
                                        ? null
                                        : () => chooseFact(i),
                                    child: Text(opt),
                                  ),
                                ),
                            if (factPick != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                factPick == check['correct']
                                    ? tr('Exacto.', 'Exactly right.')
                                    : tr('Revisa el matiz.', 'Look closer.'),
                                style: meta.copyWith(color: paper),
                              ),
                              Text(
                                check['explanation'],
                                style: body.copyWith(color: paper),
                              ),
                            ],
                          ],
                        ),
                      ),

                    const Divider(height: 36),
                    Text(tr('Tu propuesta', 'Your proposal'), style: meta),
                    SelectableText(saved!, style: body),
                    if (move != null && move! < c.moveDebriefs.length)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: orange, width: 3),
                          ),
                        ),
                        child: Text(c.moveDebriefs[move!], style: body),
                      ),
                    if (interview.isNotEmpty)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(tr('Tu entrevista', 'Your interview')),
                        children: [
                          for (final turn in interview)
                            ListTile(
                              title: Text(
                                turn['role'] == 'user'
                                    ? tr('Tú', 'You')
                                    : c.role,
                              ),
                              subtitle: SelectableText(turn['content']!),
                            ),
                        ],
                      ),

                    const Divider(height: 36),
                    AiReview(c, saved!, reviewInterview: interview),
                    if (c.sources.isNotEmpty)
                      Text(tr('Fuentes', 'Sources'), style: meta),
                    for (final source in c.sources.entries)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(source.key),
                        trailing: const Icon(Icons.open_in_new, size: 18),
                        onTap: () async {
                          try {
                            if (await launchUrl(
                              Uri.parse(source.value),
                              mode: LaunchMode.externalApplication,
                            ))
                              return;
                          } catch (_) {}
                          if (context.mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  tr(
                                    'No se pudo abrir la fuente.',
                                    'Could not open the source.',
                                  ),
                                ),
                              ),
                            );
                        },
                      ),
                    if (widget.hasNext)
                      FilledButton.icon(
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(
                          tr('Jugar el siguiente caso', 'Play the next case'),
                        ),
                      ),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(tr('Volver', 'Back')),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
