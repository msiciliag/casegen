import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'cover.dart';
import 'language.dart';

class Profile {
  final String name;
  final bool fieldwork;
  const Profile(this.name, this.fieldwork);
  static const storage = FlutterSecureStorage();
  static const key = 'casegen.profile.v1';
  static Future<Profile?> read() async {
    final raw = await storage.read(key: key);
    if (raw == null) return null;
    final data = jsonDecode(raw);
    return Profile(data['name'], data['fieldwork']);
  }

  Future<void> save() => storage.write(
    key: key,
    value: jsonEncode({'name': name, 'fieldwork': fieldwork}),
  );
}

class ProfileForm extends StatefulWidget {
  final Profile? previous;
  final ValueChanged<Profile> onSaved;
  const ProfileForm(this.onSaved, {this.previous, super.key});
  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  late final name = TextEditingController(text: widget.previous?.name);
  late bool fieldwork = widget.previous?.fieldwork ?? false;
  bool saving = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (saving) return;
    setState(() => saving = true);
    final profile = Profile(name.text.trim(), fieldwork);
    try {
      await profile.save();
      if (mounted) widget.onSaved(profile);
    } catch (_) {
      if (mounted)
        setState(() {
          saving = false;
          error = tr(
            'No se pudo guardar. Reinténtalo.',
            'Could not save. Try again.',
          );
        });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset('assets/logo.png', width: 64),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            widget.previous == null
                ? tr('Tu perfil', 'Your profile')
                : tr('Editar perfil', 'Edit profile'),
            style: const TextStyle(
              fontSize: 36,
              height: 1.04,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr(
              'Escucha el caso, pregunta al cliente y defiende tu propuesta.',
              'Listen to the brief, question the client and make your case.',
            ),
            style: const TextStyle(fontSize: 17),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: name,
            maxLength: 40,
            decoration: InputDecoration(
              labelText: tr('Tu nombre (opcional)', 'Your name (optional)'),
            ),
          ),
          Text(
            tr('¿Por dónde quieres empezar?', 'Where would you like to start?'),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final f in [false, true])
                ChoiceChip(
                  label: Text(
                    f
                        ? tr('Campo FDE', 'FDE fieldwork')
                        : tr('Negocios', 'Business'),
                  ),
                  selected: fieldwork == f,
                  onSelected: (_) => setState(() => fieldwork = f),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            tr(
              'Perfil local en este móvil.',
              'Your profile stays on this device.',
            ),
          ),
          if (error != null) Text(error!),
          FilledButton(
            onPressed: saving ? null : submit,
            child: Text(
              widget.previous == null
                  ? tr('Crear perfil', 'Create profile')
                  : tr('Guardar', 'Save'),
            ),
          ),
        ],
      ),
    ),
  );
}

class CaseNav extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const CaseNav(this.selected, this.onSelect, {super.key});
  @override
  Widget build(BuildContext context) => Material(
    color: ink,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        child: Row(
          children: [
            for (final (i, label) in [
              tr('Biblioteca', 'Library'),
              tr('Campo FDE', 'FDE fieldwork'),
              tr('Perfil', 'Profile'),
            ].indexed)
              Expanded(
                child: Semantics(
                  selected: selected == i,
                  button: true,
                  child: InkWell(
                    onTap: () => onSelect(i),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CustomPaint(
                            size: const Size(26, 23),
                            painter: _Mark(i, selected == i ? orange : paper),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: paper,
                              fontSize: 12,
                              fontWeight: selected == i
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Mark extends CustomPainter {
  final int index;
  final Color color;
  _Mark(this.index, this.color);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    if (index == 0) {
      c.drawArc(const Rect.fromLTWH(3, 7, 20, 20), math.pi, math.pi, false, p);
      for (final x in [10.0, 16.0]) {
        c.drawLine(Offset(x, 13), Offset(x, 19), p);
      }
      c.drawLine(const Offset(13, 1), const Offset(13, 4), p);
    } else if (index == 1) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(2, 8, 22, 13),
          const Radius.circular(3),
        ),
        p,
      );
      c.drawArc(const Rect.fromLTWH(8, 3, 10, 10), math.pi, math.pi, false, p);
      c.drawLine(const Offset(10, 13), const Offset(16, 13), p);
    } else {
      c.drawCircle(const Offset(13, 6), 4, p);
      c.drawArc(const Rect.fromLTWH(4, 13, 18, 17), math.pi, math.pi, false, p);
    }
  }

  @override
  bool shouldRepaint(_Mark old) => old.index != index || old.color != color;
}
