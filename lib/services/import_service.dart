import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel2003/excel2003.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

class ImportService {
  static const Map<String, int> _months = {
    'jan': 1, 'january': 1,
    'feb': 2, 'february': 2,
    'mar': 3, 'march': 3,
    'apr': 4, 'april': 4,
    'may': 5,
    'jun': 6, 'june': 6,
    'jul': 7, 'july': 7,
    'aug': 8, 'august': 8,
    'sep': 9, 'september': 9,
    'oct': 10, 'october': 10,
    'nov': 11, 'november': 11,
    'dec': 12, 'december': 12,
  };

  /// Parses date string in YYYY-MM-DD, DD/MM/YYYY, DD-MM-YYYY, or D MMM YYYY formats and returns "DD/MM/YYYY"
  static String? normalizeDate(String input) {
    try {
      final clean = input.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (clean.isEmpty) return null;

      // Check for hyphens first: try ISO YYYY-MM-DD (e.g. 2026-05-12 or 2026-5-2)
      if (clean.contains('-')) {
        final ymdRegex = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$');
        final ymdMatch = ymdRegex.firstMatch(clean);
        if (ymdMatch != null) {
          final year = int.parse(ymdMatch.group(1)!);
          final month = int.parse(ymdMatch.group(2)!);
          final day = int.parse(ymdMatch.group(3)!);
          if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
            final dt = DateTime(year, month, day);
            if (dt.year == year && dt.month == month && dt.day == day) {
              return '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/$year';
            }
          }
          return null;
        }
      }

      // Try DD/MM/YYYY or DD-MM-YYYY
      final dmyRegex = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$');
      var match = dmyRegex.firstMatch(clean);
      if (match != null) {
        final day = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        var year = int.parse(match.group(3)!);
        if (year < 100) year += 2000;
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          final dt = DateTime(year, month, day);
          if (dt.year == year && dt.month == month && dt.day == day) {
            return '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/$year';
          }
        }
        return null;
      }

