class Job {
  final String id;
  final String title;
  final String description;
  final List<String> requiredSkills;
  final double requiredExperienceYears;

  Job({
    required this.id,
    required this.title,
    required this.description,
    required this.requiredSkills,
    required this.requiredExperienceYears,
  });
}
