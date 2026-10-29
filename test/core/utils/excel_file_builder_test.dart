import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neogenesis_ai/core/utils/excel_file_builder.dart';

void main() {
  test('genera un XLSX válido y escapa texto XML', () {
    final bytes = ExcelFileBuilder.build(
      headers: ['Candidato', 'Habilidad'],
      rows: [
        ['Ana <García>', 'C++, R&D'],
      ],
    );

    final files = ZipDecoder().decodeBytes(bytes);
    final workbook = files.findFile('xl/workbook.xml');
    final worksheet = files.findFile('xl/worksheets/sheet1.xml');

    expect(workbook, isNotNull);
    expect(worksheet, isNotNull);
    final worksheetXml = utf8.decode(worksheet!.content);
    expect(worksheetXml, contains('Ana &lt;García&gt;'));
    expect(worksheetXml, contains('C++, R&amp;D'));
  });
}
