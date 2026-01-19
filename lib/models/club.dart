class Club {
  final int id;
  final String authClubId;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? email;
  final bool isActive;
  final DateTime? createdAt;
  final int? upcomingEvents;
  final int? completedEvents;
  final int? totalParticipants;

  Club({
    required this.id,
    required this.authClubId,
    required this.name,
    this.description,
    this.logoUrl,
    this.email,
    this.isActive = true,
    this.createdAt,
    this.upcomingEvents,
    this.completedEvents,
    this.totalParticipants,
  });

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      id: json['id'] is String ? int.parse(json['id']) : json['id'] as int,
      authClubId: json['authClubId'] as String? ?? '',
      name: json['name'] as String,
      description: json['description'] as String?,
      logoUrl: json['logoUrl'] as String?,
      email: json['email'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      upcomingEvents: _parseInt(json['upcomingEvents']),
      completedEvents: _parseInt(json['completedEvents']),
      totalParticipants: _parseInt(json['totalParticipants']),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authClubId': authClubId,
      'name': name,
      'description': description,
      'logoUrl': logoUrl,
      'email': email,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'upcomingEvents': upcomingEvents,
      'completedEvents': completedEvents,
      'totalParticipants': totalParticipants,
    };
  }
}

class ClubProfile {
  final int id;
  final int clubId;
  final String? aboutClub;
  final String? mission;
  final String? vision;
  final String? achievements;
  final String? benefits;
  final String? contactPhone;
  final String? address;
  final String? websiteUrl;
  final Map<String, String>? socialLinks;
  final int? establishedYear;
  final int totalEventHosted;
  final DateTime? updatedAt;

  ClubProfile({
    required this.id,
    required this.clubId,
    this.aboutClub,
    this.mission,
    this.vision,
    this.achievements,
    this.benefits,
    this.contactPhone,
    this.address,
    this.websiteUrl,
    this.socialLinks,
    this.establishedYear,
    this.totalEventHosted = 0,
    this.updatedAt,
  });

  factory ClubProfile.fromJson(Map<String, dynamic> json) {
    return ClubProfile(
      id: _parseIntRequired(json['id']),
      clubId: _parseIntRequired(json['clubId']),
      aboutClub: json['aboutClub'] as String?,
      mission: json['mission'] as String?,
      vision: json['vision'] as String?,
      achievements: json['achievements'] as String?,
      benefits: json['benefits'] as String?,
      contactPhone: json['contactPhone'] as String?,
      address: json['address'] as String?,
      websiteUrl: json['websiteUrl'] as String?,
      socialLinks: json['socialLinks'] != null
          ? Map<String, String>.from(json['socialLinks'] as Map)
          : null,
      establishedYear: Club._parseInt(json['establishedYear']),
      totalEventHosted: Club._parseInt(json['totalEventHosted']) ?? 0,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  static int _parseIntRequired(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.parse(value);
    throw FormatException('Cannot parse $value as int');
  }
}
