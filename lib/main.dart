import 'profile.dart';
import 'dart:convert';
import 'reader.dart';
import 'news.dart';
import 'game_style.dart';
export 'reader.dart' show Reader;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'language.dart';
import 'package:flutter/material.dart';

import 'cases.dart';
import 'ai.dart';
import 'cover.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await restoreLanguage();
  } on Exception {
    /* Use Spanish if storage is unavailable. */
  }
  runApp(const CaseGen());
}

class CaseGen extends StatelessWidget {
  const CaseGen({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: appLanguage,
    builder: (context, code, _) => MaterialApp(
      locale: Locale(code),
      supportedLocales: const [Locale("es"), Locale("en")],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      title: 'CaseGen',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: paper,
        colorScheme: ColorScheme.fromSeed(
          seedColor: orange,
          primary: ink,
          surface: paper,
        ),
        dividerColor: line,
        visualDensity: VisualDensity.standard,
      ),
      home: Library(),
    ),
  );
}

class Library extends StatefulWidget {
  final History? history;
  const Library({this.history, super.key});
  @override
  State<Library> createState() => _LibraryState();
}

class _LibraryState extends State<Library> {
  late final history = widget.history ?? History();
  late final catalog = loadCatalog();
  List<BusinessCase> news = [];
  List<Map<String, Object?>> attempts = [];
  Map<String, BusinessCase> drafts = {};
  int tab = 0;
  bool archive = false, refreshing = false, historyFailed = false;
  Profile? profile;

  Future<List<BusinessCase>> loadCatalog() async {
    final lists = await Future.wait([BusinessCase.load(), NewsFeed.load()]);
    news = lists.last;
    return lists.first;
  }

  @override
  void initState() {
    super.initState();
    catalog.then((_) {
      if (mounted) refreshNews();
    }, onError: (Object _) {});
    reloadHistory();
    Profile.read()
        .then((p) {
          if (mounted) setState(() => profile = p);
        })
        .catchError((Object _) {});
  }

  Future<void> refreshNews({bool manual = false}) async {
    if (refreshing) return;
    setState(() => refreshing = true);
    try {
      final updated = await NewsFeed.refresh();
      if (mounted) setState(() => news = updated);
      if (manual && mounted)
        message(tr('Edición actualizada.', 'Edition up to date.'));
    } catch (_) {
      if (manual && mounted)
        message(
          tr(
            'No se pudo actualizar. Puedes jugar la edición guardada.',
            'Update unavailable. The saved edition is ready to play.',
          ),
        );
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> reloadHistory() async {
    try {
      final rows = await history.all();
      final pending = await history.draftCases();
      if (mounted)
        setState(() {
          attempts = rows;
          drafts = pending;
          historyFailed = false;
        });
    } catch (_) {
      if (mounted) setState(() => historyFailed = true);
    }
  }

  Future<void> editProfile() async {
    final updated = await Navigator.push<Profile>(
      context,
      MaterialPageRoute(
        builder: (ctx) =>
            ProfileForm((p) => Navigator.pop(ctx, p), previous: profile),
      ),
    );
    if (updated != null && mounted) setState(() => profile = updated);
  }

  Future<void> play(
    BusinessCase start,
    List<BusinessCase> deck, {
    String? answer,
    int? previousMove,
    int? previousId,
    int? previousPick,
    List<Map<String, String>> previousTurns = const [],
  }) async {
    var current = start;
    while (mounted) {
      final completed = attempts.map((a) => a['case_id']).toSet();
      final next = deck
          .where((c) => c.id != current.id && !completed.contains(c.id))
          .firstOrNull;
      final advance = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => Reader(
            current,
            history,
            answer: answer,
            previousMove: previousMove,
            previousId: previousId,
            previousPick: previousPick,
            previousTurns: previousTurns,
            hasNext: next != null,
          ),
        ),
      );
      await reloadHistory();
      if (advance != true || next == null) return;
      current = next;
      answer = null;
      previousMove = null;
      previousId = null;
      previousPick = null;
      previousTurns = [];
    }
  }

  Future<void> remove(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('¿Borrar esta respuesta?', 'Delete this response?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancelar', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Borrar', 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await history.delete(id);
      await reloadHistory();
    } catch (_) {
      if (mounted)
        message(
          tr(
            'No se pudo borrar la respuesta.',
            'Could not delete the response.',
          ),
        );
    }
  }

