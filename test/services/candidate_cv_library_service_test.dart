import 'package:flutter_test/flutter_test.dart';
import 'package:neogenesis_ai/data/models/candidate_cv_library_item.dart';
import 'package:neogenesis_ai/data/models/candidate_model.dart';
import 'package:neogenesis_ai/data/services/candidate_cv_library_service.dart';

void main() {
  group('CandidateCvLibraryService', () {
    test('extrae habilidades de listas y texto separado', () {
      final listCandidate = _candidate({
        'skills': ['Flutter', 'Dart', 'Flutter'],
      });
      final textCandidate = _candidate({'skills': 'Excel, Nómina; SQL'});

      expect(CandidateCvLibraryService.skillsFor(listCandidate), [
        'Flutter',
        'Dart',
      ]);
      expect(CandidateCvLibraryService.skillsFor(textCandidate), [
        'Excel',
        'Nómina',
        'SQL',
      ]);
    });

    test('extrae cargos del resumen y del historial laboral', () {
      final candidate = _candidate({
        'position': 'Analista',
        'experience': [
          {'title': 'Asistente contable'},
          {'job_title': 'Analista'},
        ],
      });

      expect(CandidateCvLibraryService.positionsFor(candidate), [
        'Analista',
        'Asistente contable',
      ]);
    });

    test('busca perfiles por nombre, correo, habilidad o cargo', () {
      final items = [
        _item(
          name: 'Ana García',
          email: 'ana@example.com',
          position: 'Analista',
          skills: ['Excel'],
        ),
        _item(name: 'Luis Pérez', email: 'luis@example.com'),
      ];

      expect(
        CandidateCvLibraryService.filterCandidates(
          items: items,
          query: 'ANA@EXAMPLE',
        ).map((item) => item.candidate.fullName),
        ['Ana García'],
      );
      expect(
        CandidateCvLibraryService.filterCandidates(
          items: items,
          query: 'garcia',
        ).map((item) => item.candidate.fullName),
        ['Ana García'],
      );
      expect(
        CandidateCvLibraryService.filterCandidates(
          items: items,
          query: 'excel',
        ).map((item) => item.candidate.fullName),
        ['Ana García'],
      );
      expect(
        CandidateCvLibraryService.filterCandidates(
          items: items,
          query: 'analista',
        ).map((item) => item.candidate.fullName),
        ['Ana García'],
      );
      expect(CandidateCvLibraryService.filterCandidates(items: items), items);
    });

    test('distingue CV registrado de perfil sin CV', () {
      final profileWithResume = _item(
        name: 'Ana García',
        email: 'ana@example.com',
        skills: ['Excel'],
      );
      final profileWithoutResume = _item(
        name: 'Luis Pérez',
        email: 'luis@example.com',
      );

      expect(profileWithResume.hasResume, isTrue);
      expect(profileWithoutResume.hasResume, isFalse);
    });

    test('reconoce los campos guardados por el formulario de hoja de vida', () {
      final candidate = _candidate({
        'experience_years': 2.5,
        'education_level': 'bachelor',
        'skills': ['Flutter'],
        'additional_info': 'Disponibilidad inmediata',
      });

      expect(
        CandidateCvLibraryItem.hasResumeData(candidate.resumeData),
        isTrue,
      );
      expect(CandidateCvLibraryService.skillsFor(candidate), ['Flutter']);
    });

    test('asocia CV al usuario por correo cuando falta created_by', () {
      final profiles = {
        'user-1': {'nombre': 'Ana García', 'email': 'ana@example.com'},
        'user-2': {'nombre': 'Luis Pérez', 'email': 'luis@example.com'},
      };

      expect(
        CandidateCvLibraryService.userIdForCandidate({
          'id': 'candidate-1',
          'email': 'ANA@example.com',
        }, profiles),
        'user-1',
      );
    });

    test('usa el nombre solo si identifica un único perfil', () {
      final uniqueProfiles = {
        'user-1': {'nombre': 'Ana García', 'email': 'ana@example.com'},
      };
      final ambiguousProfiles = {
        ...uniqueProfiles,
        'user-2': {'nombre': 'Ana García', 'email': 'ana2@example.com'},
      };

      expect(
        CandidateCvLibraryService.userIdForCandidate({
          'id': 'candidate-1',
          'full_name': 'Ana Garcia',
        }, uniqueProfiles),
        'user-1',
      );
      expect(
        CandidateCvLibraryService.userIdForCandidate({
          'id': 'candidate-1',
          'full_name': 'Ana García',
        }, ambiguousProfiles),
        isNull,
      );
    });
  });
}

CandidateModel _candidate(Map<String, dynamic> resumeData) => CandidateModel(
  id: 'candidate-1',
  fullName: 'Ana García',
  email: 'ana@example.com',
  phone: null,
  resumeData: resumeData,
);

CandidateCvLibraryItem _item({
  required String name,
  required String email,
  String? position,
  List<String> skills = const [],
}) {
  final candidate = CandidateModel(
    id: name,
    fullName: name,
    email: email,
    phone: null,
    profilePosition: position,
    resumeData: skills.isEmpty ? const {} : {'skills': skills},
  );
  return CandidateCvLibraryItem(
    candidate: candidate,
    positions: position == null ? const [] : [position],
    skills: skills,
  );
}
