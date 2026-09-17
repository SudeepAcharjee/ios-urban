
class AdModel {
  final String id;
  final String title;
  final String subtitle;
  final String tag;
  final String imageUrl;
  final String status;
  final String? link;

  AdModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.imageUrl,
    required this.status,
    this.link,
  });

  factory AdModel.fromMap(Map<String, dynamic> map, String id) {
    return AdModel(
      id: id,
      title: map['title'] ?? '',
      subtitle: map['subtitle'] ?? '',
      tag: map['tag'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      status: map['status'] ?? 'active',
      link: map['link'],
    );
  }
}
