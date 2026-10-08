import '../models/candidate.dart';

class MockCandidates {
  static final List<Candidate> all = [
    Candidate(
      id: 'candidate-1',
      name: 'Juan Pérez',
      cvText:
          'Desarrollador Flutter con experiencia en aplicaciones móviles y Dart.',
      skills: [
        'Flutter',
        'Dart',
        'Firebase',
      ],
      experienceYears: 3,
    ),
    Candidate(
      id: 'candidate-2',
      name: 'María López',
      cvText:
          'Desarrolladora de software con experiencia en aplicaciones móviles.',
      skills: [
        'Flutter',
        'Dart',
      ],
      experienceYears: 2,
    ),
    Candidate(
      id: 'candidate-3',
      name: 'Carlos Ruiz',
      cvText:
          'Desarrollador web con experiencia en JavaScript y bases de datos.',
      skills: [
        'JavaScript',
        'SQL',
      ],
      experienceYears: 1,
    ),
  ];
}

