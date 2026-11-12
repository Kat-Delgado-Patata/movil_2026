/// Una fila válida leída de un archivo Excel al importar estudiantes.
class RosterImportRow {
  RosterImportRow({required this.rowNumber, required this.fullName, required this.code});

  /// Número de fila dentro del archivo (1 = primera fila), solo para mensajes de error.
  final int rowNumber;
  final String fullName;
  final String code;
}

/// Resultado de leer un archivo Excel antes de confirmarlo contra Firestore.
class RosterImportParseResult {
  RosterImportParseResult({required this.rows, required this.skipped});

  final List<RosterImportRow> rows;

  /// Un mensaje por cada fila que no se pudo usar (vacía, incompleta, etc.).
  final List<String> skipped;
}
