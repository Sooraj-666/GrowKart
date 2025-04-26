class DeliveryAddress {
  final String street;
  final String landmark;
  final String city;
  final String state;
  final String pincode;

  DeliveryAddress({
    required this.street,
    required this.landmark,
    required this.city,
    required this.state,
    required this.pincode,
  });

  Map<String, dynamic> toMap() {
    return {
      'street': street,
      'landmark': landmark,
      'city': city,
      'state': state,
      'pincode': pincode,
    };
  }

  factory DeliveryAddress.fromMap(Map<String, dynamic> map) {
    return DeliveryAddress(
      street: map['street'] ?? '',
      landmark: map['landmark'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      pincode: map['pincode'] ?? '',
    );
  }
}
