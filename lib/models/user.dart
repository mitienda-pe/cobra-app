class User {
  final String id;
  final String email;
  final String name;
  final String? phoneNumber; 
  final String? role;
  final String? profilePicture;
  final Organization? organization;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.phoneNumber, 
    this.role,
    this.profilePicture,
    this.organization,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Verificar si la respuesta sigue el nuevo formato
    if (json.containsKey('data') && json['data'] is Map<String, dynamic> && 
        json['data'].containsKey('user')) {
      final userData = json['data']['user'] as Map<String, dynamic>;
      
      // Crear la organización si existe
      Organization? org;
      if (userData.containsKey('organization') && 
          userData['organization'] is Map<String, dynamic>) {
        org = Organization.fromJson(userData['organization']);
      }
      
      return User(
        id: userData['id'].toString(),
        email: userData['email'] ?? '',
        name: userData['name'] ?? '',
        phoneNumber: userData['phone'], 
        role: userData['role'],
        profilePicture: userData['profile_picture'],
        organization: org,
      );
    }
    
    // Formato anterior para compatibilidad
    Organization? org;
    if (json.containsKey('organization') && 
        json['organization'] is Map<String, dynamic>) {
      org = Organization.fromJson(json['organization']);
    }
    
    return User(
      id: json['id'].toString(),
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      phoneNumber: json['phone'] ?? json['phone_number'], 
      role: json['role'],
      profilePicture: json['profile_picture'],
      organization: org,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'email': email,
      'name': name,
      'phone': phoneNumber, 
      'role': role,
      'profile_picture': profilePicture,
    };
    
    if (organization != null) {
      data['organization'] = organization!.toJson();
    }
    
    return data;
  }
}

class Organization {
  final int id;
  final String name;
  final String? code;

  Organization({
    required this.id,
    required this.name,
    this.code,
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'],
      name: json['name'] ?? '',
      code: json['code'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
    };
  }
}
