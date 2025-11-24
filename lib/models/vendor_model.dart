class VendorModel {
  final bool? approved;
  final String vendorId;
  final String bussinessName;
  final String city;
  final String country;
  final String address;
  final String zipcode;
  final String email;
  final String image;
  final String phone;
  final String category;
  final String state;
  final String taxStatus;
  final String taxNo;
  final String bankName;
  final String bankAccount;
  final String promptPayId;
  final Map<String, dynamic>?
  storeHours; // ใหม่: { 'monday': {'open': '09:00', 'close': '18:00'} }

  VendorModel({
    this.approved,
    required this.vendorId,
    required this.bussinessName,
    required this.city,
    required this.country,
    required this.address,
    required this.zipcode,
    required this.email,
    required this.image,
    required this.phone,
    required this.category,
    required this.state,
    required this.taxStatus,
    required this.taxNo,
    required this.bankName,
    required this.bankAccount,
    required this.promptPayId,
    this.storeHours, // ใหม่
  });

  factory VendorModel.fromJson(Map<String, Object?> json) {
    print('VendorModel JSON Input: $json');
    bool? approved;
    if (json['approved'] is bool) {
      approved = json['approved'] as bool;
    } else if (json['approved'] is String) {
      approved = json['approved'].toString().toLowerCase() == 'true';
    } else {
      approved = false;
    }
    return VendorModel(
      approved: approved,
      vendorId: json['vendorId'] as String? ?? '',
      bussinessName: json['bussinessName'] as String? ?? 'Unknown',
      city: json['city'] as String? ?? '',
      country: json['country'] as String? ?? '',
      address: json['address'] as String? ?? '',
      zipcode: json['vzipcode'] as String? ?? '',
      email: json['email'] as String? ?? '',
      image: json['image'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      state: json['state'] as String? ?? '',
      category: json['category'] as String? ?? '',
      taxStatus: json['taxStatus'] as String? ?? '',
      taxNo: json['taxNo'] as String? ?? '',
      bankName: json['bankName'] as String? ?? '',
      bankAccount: json['bankAccount'] as String? ?? '',
      promptPayId: json['promptPayId'] as String? ?? '',
      storeHours: json['storeHours'] as Map<String, dynamic>?, // ใหม่
    );
  }

  Map<String, Object?> toJson() {
    return {
      'approved': approved,
      'vendorId': vendorId,
      'bussinessName': bussinessName,
      'city': city,
      'country': country,
      'address': address,
      'vzipcode': zipcode,
      'email': email,
      'image': image,
      'phone': phone,
      'state': state,
      'taxStatus': taxStatus,
      'category': category,
      'taxNo': taxNo,
      'bankName': bankName,
      'bankAccount': bankAccount,
      'promptPayId': promptPayId,
      'storeHours': storeHours, // ใหม่
    };
  }
}
