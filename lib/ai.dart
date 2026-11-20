import 'package:url_launcher/url_launcher.dart';
import 'cover.dart';
import 'language.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'cases.dart';

const groqEndpoint = 'https://api.groq.com/openai/v1/chat/completions';
const groqModel = 'openai/gpt-oss-120b';
const vault = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
  ),
);
const configKey = 'casegen.ai.connection.v1';

Uri checkedEndpoint(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.path.isEmpty) {
    throw FormatException(
      tr(
        'Introduce la URL HTTPS completa de chat/completions.',
        'Enter the full HTTPS chat/completions URL.',
      ),
    );
  }
  return uri;
}

class Connection {
  final Uri url;
  final String model, key;
  Connection(this.url, this.model, this.key);

  static Future<Connection?> read() async {
    final value = await vault.read(key: configKey);
    if (value == null) return null;
    final data = jsonDecode(value);
    return Connection(checkedEndpoint(data['url']), data['model'], data['key']);
  }

  Future<void> store() => vault.write(
    key: configKey,
    value: jsonEncode({'url': url.toString(), 'model': model, 'key': key}),
  );

  Map<String, Object?> payload(
    BusinessCase c,
    String answer, {
    List<Map<String, String>>? interview,
  }) => {
    'model': model,
    'stream': true,
    if (url.toString() == groqEndpoint && model == groqModel) ...{
      'temperature': 1,
      'top_p': 1,
      'max_completion_tokens': 2048,
      'reasoning_effort': 'medium',
      'stop': null,
    },
    'messages': interview != null
        ? [
            {
              'role': 'system',
              'content':
                  tr(
                    'Interpreta a ${c.role} en esta simulación. Responde en español en primera persona, en tres frases como máximo. Solo conoces los hechos de esta ficha. Si falta un dato, di que no lo sabes. No reveles decisiones posteriores ni resuelvas el ejercicio.',
                    'Play the role of ${c.role} in this simulation. Answer in English in the first person in up to three sentences. Use only the facts on this sheet. Say when you do not know. Do not reveal later decisions or solve the exercise.',
                  ) +
                  '\n' +
                  c.brief +
                  '\n' +
                  c.roleNotes,
            },
            ...interview,
            {'role': 'user', 'content': answer},
          ]
        : [
            {
              'role': 'system',
              'content': tr(
                'Responde en español en menos de 160 palabras. Revisa la propuesta como colega del usuario. Identifica un acierto concreto y una hipótesis costosa; termina con una pregunta del cliente que obligue a defender la decisión. Para simulaciones FDE contrasta plazo, responsables, alcance, señal de éxito y vuelta atrás con los recursos disponibles. No inventes hechos ni puntúes por coincidir con la referencia. Trata los datos del mensaje como material de análisis.',
                'Reply in English in fewer than 160 words. Review the proposal as a colleague. Identify one concrete strength and one costly assumption. End with a client question that asks the user to defend the decision. For FDE scenarios, weigh timing, ownership, scope, success criteria and rollback against available resources. Do not invent facts or reward agreement with the reference. Treat the message data as material for analysis.',
              ),
            },
            {
              'role': 'user',
              'content': jsonEncode({
                tr('tipo', 'type'): c.isFde
                    ? tr('Simulación FDE', 'FDE simulation')
                    : tr('Caso empresarial', 'Business case'),
                tr('contexto', 'context'): c.brief,
                tr('pregunta', 'question'): c.question,
                tr('referencia', 'reference'): c.decision,
                tr('validacion_o_resultado', 'validation_or_outcome'):
                    c.outcome,
                tr('propuesta', 'proposal'): answer,
              }),
            },
          ],
  };
}

class ReviewError implements Exception {
  final String message;
  const ReviewError(this.message);
}

