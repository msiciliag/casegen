import 'profile.dart';
import 'narration.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'language.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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

const heading = TextStyle(
  fontSize: 34,
  height: 1.05,
  letterSpacing: -1.5,
  fontWeight: FontWeight.w700,
);
const body = TextStyle(fontSize: 17, height: 1.5);
const meta = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  letterSpacing: .4,
);

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
  const Library({super.key});
  @override
  State<Library> createState() => _LibraryState();
}

class _LibraryState extends State<Library> {
  final history = History();
  late var cases = BusinessCase.load();
  late var attempts = history.all();
  int tab = 0;
  Profile? profile;
  @override
  void initState() {
    super.initState();
    Profile.read()
        .then((p) {
          if (mounted) setState(() => profile = p);
        })
        .catchError((Object _) {});
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

  Future<void> visit(BusinessCase c, [String? answer]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Reader(c, history, answer: answer)),
    );
    if (mounted) setState(() => attempts = history.all());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: CaseNav(
      tab,
      (i) => setState(() {
        tab = i;
        if (i == 2) attempts = history.all();
      }),
    ),
    body: SafeArea(
      child: FutureBuilder(
        future: cases,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(
              child: TextButton(
                onPressed: () => setState(() => cases = BusinessCase.load()),
                child: Text(tr('Volver a cargar los casos', 'Reload cases')),
              ),
            );
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final code = Localizations.localeOf(context).languageCode;
          final allCases = snapshot.requireData
              .map((c) => c.localized(code))
              .toList();
          final data = allCases.where((c) => c.isFde == (tab == 1)).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 38,
                      height: 38,
                    ),
                  ),
                  const SizedBox(width: 10),
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
              const SizedBox(height: 30),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      [
                        tr('Biblioteca', 'Library'),
                        tr('Campo FDE', 'FDE fieldwork'),
                        tr('Perfil', 'Profile'),
                      ][tab],
                      style: heading,
                    ),
                  ),
                  if (tab < 2)
                    Text(
                      tr('${data.length} casos', '${data.length} cases'),
                      style: meta.copyWith(color: muted),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (tab == 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Text(
                    tr(
                      '¿Qué harías si Netflix te pidiera poner precio a un plan con anuncios? Lee o escucha el caso, decide qué propondrías y explica por qué. Después descubre qué hizo la empresa. En Campo FDE puedes practicar cómo resolver un encargo de un cliente.',
                      'What would you charge if Netflix asked you to price a plan with ads? Read or listen to the case, decide what you would propose and explain why. Then find out what the company did. In FDE fieldwork, practise solving a client’s problem.',
                    ),
                    style: const TextStyle(fontSize: 16, height: 1.4),
                  ),
                ),
              if (tab == 1)
                Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    tr(
                      'Simulaciones de Forward Deployed Engineering. Trabaja con el cliente y decide qué desplegarías primero.',
                      'Forward deployed engineering simulations. Work with the client and decide what you would deploy first.',
                    ),
                  ),
                ),
              if (tab < 2 && data.isNotEmpty) ...[
                Material(
                  color: ink,
                  borderRadius: BorderRadius.circular(22),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => visit(data.first),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${data.first.company}   /   ${data.first.topic}',
                            style: meta.copyWith(color: paper),
                          ),
                          SizedBox(
                            width: double.infinity,
                            height: 96,
                            child: CustomPaint(
                              painter: Cover(data.first.id, orange),
                            ),
                          ),
                          Text(
                            data.first.title,
                            style: heading.copyWith(color: paper, fontSize: 30),
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: Color(0xFF484941)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                tr('Abrir caso', 'Open case'),
                                style: TextStyle(
                                  color: paper,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Icon(Icons.arrow_forward, color: orange),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                for (final c in data.skip(1)) ...[
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    onTap: () => visit(c),
                    leading: SizedBox.square(
                      dimension: 50,
                      child: ColoredBox(
                        color: const Color(0xFFE5E6DE),
                        child: CustomPaint(painter: Cover(c.id, ink)),
                      ),
                    ),
                    title: Text(
                      c.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        height: 1.2,
                      ),
                    ),
                    subtitle: Text('${c.company} · ${c.topic}'),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                  const Divider(height: 1),
                ],
              ],
              if (tab == 2) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: ink,
                    child: Icon(Icons.person_outline, color: paper),
                  ),
                  title: Text(
                    profile?.name.isNotEmpty == true
                        ? profile!.name
                        : tr('Mi perfil', 'My profile'),
                  ),
                  subtitle: Text(tr('Solo en este móvil', 'On this device')),
                  trailing: IconButton(
                    tooltip: tr('Editar perfil', 'Edit profile'),
                    onPressed: editProfile,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ),
                if (profile != null)
                  OutlinedButton(
                    onPressed: () =>
                        setState(() => tab = profile!.fieldwork ? 1 : 0),
                    child: Text(
                      profile!.fieldwork
                          ? tr('Practicar campo FDE', 'Practice fieldwork')
                          : tr('Practicar negocios', 'Practice business cases'),
                    ),
                  ),
                const Divider(height: 32),
                Text(tr('Historial', 'History'), style: meta),
              ],
              if (tab == 2)
                FutureBuilder(
                  future: attempts,
                  builder: (context, s) {
                    if (s.hasError)
                      return TextButton(
                        onPressed: () =>
                            setState(() => attempts = history.all()),
                        child: Text(
                          tr(
                            'Reintentar cargar el historial',
                            'Reload history',
                          ),
                        ),
                      );
                    if (!s.hasData) return const LinearProgressIndicator();
                    if (s.requireData.isEmpty)
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(
                              'Tus propuestas aparecerán aquí cuando resuelvas un caso.',
                              'Your proposals will appear here after you complete a case.',
                            ),
                            style: body,
                          ),
                          TextButton(
                            onPressed: () => setState(() => tab = 0),
                            child: Text(tr('Elegir un caso', 'Choose a case')),
                          ),
                        ],
                      );
                    return Column(
                      children: [
                        for (final row in s.requireData)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              allCases
                                      .where((c) => c.id == row['case_id'])
                                      .firstOrNull
                                      ?.title ??
                                  row['title'] as String,
                            ),
                            subtitle: Text(
                              row['answer'] as String,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              final c = allCases
                                  .where((c) => c.id == row['case_id'])
                                  .firstOrNull;
                              if (c != null) visit(c, row['answer'] as String);
                            },
                            trailing: IconButton(
                              tooltip: tr(
                                'Borrar respuesta',
                                'Delete response',
                              ),
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(
                                      tr(
                                        '¿Borrar esta respuesta?',
                                        'Delete this response?',
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: Text(tr('Cancelar', 'Cancel')),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: Text(tr('Borrar', 'Delete')),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  try {
                                    await history.delete(row['id'] as int);
                                    if (mounted)
                                      setState(() => attempts = history.all());
                                  } catch (_) {
                                    if (context.mounted)
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            tr(
                                              'No se pudo borrar la respuesta.',
                                              'Could not delete the response.',
                                            ),
                                          ),
                                        ),
                                      );
                                  }
                                }
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
            ],
          );
        },
      ),
    ),
  );
}

