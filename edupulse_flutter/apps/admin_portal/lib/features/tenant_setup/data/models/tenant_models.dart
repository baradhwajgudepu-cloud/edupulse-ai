class TenantDto {
  final String id;
  final String name;
  final String? displayName;
  final String code;
  final String subdomain;
  final String email;
  final String? phone;
  final String? website;
  final String? logoUrl;
  final String timezone;
  final String currency;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final String? pan;
  final String? gstin;
  final bool isActive;
  final String status;

  TenantDto({
    required this.id,
    required this.name,
    this.displayName,
    required this.code,
    required this.subdomain,
    required this.email,
    this.phone,
    this.website,
    this.logoUrl,
    required this.timezone,
    required this.currency,
    this.address,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.pan,
    this.gstin,
    required this.isActive,
    required this.status,
  });

  factory TenantDto.fromJson(Map<String, dynamic> json) {
    return TenantDto(
      id: json['id'] as String,
      name: json['name'] as String,
      displayName: json['display_name'] as String?,
      code: json['code'] as String,
      subdomain: json['subdomain'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      logoUrl: json['logo_url'] as String?,
      timezone: json['timezone'] as String? ?? 'Asia/Kolkata',
      currency: json['currency'] as String? ?? 'INR',
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String? ?? 'India',
      postalCode: json['postal_code'] as String?,
      pan: json['pan'] as String?,
      gstin: json['gstin'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      status: json['status'] as String? ?? 'ACTIVE',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
      'code': code,
      'subdomain': subdomain,
      'email': email,
      'phone': phone,
      'website': website,
      'logo_url': logoUrl,
      'timezone': timezone,
      'currency': currency,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'postal_code': postalCode,
      'pan': pan,
      'gstin': gstin,
      'is_active': isActive,
      'status': status,
    };
  }
}

class TenantCreateRequest {
  final String name;
  final String? displayName;
  final String code;
  final String subdomain;
  final String email;
  final String? phone;
  final String? website;
  final String? logoUrl;
  final String timezone;
  final String currency;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final String? pan;
  final String? gstin;
  final bool isActive;
  final String status;

  TenantCreateRequest({
    required this.name,
    this.displayName,
    required this.code,
    required this.subdomain,
    required this.email,
    this.phone,
    this.website,
    this.logoUrl,
    this.timezone = 'Asia/Kolkata',
    this.currency = 'INR',
    this.address,
    this.city,
    this.state,
    this.country = 'India',
    this.postalCode,
    this.pan,
    this.gstin,
    this.isActive = true,
    this.status = 'ACTIVE',
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'display_name': displayName,
      'code': code,
      'subdomain': subdomain,
      'email': email,
      'phone': phone,
      'website': website,
      'logo_url': logoUrl,
      'timezone': timezone,
      'currency': currency,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'postal_code': postalCode,
      'pan': pan,
      'gstin': gstin,
      'is_active': isActive,
      'status': status,
    };
  }
}

class TenantUpdateRequest {
  final String? name;
  final String? displayName;
  final String? code;
  final String? subdomain;
  final String? email;
  final String? phone;
  final String? website;
  final String? logoUrl;
  final String? timezone;
  final String? currency;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final String? pan;
  final String? gstin;
  final bool? isActive;
  final String? status;

  TenantUpdateRequest({
    this.name,
    this.displayName,
    this.code,
    this.subdomain,
    this.email,
    this.phone,
    this.website,
    this.logoUrl,
    this.timezone,
    this.currency,
    this.address,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.pan,
    this.gstin,
    this.isActive,
    this.status,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    if (displayName != null) data['display_name'] = displayName;
    if (code != null) data['code'] = code;
    if (subdomain != null) data['subdomain'] = subdomain;
    if (email != null) data['email'] = email;
    if (phone != null) data['phone'] = phone;
    if (website != null) data['website'] = website;
    if (logoUrl != null) data['logo_url'] = logoUrl;
    if (timezone != null) data['timezone'] = timezone;
    if (currency != null) data['currency'] = currency;
    if (address != null) data['address'] = address;
    if (city != null) data['city'] = city;
    if (state != null) data['state'] = state;
    if (country != null) data['country'] = country;
    if (postalCode != null) data['postal_code'] = postalCode;
    if (pan != null) data['pan'] = pan;
    if (gstin != null) data['gstin'] = gstin;
    if (isActive != null) data['is_active'] = isActive;
    if (status != null) data['status'] = status;
    return data;
  }
}