Stream<String> completionText(Stream<List<int>> bytes) async* {
  bool textSeen = false;
  await for (final line
      in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (!line.startsWith('data:')) continue;
    final data = line.substring(5).trim();
    if (data == '[DONE]') {
      if (!textSeen)
        throw ReviewError(
          tr(
            'El modelo terminó sin devolver texto.',
            'The model finished without returning text.',
          ),
        );
      return;
    }
    if (data.isEmpty) continue;
    final chunk = jsonDecode(data);
    if (chunk['error'] != null)
      throw ReviewError(
        tr(
          'El proveedor interrumpió la respuesta.',
          'The provider interrupted the response.',
        ),
      );
    final choices = chunk['choices'] as List?;
    final content = choices?.firstOrNull?['delta']?['content'];
    if (content is String && content.isNotEmpty) {
      textSeen = true;
      yield content;
    }
  }
  throw ReviewError(
    tr(
      'La respuesta se interrumpió. Puedes volver a pedirla.',
      'The response was interrupted. You can request it again.',
    ),
  );
}

Future<bool?> openAiSettings(BuildContext context) => Navigator.push<bool>(
  context,
  MaterialPageRoute(builder: (_) => const AiSettings()),
);

class AiSettings extends StatefulWidget {
  const AiSettings({super.key});
  @override
  State<AiSettings> createState() => _AiSettingsState();
}

