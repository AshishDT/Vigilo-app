import '../enums/brief_type.dart';

class BriefingItem {
  final BriefType type;
  final String title;
  final String path;
  final DateTime? createdAt;
  final String? uploadedBy;

  BriefingItem({
    required this.type,
    required this.title,
    required this.path,
    required this.createdAt,
    this.uploadedBy,
  });

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'title': title,
    'path': path,
    'createdAt': createdAt?.millisecondsSinceEpoch,
    'uploadedBy': uploadedBy,
  };

  static BriefingItem fromJson(Map<String, dynamic> m) => BriefingItem(
    type: BriefType.values[(m['type'] ?? 0) as int],
    title: m['title'],
    path: m['path'],
    createdAt: (m['createdAt'] == null)
        ? null
        : DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
    uploadedBy: m['uploadedBy'] as String?,
  );
}
