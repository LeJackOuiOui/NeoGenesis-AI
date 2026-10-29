import 'package:archive/archive.dart';

class ExcelFileBuilder {
  const ExcelFileBuilder._();

  static List<int> build({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final archive = Archive();
    void addXml(String path, String content) {
      archive.add(ArchiveFile.string(path, content));
    }

    final columns = headers.length;
    final lastColumn = _columnName(columns);
    final sheetRows = <String>[
      _rowXml(1, headers),
      for (var index = 0; index < rows.length; index++)
        _rowXml(index + 2, rows[index]),
    ].join();

    addXml(
      '[Content_Types].xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
          '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
          '<Default Extension="xml" ContentType="application/xml"/>'
          '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
          '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
          '</Types>',
    );
    addXml(
      '_rels/.rels',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
          '</Relationships>',
    );
    addXml(
      'xl/workbook.xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
          'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
          '<sheets><sheet name="Candidatos" sheetId="1" r:id="rId1"/></sheets>'
          '</workbook>',
    );
    addXml(
      'xl/_rels/workbook.xml.rels',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
          '</Relationships>',
    );
    addXml(
      'xl/worksheets/sheet1.xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
          '<dimension ref="A1:$lastColumn${rows.length + 1}"/>'
          '<sheetData>$sheetRows</sheetData>'
          '</worksheet>',
    );
    return ZipEncoder().encode(archive);
  }

  static String _rowXml(int rowNumber, List<String> values) {
    final cells = StringBuffer();
    for (var index = 0; index < values.length; index++) {
      final reference = '${_columnName(index + 1)}$rowNumber';
      cells.write(
        '<c r="$reference" t="inlineStr"><is><t xml:space="preserve">'
        '${_escapeXml(values[index])}</t></is></c>',
      );
    }
    return '<row r="$rowNumber">$cells</row>';
  }

  static String _columnName(int index) {
    var value = index;
    final result = StringBuffer();
    while (value > 0) {
      value--;
      result.writeCharCode(65 + value % 26);
      value ~/= 26;
    }
    return result.toString().split('').reversed.join();
  }

  static String _escapeXml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