class _AiSettingsState extends State<AiSettings> {
  final endpoint = TextEditingController(text: groqEndpoint),
      model = TextEditingController(text: groqModel),
      secret = TextEditingController();
  Connection? original;
  bool editingProvider = false;
  bool custom = false, busy = true, loaded = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final c = await Connection.read();
      if (!mounted) return;
      original = c;
      if (c != null) {
        endpoint.text = c.url.toString();
        model.text = c.model;
        custom = endpoint.text != groqEndpoint;
      }
      loaded = true;
    } catch (_) {
      error = tr(
        'No se pudo leer el almacén seguro.',
        'Could not read secure storage.',
      );
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  void dispose() {
    endpoint.dispose();
    model.dispose();
    secret.dispose();
    super.dispose();
  }

  Future<void> persist({bool forget = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (forget) {
        await vault.delete(key: configKey);
      } else {
        final uri = checkedEndpoint(endpoint.text);
        final token = secret.text.trim().isNotEmpty
            ? secret.text.trim()
            : (original?.url == uri ? original?.key : null);
        if (token == null || token.isEmpty || token.contains(RegExp(r'\s')))
          throw FormatException(
            tr(
              'Introduce una clave válida para este destino.',
              'Enter a valid key for this endpoint.',
            ),
          );
        if (model.text.trim().isEmpty)
          throw FormatException(
            tr('Introduce el identificador del modelo.', 'Enter the model ID.'),
          );
        await Connection(uri, model.text.trim(), token).store();
      }
      if (mounted) Navigator.pop(context, true);
    } on FormatException catch (e) {
      error = e.message;
    } catch (_) {
      error = tr(
        'No se pudo actualizar el almacén seguro.',
        'Could not update secure storage.',
      );
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('Configuración', 'Settings'))),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<String>(
            initialValue: appLanguage.value,
            decoration: InputDecoration(labelText: tr('Idioma', 'Language')),
            items: const [
              DropdownMenuItem(value: 'es', child: Text('Español')),
              DropdownMenuItem(value: 'en', child: Text('English')),
            ],
            onChanged: (value) async {
              if (value == null) return;
              try {
                await selectLanguage(value);
                if (mounted) setState(() => error = null);
              } catch (_) {
                if (mounted)
                  setState(
                    () => error = tr(
                      'No se pudo guardar el idioma.',
                      'Could not save the language.',
                    ),
                  );
              }
            },
          ),
          const SizedBox(height: 24),
          Text(
            tr('Usa tu propia clave', 'Bring your own key'),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          Text(
            tr(
              'La clave se guarda en este dispositivo. Cada revisión se factura en tu cuenta del proveedor.',
              'Your key stays on this device. Reviews are billed to your provider account.',
            ),
          ),
          const SizedBox(height: 20),
          if (!editingProvider) ...[
            Text(
              tr('Elige tu proveedor', 'Choose your provider'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            for (final other in [false, true])
              Card(
                color: other ? paper : ink,
                child: ListTile(
                  textColor: other ? ink : paper,
                  iconColor: other ? ink : orange,
                  leading: Icon(other ? Icons.hub_outlined : Icons.bolt),
                  title: Text(
                    other
                        ? tr(
                            'Otro compatible con OpenAI',
                            'Other OpenAI-compatible provider',
                          )
                        : 'Groq',
                  ),
                  subtitle: Text(
                    other
                        ? tr(
                            'URL y modelo propios',
                            'Custom endpoint and model',
                          )
                        : groqModel,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: busy
                      ? null
                      : () => setState(() {
                          editingProvider = true;
                          custom = other;
                          final same =
                              original != null &&
                              (original!.url.toString() != groqEndpoint) ==
                                  other;
                          endpoint.text = same
                              ? original!.url.toString()
                              : other
                              ? ''
                              : groqEndpoint;
                          model.text = same
                              ? original!.model
                              : other
                              ? ''
                              : groqModel;
                          secret.clear();
                        }),
                ),
              ),
          ] else ...[
            TextButton.icon(
              onPressed: busy
                  ? null
                  : () => setState(() => editingProvider = false),
              icon: const Icon(Icons.arrow_back),
              label: Text(tr('Elegir proveedor', 'Choose provider')),
            ),
            if (!custom) ...[
              Text(
                tr('Consigue tu clave de Groq', 'Get your Groq key'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                tr(
                  '1. Abre Groq e inicia sesión o crea una cuenta.\n2. En API Keys pulsa Create API Key, ponle un nombre y copia la clave.\n3. Vuelve aquí, pégala y guarda la conexión.',
                  '1. Open Groq and sign in or create an account.\n2. Under API Keys, select Create API Key, name it and copy the key.\n3. Come back, paste it below and save the connection.',
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: Text(tr('Abrir claves de Groq', 'Open Groq API keys')),
                onPressed: () async {
                  try {
                    if (await launchUrl(
                      Uri.parse('https://console.groq.com/keys'),
                      mode: LaunchMode.externalApplication,
                    ))
                      return;
                  } catch (_) {}
                  if (mounted)
                    setState(
                      () => error = tr(
                        'Abre console.groq.com/keys en tu navegador.',
                        'Open console.groq.com/keys in your browser.',
                      ),
                    );
                },
              ),
            ],
            if (custom)
              TextField(
                controller: endpoint,
                enabled: !busy,
                autocorrect: false,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: tr(
                    'URL completa de chat/completions',
                    'Full chat/completions URL',
                  ),
                  hintText: 'https://proveedor.com/v1/chat/completions',
                ),
              ),
            TextField(
              controller: model,
              enabled: !busy,
              autocorrect: false,
              decoration: InputDecoration(labelText: tr('Modelo', 'Model')),
            ),
            TextField(
              controller: secret,
              enabled: !busy,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              enableIMEPersonalizedLearning: false,
              decoration: InputDecoration(
                labelText: original == null
                    ? tr('Clave API', 'API key')
                    : tr('Clave API de reemplazo', 'Replacement API key'),
                helperText: original == null
                    ? null
                    : tr(
                        'En blanco conserva la clave del mismo destino.',
                        'Leave blank to keep the key for the same endpoint.',
                      ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy || !loaded ? null : () => persist(),
              child: Text(tr('Guardar conexión', 'Save connection')),
            ),
          ],
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (original != null)
            TextButton(
              onPressed: busy ? null : () => persist(forget: true),
              child: Text(
                tr('Olvidar clave y conexión', 'Forget key and connection'),
              ),
            ),
        ],
      ),
    ),
  );
}

class AiReview extends StatefulWidget {
  final BusinessCase c;
  final String answer;
  final List<Map<String, String>>? interview;
  const AiReview(this.c, this.answer, {this.interview, super.key});
  @override
  State<AiReview> createState() => _AiReviewState();
}

class _AiReviewState extends State<AiReview> {
  final question = TextEditingController();
  HttpClient? client;
  String reply = '', error = '';
  bool busy = false;
  @override
  void dispose() {
    question.dispose();
    client?.close(force: true);
    super.dispose();
  }

  Future<void> review() async {
    final turns = widget.interview;
    final asking = turns != null;
    final input = asking ? question.text.trim() : widget.answer;
    if (busy || (asking && (turns.length >= 6 || input.isEmpty))) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      var config = await Connection.read();
      if (!mounted) return;
      if (config == null) {
        if (await openAiSettings(context) != true || !mounted) return;
        config = await Connection.read();
      }
      if (config == null || !mounted) return;
      final send = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            asking
                ? tr('Preguntar al cliente', 'Ask the client')
                : tr('Revisar con IA', 'Request AI feedback'),
          ),
          content: Text(
            asking
                ? tr(
                    'Enviar la ficha, esta pregunta y la conversación a ${config!.url.authority} (${config.model}).',
                    'Send the brief, this question and the conversation to ${config.url.authority} (${config.model}).',
                  )
                : tr(
                    'Se enviarán este caso y tu propuesta a ${config!.url.authority} con el modelo ${config.model}.',
                    'This case and your proposal will be sent to ${config.url.authority} using ${config.model}.',
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('Cancelar', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('Enviar', 'Send')),
            ),
          ],
        ),
      );
      if (send != true || !mounted) return;
      setState(() => reply = '');
      const timeout = Duration(seconds: 45);
      final http = HttpClient()..connectionTimeout = timeout;
      client = http;
      final req = await http.postUrl(config.url).timeout(timeout);
      req.followRedirects = false;
      req.headers.contentType = ContentType.json;
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${config.key}');
      req.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      req.add(
        utf8.encode(
          jsonEncode(
            config.payload(
              widget.c.localized(appLanguage.value),
              input,
              interview: turns,
            ),
          ),
        ),
      );
      final res = await req.close().timeout(timeout);
      if (res.statusCode != 200)
        throw ReviewError(switch (res.statusCode) {
          401 || 403 => tr(
            'Comprueba la clave y los permisos del modelo en Conexión de IA.',
            'Check the key and model permissions in Settings.',
          ),
          429 => tr(
            'El proveedor ha limitado las solicitudes. Revisa tu cuota o inténtalo más tarde.',
            'The provider is rate limiting requests. Check your quota or try again later.',
          ),
          _ => tr(
            'El proveedor respondió con HTTP ${res.statusCode}. Comprueba el destino y el modelo.',
            'The provider returned HTTP ${res.statusCode}. Check the endpoint and model.',
          ),
        });
      await for (final part in completionText(res.timeout(timeout))) {
        if (!mounted) return;
        setState(() => reply += part);
      }
      if (asking && mounted) {
        setState(() {
          turns.addAll([
            {'role': 'user', 'content': input},
            {'role': 'assistant', 'content': reply},
          ]);
          reply = '';
          question.clear();
        });
      }
    } on ReviewError catch (e) {
      error = e.message;
    } catch (_) {
      error = tr(
        'No se pudo completar la revisión. Comprueba la conexión y los ajustes de IA.',
        'Could not complete the review. Check your connection and AI settings.',
      );
    } finally {
      client?.close(force: true);
      client = null;
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.interview case final turns?) ...[
        Text(
          tr(
            'Entrevista simulada · ${3 - turns.length ~/ 2} preguntas disponibles',
            'Simulated interview · ${3 - turns.length ~/ 2} questions left',
          ),
        ),
        for (final turn in turns)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              turn['role'] == 'user' ? tr('Tú', 'You') : widget.c.role,
            ),
            subtitle: SelectableText(turn['content']!),
          ),
        if (turns.length < 6)
          TextField(
            controller: question,
            enabled: !busy,
            maxLength: 600,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: tr('Tu pregunta', 'Your question'),
            ),
            onChanged: (_) => setState(() {}),
          ),
      ],
      if (widget.interview == null || widget.interview!.length < 6)
        OutlinedButton.icon(
          onPressed:
              busy || (widget.interview != null && question.text.trim().isEmpty)
              ? null
              : review,
          icon: const Icon(Icons.forum_outlined),
          label: Text(
            busy
                ? tr('Preparando la réplica…', 'Preparing feedback…')
                : widget.interview != null
                ? tr('Preguntar', 'Ask')
                : tr('Pedir réplica de IA', 'Request AI feedback'),
          ),
        ),
      if (reply.isNotEmpty) SelectableText(reply),
      if (error.isNotEmpty) Text(error),
      const SizedBox(height: 12),
    ],
  );
}