  Widget progress(
    String title,
    List<BusinessCase> deck,
    Set<Object?> completed,
  ) {
    final count = deck.where((c) => completed.contains(c.id)).length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: meta)),
              Text('$count / ${deck.length}', style: meta),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: deck.isEmpty ? 0 : count / deck.length,
              color: ink,
              backgroundColor: line,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  String dateOf(BusinessCase c) {
    final date = DateTime.tryParse(c.data['newsDate'] as String? ?? '');
    return date == null
        ? ''
        : MaterialLocalizations.of(context).formatMediumDate(date);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: CaseNav(tab, (i) => setState(() => tab = i)),
    body: SafeArea(
      child: FutureBuilder(
        future: catalog,
        builder: (context, s) {
          if (s.hasError)
            return Center(
              child: Text(
                tr(
                  'No se pudo abrir el catálogo.',
                  'Could not open the catalog.',
                ),
              ),
            );
          if (!s.hasData)
            return const Center(child: CircularProgressIndicator());
          final lang = Localizations.localeOf(context).languageCode;
          final issues = news.map((c) => c.localized(lang)).toList();
          final classic = s.requireData
              .where((c) => !c.isFde)
              .map((c) => c.localized(lang))
              .toList();
          final field = s.requireData
              .where((c) => c.isFde)
              .map((c) => c.localized(lang))
              .toList();
          final deck = tab == 1
              ? field
              : archive
              ? classic
              : issues;
          final completed = attempts.map((a) => a['case_id']).toSet();
          final hero =
              deck.where((c) => drafts.containsKey(c.id)).firstOrNull ??
              deck.where((c) => !completed.contains(c.id)).firstOrNull ??
              deck.firstOrNull;
          String status(BusinessCase c) => drafts.containsKey(c.id)
              ? tr('Continuar partida', 'Resume game')
              : completed.contains(c.id)
              ? tr('Volver a jugar', 'Play again')
              : tr('Jugar', 'Play');
          return ListView(
            key: PageStorageKey('home-$tab-$archive'),
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 36,
                      height: 36,
                    ),
                  ),
                  const SizedBox(width: 9),
                  const Text(
                    'CaseGen',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: tr('Configuración', 'Settings'),
                    icon: const Icon(Icons.tune),
                    onPressed: () => openAiSettings(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (tab == 0)
                Wrap(
                  spacing: 8,
                  children: [
                    for (final old in [false, true])
                      ChoiceChip(
                        selected: archive == old,
                        label: Text(
                          old
                              ? tr('Archivo', 'Archive')
                              : tr('Actualidad', 'In the news'),
                        ),
                        onSelected: (_) => setState(() => archive = old),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              if (tab != 2) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tab == 1
                            ? tr('En el terreno', 'In the field')
                            : archive
                            ? tr('El archivo', 'The archive')
                            : tr('En portada', 'The lead story'),
                        style: heading,
                      ),
                    ),
                    if (tab == 0 && !archive)
                      IconButton(
                        tooltip: tr('Actualizar edición', 'Refresh edition'),
                        onPressed: refreshing
                            ? null
                            : () => refreshNews(manual: true),
                        icon: const Icon(Icons.refresh),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  tab == 1
                      ? tr(
                          'Trabaja con el cliente y decide qué pondrás en marcha primero.',
                          'Work with the client and decide what to ship first.',
                        )
                      : archive
                      ? tr(
                          'Vuelve al momento en que la empresa tuvo que decidir.',
                          'Go back to the moment the company had to decide.',
                        )
                      : tr(
                          'Juega una noticia real. Toma la decisión antes de descubrir qué hizo la empresa.',
                          'Play a real news story. Make the call before you see what the company did.',
                        ),
                  style: const TextStyle(fontSize: 16, height: 1.3),
                ),
                const SizedBox(height: 15),
                if (hero != null)
                  Material(
                    color: ink,
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => play(hero, deck),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [
                                hero.company,
                                dateOf(hero).isEmpty
                                    ? hero.topic
                                    : dateOf(hero),
                              ].join('   /   '),
                              style: meta.copyWith(color: paper),
                            ),
                            SizedBox(
                              height: 74,
                              width: double.infinity,
                              child: CustomPaint(
                                painter: Cover(hero.id, orange),
                              ),
                            ),
                            Text(
                              hero.title,
                              style: heading.copyWith(
                                color: paper,
                                fontSize: 29,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: muted),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  status(hero),
                                  style: meta.copyWith(color: paper),
                                ),
                                const Icon(Icons.arrow_forward, color: orange),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                progress(
                  tr('Casos resueltos', 'Cases completed'),
                  deck,
                  completed,
                ),
                for (final c in deck.where((item) => item != hero))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => play(c, deck),
                    leading: Icon(
                      completed.contains(c.id)
                          ? Icons.check_circle_outline
                          : Icons.play_circle_outline,
                    ),
                    title: Text(
                      c.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      [
                        c.company,
                        dateOf(c),
                        status(c),
                      ].where((v) => v.isNotEmpty).join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
              ] else ...[
                Text(
                  profile?.name.isNotEmpty == true
                      ? profile!.name
                      : tr('Mi perfil', 'My profile'),
                  style: heading,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: editProfile,
                    label: Text(tr('Editar perfil', 'Edit profile')),
                  ),
                ),
                if (profile != null)
                  OutlinedButton(
                    onPressed: () =>
                        setState(() => tab = profile!.fieldwork ? 1 : 0),
                    child: Text(
                      profile!.fieldwork
                          ? tr('Practicar en el terreno', 'Play fieldwork')
                          : tr('Practicar negocios', 'Play business cases'),
                    ),
                  ),
                if (historyFailed)
                  TextButton(
                    onPressed: reloadHistory,
                    child: Text(
                      tr(
                        'Reintentar cargar tu progreso',
                        'Retry loading your progress',
                      ),
                    ),
                  ),
                if (drafts.isNotEmpty) ...[
                  const Divider(height: 32),
                  Text(
                    tr('Partidas en curso', 'Games in progress'),
                    style: heading.copyWith(fontSize: 23),
                  ),
                  for (final c in drafts.values.map((d) => d.localized(lang)))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(c.title),
                      subtitle: Text(tr('Continuar partida', 'Resume game')),
                      trailing: const Icon(Icons.play_arrow_outlined),
                      onTap: () => play(c, []),
                    ),
                  const Divider(height: 32),
                ],
                progress(
                  tr('Edición actual', 'Current edition'),
                  issues,
                  completed,
                ),
                progress(
                  tr('Archivo de negocios', 'Business archive'),
                  classic,
                  completed,
                ),
                progress(tr('Campo FDE', 'FDE fieldwork'), field, completed),
                const Divider(height: 32),
                Text(
                  tr('Tus decisiones', 'Your decisions'),
                  style: heading.copyWith(fontSize: 23),
                ),
                if (attempts.isEmpty)
                  Text(
                    tr(
                      'Tu primera propuesta aparecerá aquí al cerrar una partida.',
                      'Your first proposal will appear here when you finish a game.',
                    ),
                  ),
                for (final row in attempts)
                  Builder(
                    builder: (ctx) {
                      final id = row['case_id'] as String;
                      final c = row['snapshot'] is String
                          ? BusinessCase(
                              id,
                              jsonDecode(row['snapshot'] as String),
                            ).localized(lang)
                          : [
                              ...classic,
                              ...field,
                              ...issues,
                            ].where((c) => c.id == id).firstOrNull;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(c?.title ?? row['title'] as String),
                        subtitle: Text(
                          row['answer'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: c == null
                            ? null
                            : () => play(
                                c,
                                [],
                                answer: row['answer'] as String,
                                previousMove: row['move_index'] as int?,
                                previousId: row['id'] as int?,
                                previousPick: row['fact_pick'] as int?,
                                previousTurns: row['transcript'] == null
                                    ? []
                                    : (jsonDecode(row['transcript'] as String)
                                              as List)
                                          .map(
                                            (turn) =>
                                                Map<String, String>.from(turn),
                                          )
                                          .toList(),
                              ),
                        trailing: IconButton(
                          tooltip: tr('Borrar respuesta', 'Delete response'),
                          onPressed: () => remove(row['id'] as int),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      );
                    },
                  ),
              ],
            ],
          );
        },
      ),
    ),
  );
}
