import 'package:flutter/material.dart';
import 'covid_api.dart';
import 'covid_data.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(const MyApp());
}

// ---------- Colores ----------
const kFondo = Color(0xFFF2F6F5);
const kVerde = Color(0xFF0F766E);
const kTexto = Color(0xFF1B2B2A);
const kTextoSuave = Color(0xFF5E7371);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Datos COVID-19',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kVerde),
        scaffoldBackgroundColor: kFondo,
      ),
      home: const HomePage(),
    );
  }
}

// ---------- Funciones de ayuda ----------
String formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

// 6330000 -> 6.330.000
String formatNumber(int n) {
  final s = n.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
    buffer.write(s[i]);
  }
  return buffer.toString();
}

// ---------- Pantalla principal ----------
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const countries = [
    'Colombia',
    'Mexico',
    'Argentina',
    'Peru',
    'Chile',
    'Spain',
    'USA',
  ];

  String selected = 'Colombia';
  late Future<CovidData> future = fetchCountry(selected);

  void _reload() {
    setState(() {
      future = fetchCountry(selected);
    });
  }

  Future<void> _notify(CovidData d) async {
    await NotificationService.show(
      title: 'COVID-19: ${d.country}',
      body:
          'Casos: ${formatNumber(d.cases)} | Muertes: ${formatNumber(d.deaths)} | Hoy: ${formatNumber(d.todayCases)}',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notificación enviada')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Datos COVID-19',
          style: TextStyle(fontWeight: FontWeight.w700, color: kTexto),
        ),
        backgroundColor: kFondo,
        surfaceTintColor: kFondo,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSelector(),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<CovidData>(
                  future: future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(color: kVerde),
                      );
                    }
                    if (snapshot.hasError) {
                      return _buildError(snapshot.error.toString());
                    }
                    return _buildContent(snapshot.data!);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Selector de país
  Widget _buildSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD5E2E0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: kVerde),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: kTexto,
          ),
          items: countries
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            selected = value;
            _reload();
          },
        ),
      ),
    );
  }

  // Mensaje de error
  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: kTextoSuave),
            const SizedBox(height: 12),
            const Text(
              'No se pudieron cargar los datos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kTexto,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Revisa tu conexión a internet y vuelve a intentarlo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kTextoSuave),
            ),
            const SizedBox(height: 4),
            Text(
              error,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: kTextoSuave),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  // Datos del país
  Widget _buildContent(CovidData d) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Tarjeta principal
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: kVerde,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (d.flag.isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                d.flag,
                                width: 48,
                                height: 32,
                                fit: BoxFit.cover,
                                // Si la bandera no carga, no se muestra nada.
                                errorBuilder: (context, error, stack) =>
                                    const SizedBox(width: 48, height: 32),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Text(
                              d.country,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        formatNumber(d.cases),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'casos acumulados',
                        style: TextStyle(color: Color(0xFFCDE9E5)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Fila 1
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: Icons.trending_up,
                        label: 'Casos del día',
                        value: formatNumber(d.todayCases),
                        color: const Color(0xFFB45309),
                        background: const Color(0xFFFEF3E2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.favorite_border,
                        label: 'Recuperados',
                        value: formatNumber(d.recovered),
                        color: const Color(0xFF15803D),
                        background: const Color(0xFFE6F6EC),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Fila 2
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: Icons.heart_broken_outlined,
                        label: 'Muertes acumuladas',
                        value: formatNumber(d.deaths),
                        color: const Color(0xFF9F1239),
                        background: const Color(0xFFFCE8EE),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.today_outlined,
                        label: 'Muertes del día',
                        value: formatNumber(d.todayDeaths),
                        color: const Color(0xFF9F1239),
                        background: const Color(0xFFFCE8EE),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.schedule, size: 16, color: kTextoSuave),
                    const SizedBox(width: 6),
                    Text(
                      'Actualizado: ${formatDate(d.updated)}',
                      style: const TextStyle(color: kTextoSuave, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: kVerde,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => _notify(d),
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text(
              'Enviar notificación',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------- Tarjeta pequeña de dato ----------
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color background;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: kTextoSuave, fontSize: 13),
          ),
        ],
      ),
    );
  }
}