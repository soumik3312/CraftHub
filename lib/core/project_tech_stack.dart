import 'package:flutter/material.dart';

class ProjectTechOption {
  const ProjectTechOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
}

const kProjectTechOptions = <ProjectTechOption>[
  ProjectTechOption(id: 'flutter', label: 'Flutter', icon: Icons.flutter_dash, color: Color(0xFF69D5F7)),
  ProjectTechOption(id: 'react', label: 'React', icon: Icons.blur_circular_rounded, color: Color(0xFF66D9FF)),
  ProjectTechOption(id: 'nextjs', label: 'Next.js', icon: Icons.web_rounded, color: Color(0xFFF2F2F2)),
  ProjectTechOption(id: 'nodejs', label: 'Node.js', icon: Icons.hexagon_rounded, color: Color(0xFF8ED26C)),
  ProjectTechOption(id: 'python', label: 'Python', icon: Icons.code_rounded, color: Color(0xFFFFD343)),
  ProjectTechOption(id: 'pytorch', label: 'PyTorch', icon: Icons.psychology_alt_rounded, color: Color(0xFFFF7A59)),
  ProjectTechOption(id: 'tensorflow', label: 'TensorFlow', icon: Icons.memory_rounded, color: Color(0xFFFFA14A)),
  ProjectTechOption(id: 'rust', label: 'Rust', icon: Icons.settings_rounded, color: Color(0xFFD9D2C3)),
  ProjectTechOption(id: 'docker', label: 'Docker', icon: Icons.inventory_2_rounded, color: Color(0xFF4FC3F7)),
  ProjectTechOption(id: 'aws', label: 'AWS', icon: Icons.cloud_queue_rounded, color: Color(0xFFFFB84D)),
  ProjectTechOption(id: 'postgresql', label: 'PostgreSQL', icon: Icons.storage_rounded, color: Color(0xFF6BB6FF)),
  ProjectTechOption(id: 'mongodb', label: 'MongoDB', icon: Icons.data_object_rounded, color: Color(0xFF7ED957)),
  ProjectTechOption(id: 'firebase', label: 'Firebase', icon: Icons.local_fire_department_rounded, color: Color(0xFFFFCA28)),
  ProjectTechOption(id: 'java', label: 'Java', icon: Icons.coffee_rounded, color: Color(0xFFFF8A65)),
  ProjectTechOption(id: 'kotlin', label: 'Kotlin', icon: Icons.android_rounded, color: Color(0xFFB388FF)),
  ProjectTechOption(id: 'swift', label: 'Swift', icon: Icons.phone_iphone_rounded, color: Color(0xFFFF8A65)),
];

ProjectTechOption? projectTechOptionById(String id) {
  final normalized = id.trim().toLowerCase();
  for (final option in kProjectTechOptions) {
    if (option.id == normalized) return option;
  }
  return null;
}

List<ProjectTechOption> projectTechForIds(List<dynamic> ids) {
  return ids
      .map((entry) => projectTechOptionById('$entry'))
      .whereType<ProjectTechOption>()
      .toList();
}
