import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cases.dart';
import 'ai.dart';
import 'cover.dart';

void main() => runApp(const CaseGen());

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
  Widget build(BuildContext context) => MaterialApp(
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
    home: const Library(),
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

  Future<void> visit(BusinessCase c, [String? answer]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Reader(c, history, answer: answer)),
    );
    if (mounted) setState(() => attempts = history.all());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: NavigationBar(
      height: 66,
      backgroundColor: paper,
      indicatorColor: const Color(0xFFFFDCCA),
      selectedIndex: tab,
      onDestinationSelected: (i) => setState(() {
        tab = i;
        if (i == 2) attempts = history.all();
      }),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.grid_view), label: 'Biblioteca'),
        NavigationDestination(
          icon: Icon(Icons.construction),
          label: 'Campo FDE',
        ),
        NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
      ],
    ),
    body: SafeArea(
      child: FutureBuilder(
        future: cases,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(
              child: TextButton(
                onPressed: () => setState(() => cases = BusinessCase.load()),
                child: const Text('Volver a cargar los casos'),
              ),
            );
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final allCases = snapshot.requireData;
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
                    tooltip: 'Configurar IA',
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
                      ['Biblioteca', 'Campo FDE', 'Historial'][tab],
                      style: heading,
                    ),
                  ),
                  if (tab < 2)
                    Text(
                      '${data.length} casos',
                      style: meta.copyWith(color: muted),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (tab == 1)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    "Simulaciones de Forward Deployed Engineering. Trabaja con el cliente y decide qué desplegarías primero.",
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
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Abrir caso',
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
              if (tab == 2)
                FutureBuilder(
                  future: attempts,
                  builder: (context, s) {
                    if (s.hasError)
                      return TextButton(
                        onPressed: () =>
                            setState(() => attempts = history.all()),
                        child: const Text('Reintentar cargar el historial'),
                      );
                    if (!s.hasData) return const LinearProgressIndicator();
                    if (s.requireData.isEmpty)
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tus propuestas aparecerán aquí cuando resuelvas un caso.',
                            style: body,
                          ),
                          TextButton(
                            onPressed: () => setState(() => tab = 0),
                            child: const Text('Elegir un caso'),
                          ),
                        ],
                      );
                    return Column(
                      children: [
                        for (final row in s.requireData)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(row['title'] as String),
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
                              tooltip: 'Borrar respuesta',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text(
                                      '¿Borrar esta respuesta?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Borrar'),
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
                                        const SnackBar(
                                          content: Text(
                                            'No se pudo borrar la respuesta.',
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
      setState(() => error = 'Escribe tu propuesta para continuar.');
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
          () => error = 'No se pudo guardar. Puedes volver a intentarlo.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
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
              Text(c.brief, style: body),
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
                  labelText: 'Tu propuesta',
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                  errorText: error,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : save,
                child: const Text('Guardar y ver el desenlace'),
              ),
            ] else ...[
              Text(
                c.isFde ? 'Un enfoque posible' : 'La decisión real',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(c.decision, style: body),
              const SizedBox(height: 20),
              Text(
                c.isFde ? 'Cómo validar el piloto' : 'Qué ocurrió después',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(c.outcome, style: body),
              const Divider(height: 36),
              const Text('Tu propuesta', style: meta),
              SelectableText(saved!, style: body),
              const Divider(height: 36),
              AiReview(c, saved!),
              if (c.sources.isNotEmpty) const Text('Fuentes', style: meta),
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
                        const SnackBar(
                          content: Text('No se pudo abrir la fuente.'),
                        ),
                      );
                  },
                ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Volver'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
