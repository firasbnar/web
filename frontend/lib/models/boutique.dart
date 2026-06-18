import '../core/url_utils.dart';

class Boutique {
  final String id;
  final String name;
  final String slug;
  final String? logoUrl;
  final String? description;
  final String? email;
  final String? phone;
  final String? address;
  final String? currency;
  final String? language;
  final String? timezone;
  final bool isActive;
  final String? customDomain;
  final String? primaryColor;
  final String? secondaryColor;
  final String? seoTitle;
  final String? seoDescription;
  final String? seoKeywords;
  final String? ogImageUrl;
  final String? facebookUrl;
  final String? instagramUrl;
  final String? tiktokUrl;
  final String? twitterUrl;
  final String? linkedinUrl;
  final String? whatsappNumber;
  final bool enableCod;
  final bool enableJax;
  final bool enableIntigo;
  final bool enableAdeex;

  // Storefront config
  final String? storeConfig;
  final String? headerColor;
  final String? footerColor;
  final String? bodyColor;
  final String? cardProductColor;
  final String? buttonColor;
  final String? topBarColor;
  final String? textColor;
  final String? announcementText;
  final double? deliveryFees;
  final double? tva;
  final bool simpleCheckout;
  final bool cashOnDelivery;
  final String? facebookPixelId;
  final String? googleAnalyticsId;

  // New store settings
  final String? bannerUrl;
  final String? faviconUrl;
  final String? fontFamily;
  final bool darkMode;
  final bool stripeEnabled;
  final String? stripeStatus;
  final String? stripePublishableKey;
  final double? freeShippingThreshold;
  final int? estimatedDeliveryDays;
  final bool enableLocalPickup;
  final bool enableEmailNotifications;
  final bool enableSmsNotifications;
  final bool enablePushNotifications;
  final bool enableMarketingEmails;
  final bool enableOrderAlerts;
  final bool clientMessagingEnabled;
  final bool teamEnabled;
  final String? telegramChatId;
  final bool telegramEnabled;

  final String? storeStatus;
  final String? publicationStatus;
  final String? frozenAt;
  final String? freezeReason;
  final bool isPublished;
  final String? publishedAt;
  final String? publicUrl;
  final bool ownerAccess;
  final String? currentUserRole;
  final List<String> currentUserPermissions;

  Boutique({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
    this.description,
    this.email,
    this.phone,
    this.address,
    this.currency,
    this.language,
    this.timezone,
    required this.isActive,
    this.customDomain,
    this.primaryColor,
    this.secondaryColor,
    this.seoTitle,
    this.seoDescription,
    this.seoKeywords,
    this.ogImageUrl,
    this.facebookUrl,
    this.instagramUrl,
    this.tiktokUrl,
    this.twitterUrl,
    this.linkedinUrl,
    this.whatsappNumber,
    this.enableCod = true,
    this.enableJax = false,
    this.enableIntigo = false,
    this.enableAdeex = false,
    this.storeConfig,
    this.headerColor,
    this.footerColor,
    this.bodyColor,
    this.cardProductColor,
    this.buttonColor,
    this.topBarColor,
    this.textColor,
    this.announcementText,
    this.deliveryFees,
    this.tva,
    this.simpleCheckout = false,
    this.cashOnDelivery = true,
    this.facebookPixelId,
    this.googleAnalyticsId,
    this.bannerUrl,
    this.faviconUrl,
    this.fontFamily,
    this.darkMode = false,
    this.stripeEnabled = false,
    this.stripeStatus,
    this.stripePublishableKey,
    this.freeShippingThreshold,
    this.estimatedDeliveryDays,
    this.enableLocalPickup = false,
    this.enableEmailNotifications = true,
    this.enableSmsNotifications = false,
    this.enablePushNotifications = true,
    this.enableMarketingEmails = false,
    this.enableOrderAlerts = true,
    this.clientMessagingEnabled = true,
    this.teamEnabled = false,
    this.telegramChatId,
    this.telegramEnabled = false,
    this.storeStatus,
    this.publicationStatus,
    this.frozenAt,
    this.freezeReason,
    this.isPublished = false,
    this.publishedAt,
    this.publicUrl,
    this.ownerAccess = false,
    this.currentUserRole,
    this.currentUserPermissions = const [],
  });

