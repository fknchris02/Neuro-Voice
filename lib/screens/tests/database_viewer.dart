import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '/services/database_helper.dart';
import '/models/test_result.dart';

class DatabaseViewer extends StatefulWidget {
  const DatabaseViewer({super.key});

  @override
  State<DatabaseViewer> createState() => _DatabaseViewerState();
}

class _DatabaseViewerState extends State<DatabaseViewer> {
  List<TestResult> _allResults = [];
  Map<String, int> _countByType = {};
  int _totalCount = 0;
  String _dbPath = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDatabaseInfo();
  }

  Future<void> _loadDatabaseInfo() async {
    setState(() => _isLoading = true);

    try {
      // Obtener todos los resultados
      final results = await DatabaseHelper.instance.getAllTestResults();

      // Obtener conteo total
      final total = await DatabaseHelper.instance.getTotalTestCount();

      // Obtener conteo por tipo
      final countByType = await DatabaseHelper.instance.getTestCountByType();

      // Obtener ruta de la base de datos
      final db = await DatabaseHelper.instance.database;
      final path = db.path;

      setState(() {
        _allResults = results;
        _totalCount = total;
        _countByType = countByType;
        _dbPath = path;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportData() async {
    // Crear texto con toda la información
    StringBuffer buffer = StringBuffer();
    buffer.writeln('=== EXPORTACIÓN DE BASE DE DATOS ===\n');
    buffer.writeln('Fecha: ${DateTime.now()}\n');
    buffer.writeln('Total de registros: $_totalCount\n');
    buffer.writeln('\n--- CONTEO POR TIPO ---');
    _countByType.forEach((type, count) {
      buffer.writeln('$type: $count registros');
    });

    buffer.writeln('\n\n--- TODOS LOS REGISTROS ---\n');

    for (var result in _allResults) {
      buffer.writeln('ID: ${result.id}');
      buffer.writeln('Tipo: ${result.testType}');
      buffer.writeln('Fecha: ${result.timestamp}');
      buffer.writeln('Puntuación: ${result.overallScore}');
      buffer.writeln('Métricas: ${result.metrics}');
      buffer.writeln('Notas: ${result.notes ?? "N/A"}');
      buffer.writeln('---\n');
    }

    // Mostrar en diálogo
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Datos Exportados'),
          content: SingleChildScrollView(
            child: SelectableText(buffer.toString()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  Color _getTestColor(String testType) {
    switch (testType) {
      case 'spiral':
        return const Color(0xFF3B82F6);
      case 'voice':
        return const Color(0xFF8B5CF6);
      case 'gait':
        return const Color(0xFF10B981);
      case 'tapping':
        return const Color(0xFFF59E0B);
      default:
        return Colors.grey;
    }
  }

  IconData _getTestIcon(String testType) {
    switch (testType) {
      case 'spiral':
        return Icons.draw;
      case 'voice':
        return Icons.mic;
      case 'gait':
        return Icons.directions_walk;
      case 'tapping':
        return Icons.touch_app;
      default:
        return Icons.analytics;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visor de Base de Datos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDatabaseInfo,
            tooltip: 'Actualizar',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportData,
            tooltip: 'Exportar Datos',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información general
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Información General',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(
                      label: 'Total de registros',
                      value: _totalCount.toString(),
                    ),
                    const Divider(),
                    _InfoRow(
                      label: 'Ruta de la base de datos',
                      value: _dbPath,
                      isPath: true,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Conteo por tipo
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registros por Tipo de Test',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_countByType.isEmpty)
                      const Text('No hay datos')
                    else
                      ..._countByType.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _getTestColor(entry.key).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getTestIcon(entry.key),
                                  color: _getTestColor(entry.key),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getTestColor(entry.key).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${entry.value}',
                                  style: TextStyle(
                                    color: _getTestColor(entry.key),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Lista de todos los registros
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Todos los Registros (${_allResults.length})',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_allResults.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('No hay registros en la base de datos'),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _allResults.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final result = _allResults[index];
                          return _RecordCard(result: result);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isPath;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isPath = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontFamily: isPath ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final TestResult result;

  const _RecordCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: _getScoreColor(result.overallScore).withOpacity(0.2),
        child: Text(
          '${result.id}',
          style: TextStyle(
            color: _getScoreColor(result.overallScore),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        result.getTestName(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '${result.timestamp.toString().split('.')[0]} - Score: ${result.overallScore.toStringAsFixed(1)}',
        style: const TextStyle(fontSize: 12),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(label: 'ID', value: result.id.toString()),
              _DetailRow(label: 'Tipo', value: result.testType),
              _DetailRow(
                label: 'Fecha/Hora',
                value: result.timestamp.toString(),
              ),
              _DetailRow(
                label: 'Puntuación',
                value: result.overallScore.toStringAsFixed(2),
              ),
              const SizedBox(height: 8),
              Text(
                'Métricas:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              ...result.metrics.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        entry.value.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (result.notes != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Notas:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(result.notes!),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 75) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}