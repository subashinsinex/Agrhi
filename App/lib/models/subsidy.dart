class Subsidy {
  final String id;
  final String title;
  final String description;
  final String link;
  final String stateName;

  Subsidy({
    required this.id,
    required this.title,
    required this.description,
    required this.link,
    required this.stateName,
  });

  factory Subsidy.fromJson(Map<String, dynamic> json) {
    return Subsidy(
      id: json['id']?.toString() ?? '0',
      title: json['title'] ?? 'Untitled',
      description: json['description'] ?? '',
      link: json['link'] ?? '',
      stateName: json['state_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'link': link,
      'state_name': stateName,
    };
  }
}