  factory Boutique.fromJson(Map<String, dynamic> json) => Boutique(
    id: json['id'].toString(),
    name: json['name'] ?? '',
    slug: json['slug'] ?? '',
    logoUrl: normalizeRemoteUrl(json['logoUrl']),
    description: json['description'],
    email: json['email'],
    phone: json['phone'],
    address: json['address'],
    currency: json['currency'],
    language: json['language'],
    timezone: json['timezone'],
    isActive: json['isActive'] ?? true,
    customDomain: json['customDomain'],
    primaryColor: json['primaryColor'],
    secondaryColor: json['secondaryColor'],
    seoTitle: json['seoTitle'],
    seoDescription: json['seoDescription'],
    seoKeywords: json['seoKeywords'],
    ogImageUrl: normalizeRemoteUrl(json['ogImageUrl']),
    facebookUrl: json['facebookUrl'],
    instagramUrl: json['instagramUrl'],
    tiktokUrl: json['tiktokUrl'],
    twitterUrl: json['twitterUrl'],
    linkedinUrl: json['linkedinUrl'],
    whatsappNumber: json['whatsappNumber'],
    enableCod: json['enableCod'] ?? true,
    enableJax: json['enableJax'] ?? false,
    enableIntigo: json['enableIntigo'] ?? false,
    enableAdeex: json['enableAdeex'] ?? false,
    storeConfig: json['storeConfig'],
    headerColor: json['headerColor'] ?? json['header_color'],
    footerColor: json['footerColor'] ?? json['footer_color'],
    bodyColor: json['bodyColor'] ?? json['body_color'],
    cardProductColor: json['cardProductColor'] ?? json['card_product_color'],
    buttonColor: json['buttonColor'] ?? json['button_color'],
    topBarColor: json['topBarColor'] ?? json['top_bar_color'],
    textColor: json['textColor'] ?? json['text_color'],
    announcementText: json['announcementText'] ?? json['announcement_text'],
    deliveryFees: (json['deliveryFees'] ?? json['delivery_fees'] ?? 7.0).toDouble(),
    tva: (json['tva'] ?? 0.0).toDouble(),
    simpleCheckout: json['simpleCheckout'] ?? json['simple_checkout'] ?? false,
    cashOnDelivery: json['cashOnDelivery'] ?? json['cash_on_delivery'] ?? true,
    facebookPixelId: json['facebookPixelId'] ?? json['facebook_pixel_id'],
    googleAnalyticsId: json['googleAnalyticsId'] ?? json['google_analytics_id'],
    bannerUrl: normalizeRemoteUrl(json['bannerUrl']),
    faviconUrl: json['faviconUrl'],
    fontFamily: json['fontFamily'],
    darkMode: json['darkMode'] ?? false,
    stripeEnabled: json['stripeEnabled'] ?? ((json['stripeStatus'] ?? json['stripe_status'])?.toString().toLowerCase() == 'active' || (json['stripeStatus'] ?? json['stripe_status'])?.toString().toLowerCase() == 'enabled'),
    stripeStatus: json['stripeStatus'] ?? json['stripe_status'],
    stripePublishableKey: json['stripePublishableKey'],
    freeShippingThreshold: (json['freeShippingThreshold'] as num?)?.toDouble(),
    estimatedDeliveryDays: json['estimatedDeliveryDays'],
    enableLocalPickup: json['enableLocalPickup'] ?? false,
    enableEmailNotifications: json['enableEmailNotifications'] ?? true,
    enableSmsNotifications: json['enableSmsNotifications'] ?? false,
    enablePushNotifications: json['enablePushNotifications'] ?? true,
    enableMarketingEmails: json['enableMarketingEmails'] ?? false,
    enableOrderAlerts: json['enableOrderAlerts'] ?? true,
    clientMessagingEnabled: json['clientMessagingEnabled'] ?? true,
    teamEnabled: json['teamEnabled'] ?? false,
    telegramChatId: json['telegramChatId'],
    telegramEnabled: json['telegramEnabled'] ?? false,
    storeStatus: json['storeStatus'],
    publicationStatus: json['publicationStatus'],
    frozenAt: json['frozenAt'],
    freezeReason: json['freezeReason'],
    isPublished: json['isPublished'] ?? false,
    publishedAt: json['publishedAt'],
    publicUrl: json['publicUrl'],
    ownerAccess: json['ownerAccess'] == true,
    currentUserRole: json['currentUserRole'],
    currentUserPermissions: (json['currentUserPermissions'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ?? const [],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'logoUrl': logoUrl,
    'description': description,
    'email': email,
    'phone': phone,
    'address': address,
    'currency': currency,
    'language': language,
    'timezone': timezone,
    'isActive': isActive,
    'customDomain': customDomain,
    'primaryColor': primaryColor,
    'secondaryColor': secondaryColor,
    'seoTitle': seoTitle,
    'seoDescription': seoDescription,
    'seoKeywords': seoKeywords,
    'ogImageUrl': ogImageUrl,
    'facebookUrl': facebookUrl,
    'instagramUrl': instagramUrl,
    'tiktokUrl': tiktokUrl,
    'twitterUrl': twitterUrl,
    'linkedinUrl': linkedinUrl,
    'whatsappNumber': whatsappNumber,
    'enableCod': enableCod,
    'enableJax': enableJax,
    'enableIntigo': enableIntigo,
    'enableAdeex': enableAdeex,
    'headerColor': headerColor,
    'footerColor': footerColor,
    'bodyColor': bodyColor,
    'cardProductColor': cardProductColor,
    'buttonColor': buttonColor,
    'topBarColor': topBarColor,
    'textColor': textColor,
    'announcementText': announcementText,
    'deliveryFees': deliveryFees,
    'tva': tva,
    'simpleCheckout': simpleCheckout,
    'cashOnDelivery': cashOnDelivery,
    'facebookPixelId': facebookPixelId,
    'googleAnalyticsId': googleAnalyticsId,
    'bannerUrl': bannerUrl,
    'faviconUrl': faviconUrl,
    'fontFamily': fontFamily,
    'darkMode': darkMode,
    'stripeEnabled': stripeEnabled,
    'stripeStatus': stripeStatus,
    'stripePublishableKey': stripePublishableKey,
    'freeShippingThreshold': freeShippingThreshold,
    'estimatedDeliveryDays': estimatedDeliveryDays,
    'enableLocalPickup': enableLocalPickup,
    'enableEmailNotifications': enableEmailNotifications,
    'enableSmsNotifications': enableSmsNotifications,
    'enablePushNotifications': enablePushNotifications,
    'enableMarketingEmails': enableMarketingEmails,
    'enableOrderAlerts': enableOrderAlerts,
    'clientMessagingEnabled': clientMessagingEnabled,
    'teamEnabled': teamEnabled,
    'telegramChatId': telegramChatId,
    'telegramEnabled': telegramEnabled,
    'storeStatus': storeStatus,
    'publicationStatus': publicationStatus,
    'frozenAt': frozenAt,
    'freezeReason': freezeReason,
    'isPublished': isPublished,
    'publishedAt': publishedAt,
    'publicUrl': publicUrl,
    'ownerAccess': ownerAccess,
    'currentUserRole': currentUserRole,
    'currentUserPermissions': currentUserPermissions,
  };

  bool hasPermission(String permission) =>
      ownerAccess || currentUserPermissions.contains(permission);

  bool hasAnyPermission(List<String> permissions) =>
      ownerAccess || permissions.any(currentUserPermissions.contains);
}

class BoutiqueStats {
  final int totalOrders;
  final int todayOrders;
  final double totalRevenue;
  final double todayRevenue;
  final int totalProducts;
  final int pendingOrders;
  final String? activeBoutiqueId;

  BoutiqueStats({
    required this.totalOrders,
    required this.todayOrders,
    required this.totalRevenue,
    required this.todayRevenue,
    required this.totalProducts,
    required this.pendingOrders,
    this.activeBoutiqueId,
  });

  factory BoutiqueStats.fromJson(Map<String, dynamic> json) => BoutiqueStats(
    totalOrders: json['totalOrders'] ?? 0,
    todayOrders: json['todayOrders'] ?? 0,
    totalRevenue: (json['totalRevenue'] ?? 0).toDouble(),
    todayRevenue: (json['todayRevenue'] ?? 0).toDouble(),
    totalProducts: json['totalProducts'] ?? 0,
    pendingOrders: json['pendingOrders'] ?? 0,
    activeBoutiqueId: json['activeBoutiqueId'],
  );
}
