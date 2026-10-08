import '../models/candidate_model.dart';
import '../models/vacancy_model.dart';

/// Pure evaluator for vacancy minimum criteria against HU-11 resume data.
class CandidateCriteriaEvaluator {
  const CandidateCriteriaEvaluator._();

  static const _educationRank = {
    'none': 0,
    'secondary': 1,
    'technical': 2,
    'bachelor': 3,
    'postgraduate': 4,
    'doctorate': 5,
  };

  static const _educationLabels = {
    0: 'no identificada',
    1: 'secundaria',
    2: 'técnica/tecnológica',
    3: 'universitaria',
    4: 'posgrado',
    5: 'doctorado',
  };

  static List<String> exclusionReasonsFor(
    CandidateModel candidate,
    VacancyModel vacancy,
  ) {
    final reasons = <String>[];
    final experienceYears = _experienceYears(
      candidate.resumeData['experience'],
    );
    if (experienceYears + 0.0001 < vacancy.minExperienceYears) {
      reasons.add(
        'Experiencia: ${experienceYears.toStringAsFixed(1)} años; se requieren ${vacancy.minExperienceYears.toStringAsFixed(1)}.',
      );
    }

    final candidateSkills = _asStringList(
      candidate.resumeData['skills'],
    ).map(_normalize).where((skill) => skill.isNotEmpty).toList();
    final missingSkills = vacancy.requiredSkills.where((requiredSkill) {
      final required = _normalize(requiredSkill);
      return required.isNotEmpty &&
          !candidateSkills.any((skill) => _matchesSkill(skill, required));
    }).toList();
    if (missingSkills.isNotEmpty) {
      reasons.add('Habilidades faltantes: ${missingSkills.join(', ')}.');
    }

    final requiredLevel = _educationRank[vacancy.minEducationLevel] ?? 0;
    final candidateLevel = _highestEducationRank(
      candidate.resumeData['education'],
    );
    if (candidateLevel < requiredLevel) {
      reasons.add(
        'Formación: ${_educationLabels[candidateLevel]}; se requiere ${_educationLabels[requiredLevel]}.',
      );
    }
    return reasons;
  }

  static bool _matchesSkill(String candidateSkill, String requiredSkill) {
    if (candidateSkill == requiredSkill) return true;
    final candidateWords = ' $candidateSkill ';
    final requiredWords = ' $requiredSkill ';
    return candidateWords.contains(requiredWords);
  }

  static List<String> _asStringList(dynamic value) => value is List
      ? value
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList()
      : const [];

  static int _highestEducationRank(dynamic value) {
    if (value is! List) return 0;
    var highest = 0;
    for (final item in value.whereType<Map>()) {
      final text = _normalize('${item['degree'] ?? ''} ${item['field'] ?? ''}');
      final rank = _educationLevelRank(text);
      if (rank > highest) highest = rank;
    }
    return highest;
  }

  static int _educationLevelRank(String text) {
    if (_containsAny(text, ['doctorado', 'phd', 'doctor of'])) return 5;
    if (_containsAny(text, [
      'maestria',
      'master',
      'posgrado',
      'especializacion',
    ])) {
      return 4;
    }
    if (_containsAny(text, [
      'licenciatura',
      'ingenieria',
      'bachelor',
      'grado',
      'universitario',
    ])) {
      return 3;
    }
    if (_containsAny(text, [
      'tecnico',
      'tecnologo',
      'tecnologica',
      'technical',
      'technician',
    ])) {
      return 2;
    }
    if (_containsAny(text, [
      'secundaria',
      'bachiller',
      'high school',
      'educacion media',
    ])) {
      return 1;
    }
    return 0;
  }

  static bool _containsAny(String text, List<String> values) =>
      values.any(text.contains);

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll(RegExp(r'[^a-z0-9+#.]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static double _experienceYears(dynamic value) {
    if (value is! List) return 0;
    final intervals = <(int, int)>[];
    for (final item in value.whereType<Map>()) {
      final start = _parseYearMonth(item['start_date']?.toString() ?? '');
      if (start == null) continue;

      final rawEnd = item['end_date']?.toString().trim() ?? '';
      final DateTime? end;
      if (rawEnd.isEmpty) {
        // Missing extraction data is not assumed to mean a current position.
        end = start;
      } else if (_isCurrentPosition(rawEnd)) {
        end = DateTime.now();
      } else {
        end = _parseYearMonth(rawEnd);
      }
      if (end == null) continue;

      final startIndex = start.year * 12 + start.month - 1;
      final endIndex = end.year * 12 + end.month - 1;
      if (endIndex >= startIndex) intervals.add((startIndex, endIndex));
    }
    if (intervals.isEmpty) return 0;

    intervals.sort((a, b) => a.$1.compareTo(b.$1));
    var months = 0;
    var rangeStart = intervals.first.$1;
    var rangeEnd = intervals.first.$2;
    for (final interval in intervals.skip(1)) {
      if (interval.$1 <= rangeEnd + 1) {
        if (interval.$2 > rangeEnd) rangeEnd = interval.$2;
      } else {
        months += rangeEnd - rangeStart + 1;
        rangeStart = interval.$1;
        rangeEnd = interval.$2;
      }
    }
    months += rangeEnd - rangeStart + 1;
    return months / 12;
  }

  static bool _isCurrentPosition(String value) => _containsAny(
    _normalize(value),
    ['present', 'presente', 'actualidad', 'actual', 'current', 'ongoing'],
  );

  static DateTime? _parseYearMonth(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final iso = DateTime.tryParse(text);
    if (iso != null) return iso;

    final yearFirst = RegExp(r'^(\d{4})(?:[-/](\d{1,2}))?$').firstMatch(text);
    if (yearFirst != null) {
      return _dateFromParts(
        int.parse(yearFirst.group(1)!),
        int.tryParse(yearFirst.group(2) ?? '1') ?? 1,
      );
    }

    final monthFirst = RegExp(r'^(\d{1,2})[/-](\d{4})$').firstMatch(text);
    if (monthFirst != null) {
      return _dateFromParts(
        int.parse(monthFirst.group(2)!),
        int.parse(monthFirst.group(1)!),
      );
    }

    final namedMonth = RegExp(
      r'^([a-záéíóúüñ]+)[ ,/-]+(\d{4})$',
      caseSensitive: false,
    ).firstMatch(text);
    if (namedMonth == null) return null;
    final month = _monthNumber(_normalize(namedMonth.group(1)!));
    return month == null
        ? null
        : _dateFromParts(int.parse(namedMonth.group(2)!), month);
  }

  static DateTime? _dateFromParts(int year, int month) {
    if (month < 1 || month > 12) return null;
    return DateTime(year, month);
  }

  static int? _monthNumber(String month) {
    const months = {
      'jan': 1,
      'january': 1,
      'ene': 1,
      'enero': 1,
      'feb': 2,
      'february': 2,
      'febrero': 2,
      'mar': 3,
      'march': 3,
      'marzo': 3,
      'apr': 4,
      'april': 4,
      'abr': 4,
      'abril': 4,
      'may': 5,
      'mayo': 5,
      'jun': 6,
      'june': 6,
      'junio': 6,
      'jul': 7,
      'july': 7,
      'julio': 7,
      'aug': 8,
      'august': 8,
      'ago': 8,
      'agosto': 8,
      'sep': 9,
      'september': 9,
      'septiembre': 9,
      'oct': 10,
      'october': 10,
      'octubre': 10,
      'nov': 11,
      'november': 11,
      'noviembre': 11,
      'dec': 12,
      'december': 12,
      'dic': 12,
      'diciembre': 12,
    };
    return months[month];
  }
}