      // Try D MMM YYYY (e.g. 12 May 2026)
      final parts = clean.split(' ');
      if (parts.length >= 3) {
        final day = int.tryParse(parts[0]);
        final monthStr = parts[1].toLowerCase();
        var year = int.tryParse(parts[2]);
        final month = _months[monthStr];

        if (day != null && month != null && year != null) {
          if (year < 100) year += 2000;
          if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
            final dt = DateTime(year, month, day);
            if (dt.year == year && dt.month == month && dt.day == day) {
              return '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/$year';
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Parses duration/extra time formats (HH:MM or decimal/integer minutes) and returns "HH:MM" or "-HH:MM"
  static String? normalizeDuration(dynamic input) {
    if (input == null) return null;
    final str = input.toString().trim();
    if (str.isEmpty) return null;

    // Try HH:MM
    if (str.contains(':')) {
      final parts = str.split(':');
      if (parts.length >= 2) {
        final hh = int.tryParse(parts[0]);
        final mm = int.tryParse(parts[1]);
        if (hh != null && mm != null) {
          final isNegative = str.contains('-') || hh < 0 || mm < 0;
          final absHh = hh.abs();
          final absMm = mm.abs();
          final prefix = isNegative ? '-' : '';
          return '$prefix${absHh.toString().padLeft(2, '0')}:${absMm.toString().padLeft(2, '0')}';
        }
      }
    }

    // Try minutes (decimal/integer)
    final mins = double.tryParse(str);
    if (mins != null) {
      final totalMins = mins.round();
      final isNegative = totalMins < 0;
      final absMins = totalMins.abs();
      final hh = absMins ~/ 60;
      final mm = absMins % 60;
      final prefix = isNegative ? '-' : '';
      return '$prefix${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
    }

    return null;
  }

  /// Converts a normalized duration string ("HH:MM" or "-HH:MM") to total minutes.
  /// Returns null if format is invalid or cannot be parsed.
  static int? durationToMinutes(String durationStr) {
    final parts = durationStr.split(':');
    if (parts.length >= 2) {
      final hh = int.tryParse(parts[0]);
      final mm = int.tryParse(parts[1]);
      if (hh != null && mm != null) {
        final total = hh.abs() * 60 + mm.abs();
        final isNegative = durationStr.contains('-') || hh < 0 || mm < 0;
        return isNegative ? -total : total;
      }
    }
    return null;
  }


  /// Normalizes start time (HH:MM)
  static String? normalizeStartTime(String input) {
    final str = input.trim();
    if (str.contains(':')) {
      final parts = str.split(':');
      if (parts.length >= 2) {
        final hh = int.tryParse(parts[0]);
        final mm = int.tryParse(parts[1]);
        if (hh != null && mm != null) {
          return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
        }
      }
    }
    return null;
  }

  /// Splits room string into list of trimmed room names. If empty, returns list with one empty string.
  static List<String> splitRooms(String? input) {
    if (input == null || input.trim().isEmpty) {
      return [''];
    }
    // Split by comma, semicolon or slash
    final rawList = input.split(RegExp(r'[,;/]'));
    final rooms = rawList
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty)
        .toList();
    return rooms.isEmpty ? [''] : rooms;
  }

  /// Parses file (CSV or Excel) and returns header columns + row data (list of maps)
  static Future<ParsedFile> parseFile(String filePath) async {
    final file = File(filePath);
    final ext = filePath.split('.').last.toLowerCase();

    List<List<dynamic>> rows = [];

    if (ext == 'csv') {
      final bytes = await file.readAsBytes();
      // Try UTF-8 first, fallback to Latin1 if it fails
      String content;
      try {
        content = utf8.decode(bytes);
      } catch (_) {
        content = latin1.decode(bytes);
      }
      rows = csv.decode(content);
    } else if (ext == 'xls') {
      final bytes = await file.readAsBytes();

      // First attempt: legacy BIFF8 format (Excel 97-2003) via excel2003
      bool parsedWithBiff = false;
      Object? biffError;
      try {
        final reader = XlsReader.fromBytes(bytes);
        reader.open();

        if (reader.sheetCount == 0) {
          throw Exception('The .xls file contains no sheets.');
        }

        final xlsSheet = reader.sheet(0);
        for (int r = xlsSheet.firstRow; r < xlsSheet.lastRow; r++) {
          final List<dynamic> rowData = [];
          for (int c = xlsSheet.firstCol; c < xlsSheet.lastCol; c++) {
            rowData.add(xlsSheet.cell(r, c));
          }
          rows.add(rowData);
        }

        parsedWithBiff = true;
      } catch (e) {
        biffError = e;
      }

      // Fallback: some .xls files are actually OOXML (ZIP-based) with a wrong extension
      if (!parsedWithBiff) {
        try {
          final decoder = SpreadsheetDecoder.decodeBytes(bytes);
          if (decoder.tables.isNotEmpty) {
            final table = decoder.tables[decoder.tables.keys.first];
            if (table != null) {
              rows.addAll(table.rows);
            }
          }
          if (rows.isEmpty) {
            throw Exception('File parsed but contained no data.');
          }
        } catch (xlsxError) {
          throw Exception(
            'Failed to read this file.\n\n'
            'BIFF8 error: $biffError\n\n'
            'OOXML error: $xlsxError\n\n'
            'Try saving the file as .xlsx or .csv from Excel / Google Sheets.',
          );
        }
      }
    } else if (ext == 'xlsx') {
      final bytes = await file.readAsBytes();
      final decoder = SpreadsheetDecoder.decodeBytes(bytes);
      // Read the first sheet
      if (decoder.tables.isNotEmpty) {
        final table = decoder.tables[decoder.tables.keys.first];
        if (table != null) {
          rows.addAll(table.rows);
        }
      }
    } else {
      throw Exception('Unsupported file extension: $ext');
    }

    if (rows.isEmpty) {
      throw Exception('The file is empty or could not be parsed.');
    }

    // First non-empty row is headers
    int headerIndex = -1;
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].any((cell) => cell != null && cell.toString().trim().isNotEmpty)) {
        headerIndex = i;
        break;
      }
    }

    if (headerIndex == -1) {
      throw Exception('Could not find header row in the file.');
    }

    final headers = rows[headerIndex]
        .map((h) => h?.toString().trim() ?? '')
        .toList();

    List<Map<String, dynamic>> dataRows = [];
    for (int i = headerIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      // Skip completely empty rows
      if (!row.any((cell) => cell != null && cell.toString().trim().isNotEmpty)) {
        continue;
      }
      final map = <String, dynamic>{};
      for (int j = 0; j < headers.length; j++) {
        if (headers[j].isNotEmpty) {
          final val = j < row.length ? row[j] : null;
          // Excel values might not be strings, keep raw for now
          map[headers[j]] = val;
        }
      }
      dataRows.add(map);
    }

    return ParsedFile(headers: headers.where((h) => h.isNotEmpty).toList(), rows: dataRows);
  }
}

class ParsedFile {
  final List<String> headers;
  final List<Map<String, dynamic>> rows;
  ParsedFile({required this.headers, required this.rows});
}