class Reader extends StatefulWidget {
  final BusinessCase c;
  final History history;
  final String? answer;
  const Reader(this.c, this.history, {this.answer, super.key});
  @override
  State<Reader> createState() => _ReaderState();
}

class _ReaderState extends State<Reader> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final interview = <Map<String, String>>[];
  late String? saved = widget.answer;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || saved != null) return;
    final answer = input.text.trim();
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
      await widget.history.save(widget.c, answer);
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
    final c = widget.c.localized(appLanguage.value);
    Localizations.localeOf(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: paper,
        title: Text(c.company),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 36),
          children: [
            Container(
              color: ink,
              height: 66,
              child: CustomPaint(painter: Cover(c.id, orange)),
            ),
            const SizedBox(height: 20),
            Text(c.setting, style: meta.copyWith(color: muted)),
            const SizedBox(height: 10),
            Text(c.title, style: heading),
            const SizedBox(height: 22),
            if (saved == null) ...[
              Narration('${c.title}. ${c.brief} ${c.question}'),
              Text(c.brief, style: body),
              OutlinedButton.icon(
                icon: const Icon(Icons.forum_outlined),
                label: Text(tr('Hablar con el cliente', 'Talk to the client')),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: Text(c.role)),
                        body: SafeArea(
                          child: ListView(
                            padding: const EdgeInsets.all(20),
                            children: [AiReview(c, '', interview: interview)],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 36),
              Text(
                c.question,
                style: body.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: input,
                minLines: 4,
                maxLines: 10,
                readOnly: busy,
                decoration: InputDecoration(
                  labelText: tr('Tu propuesta', 'Your proposal'),
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                  errorText: error,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(
                  tr('Guardar y ver el desenlace', 'Save and see the outcome'),
                ),
              ),
            ] else ...[
              Text(
                c.isFde
                    ? tr('Un enfoque posible', 'One possible approach')
                    : tr('La decisión real', 'The actual decision'),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(c.decision, style: body),
              const SizedBox(height: 20),
              Text(
                c.isFde
                    ? tr('Cómo validar el piloto', 'How to test the pilot')
                    : tr('Qué ocurrió después', 'What happened next'),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(c.outcome, style: body),
              const Divider(height: 36),
              Text(tr('Tu propuesta', 'Your proposal'), style: meta),
              SelectableText(saved!, style: body),
              const Divider(height: 36),
              AiReview(c, saved!),
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
              FilledButton(
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
