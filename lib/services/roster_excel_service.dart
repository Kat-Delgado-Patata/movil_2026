import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/course_student.dart';
import '../models/roster_import_row.dart';

class RosterExcelException implements Exception {
  RosterExcelException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Lee y genera archivos .xlsx para importar/exportar el roster de un curso.
class RosterExcelService {
  RosterExcelService._();
  static final RosterExcelService instance = RosterExcelService._();

  /// Abre el selector de archivos del sistema. Devuelve `null` si el usuario cancela.
  Future<RosterImportParseResult?> pickAndParse() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      dialogTitle: 'Selecciona el Excel con los estudiantes',
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    return _parse(bytes);
  }

  RosterImportParseResult _parse(List<int> bytes) {
    late Excel workbook;
    try {
      workbook = Excel.decodeBytes(bytes);
    } catch (_) {
      throw RosterExcelException('El archivo no es un Excel (.xlsx) válido.');
    }
    if (workbook.tables.isEmpty) {
      throw RosterExcelException('El archivo no tiene ninguna hoja con datos.');
    }

    final sheet = workbook.tables[workbook.tables.keys.first]!;
    final rows = <RosterImportRow>[];
    final skipped = <String>[];

    for (var i = 0; i < sheet.rows.length; i++) {
      final cells = sheet.rows[i];
      final rowNumber = i + 1;
      final name = cells.isNotEmpty ? cells[0]?.value?.toString().trim() : null;
      final code = cells.length > 1 ? cells[1]?.value?.toString().trim() : null;

      final nameEmpty = name == null || name.isEmpty;
      final codeEmpty = code == null || code.isEmpty;
      if (nameEmpty && codeEmpty) continue; // fila vacía, se ignora en silencio

      if (i == 0 && _looksLikeHeader(name, code)) continue;

      if (nameEmpty || codeEmpty) {
        skipped.add('Fila $rowNumber: falta el nombre o el código');
        continue;
      }
      rows.add(RosterImportRow(rowNumber: rowNumber, fullName: name, code: code));
    }

    if (rows.isEmpty && skipped.isEmpty) {
      throw RosterExcelException('El archivo no tiene filas con datos.');
    }
    return RosterImportParseResult(rows: rows, skipped: skipped);
  }

  bool _looksLikeHeader(String? name, String? code) {
    final n = (name ?? '').toLowerCase();
    final c = (code ?? '').toLowerCase();
    return n.contains('nombre') || c.contains('código') || c.contains('codigo') || c.contains('code');
  }

  /// Genera un .xlsx con el roster actual y abre el panel para compartirlo o guardarlo.
  Future<void> exportRoster({required String courseName, required List<CourseStudent> students}) async {
    final workbook = Excel.createExcel();
    final sheet = workbook['Estudiantes'];
    sheet.appendRow([TextCellValue('Nombre Completo'), TextCellValue('Código Universitario')]);
    for (final student in students) {
      sheet.appendRow([TextCellValue(student.fullName), TextCellValue(student.code)]);
    }
    try {
      workbook.delete('Sheet1');
    } catch (_) {
      // Ya no existía con ese nombre; no es un problema.
    }

    final bytes = workbook.save();
    if (bytes == null) {
      throw RosterExcelException('No se pudo generar el archivo Excel.');
    }

    final tempDir = await getTemporaryDirectory();
    final safeName = courseName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final file = File('${tempDir.path}/roster_$safeName.xlsx');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Lista de estudiantes - $courseName'),
    );
  }
}
