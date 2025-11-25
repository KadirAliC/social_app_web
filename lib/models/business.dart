class Business {
  final String id;
  String name;
  String email;
  String? imagePath;
  DateTime? createDate;
  DateTime? lastLogin;
  int? capacity;
  String? address;
  String? addressDescription;
  double? latitude;
  double? longitude;
  String? cityName;
  String? districtName;

  Business({
    required this.id,
    required this.name,
    required this.email,
    this.imagePath,
    this.createDate,
    this.lastLogin,
    this.capacity,
    this.address,
    this.addressDescription,
    this.latitude,
    this.longitude,
    this.cityName,
    this.districtName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_name': name,
      'business_email': email,
      'business_image_path': imagePath,
      'business_create_date': createDate?.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
      'capacity': capacity,
      'address': address,
      'addressDescription': addressDescription,
      'latitude': latitude,
      'longitude': longitude,
      'city_name': cityName,
      'district_name': districtName,
    };
  }

  factory Business.fromMap(Map<String, dynamic> map, String id) {
    return Business(
      id: id,
      name: map['business_name'] ?? '',
      email: map['business_email'] ?? '',
      imagePath: map['business_image_path'],
      createDate: map['business_create_date'] != null 
          ? DateTime.parse(map['business_create_date']) 
          : null,
      lastLogin: map['last_login'] != null 
          ? DateTime.parse(map['last_login']) 
          : null,
      capacity: map['capacity'],
      address: map['address'],
      addressDescription: map['addressDescription'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      cityName: map['city_name'],
      districtName: map['district_name'],
    );
  }
}
