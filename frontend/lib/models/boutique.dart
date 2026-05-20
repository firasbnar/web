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
  final String? customCss;
  final String? customJs;
  final bool enablePaypal;
  final bool enableCod;
  final bool enableD17;
  final bool enableAdeex;
  final bool enableJax;
  final bool enableIntigo;

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
  final String? konnectMerchantId;
  final String? konnectApiKey;
  final String? konnectStatus;
  final String? d17MerchantNumber;
  final String? d17QrCodeUrl;
  final String? d17Status;
  final String? facebookPixelId;
  final String? googleAnalyticsId;

  // New store settings
  final String? bannerUrl;
  final String? faviconUrl;
  final String? fontFamily;
  final bool darkMode;
  final String? stripePublishableKey;
  final String? paypalClientId;
  final double? freeShippingThreshold;
  final int? estimatedDeliveryDays;
  final bool enableLocalPickup;
  final bool enableEmailNotifications;
  final bool enableSmsNotifications;
  final bool enablePushNotifications;
  final bool enableMarketingEmails;
  final bool enableOrderAlerts;
  final String? telegramChatId;
  final bool telegramEnabled;

  final String? storeStatus;
  final String? publicationStatus;
  final String? frozenAt;
  final String? freezeReason;
  final bool isPublished;
  final String? publishedAt;
  final String? publicUrl;

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
    this.customCss,
    this.customJs,
    this.enablePaypal = false,
    this.enableCod = true,
    this.enableD17 = false,
    this.enableAdeex = false,
    this.enableJax = false,
    this.enableIntigo = false,
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
    this.konnectMerchantId,
    this.konnectApiKey,
    this.konnectStatus,
    this.d17MerchantNumber,
    this.d17QrCodeUrl,
    this.d17Status,
    this.facebookPixelId,
    this.googleAnalyticsId,
    this.bannerUrl,
    this.faviconUrl,
    this.fontFamily,
    this.darkMode = false,
    this.stripePublishableKey,
    this.paypalClientId,
    this.freeShippingThreshold,
    this.estimatedDeliveryDays,
    this.enableLocalPickup = false,
    this.enableEmailNotifications = true,
    this.enableSmsNotifications = false,
    this.enablePushNotifications = true,
    this.enableMarketingEmails = false,
    this.enableOrderAlerts = true,
    this.telegramChatId,
    this.telegramEnabled = false,
    this.storeStatus,
    this.publicationStatus,
    this.frozenAt,
    this.freezeReason,
    this.isPublished = false,
    this.publishedAt,
    this.publicUrl,
  });

  factory Boutique.fromJson(Map<String, dynamic> json) => Boutique(
    id: json['id'].toString(),
    name: json['name'] ?? '',
    slug: json['slug'] ?? '',
    logoUrl: json['logoUrl'],
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
    ogImageUrl: json['ogImageUrl'],
    facebookUrl: json['facebookUrl'],
    instagramUrl: json['instagramUrl'],
    tiktokUrl: json['tiktokUrl'],
    twitterUrl: json['twitterUrl'],
    linkedinUrl: json['linkedinUrl'],
    whatsappNumber: json['whatsappNumber'],
    customCss: json['customCss'],
    customJs: json['customJs'],
    enablePaypal: json['enablePaypal'] ?? false,
    enableCod: json['enableCod'] ?? true,
    enableD17: json['enableD17'] ?? false,
    enableAdeex: json['enableAdeex'] ?? false,
    enableJax: json['enableJax'] ?? false,
    enableIntigo: json['enableIntigo'] ?? false,
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
    konnectMerchantId: json['konnectMerchantId'] ?? json['konnect_merchant_id'],
    konnectApiKey: json['konnectApiKey'] ?? json['konnect_api_key'],
    konnectStatus: json['konnectStatus'] ?? json['konnect_status'],
    d17MerchantNumber: json['d17MerchantNumber'] ?? json['d17_merchant_number'],
    d17QrCodeUrl: json['d17QrCodeUrl'] ?? json['d17_qr_code_url'],
    d17Status: json['d17Status'] ?? json['d17_status'],
    facebookPixelId: json['facebookPixelId'] ?? json['facebook_pixel_id'],
    googleAnalyticsId: json['googleAnalyticsId'] ?? json['google_analytics_id'],
    bannerUrl: json['bannerUrl'],
    faviconUrl: json['faviconUrl'],
    fontFamily: json['fontFamily'],
    darkMode: json['darkMode'] ?? false,
    stripePublishableKey: json['stripePublishableKey'],
    paypalClientId: json['paypalClientId'],
    freeShippingThreshold: (json['freeShippingThreshold'] as num?)?.toDouble(),
    estimatedDeliveryDays: json['estimatedDeliveryDays'],
    enableLocalPickup: json['enableLocalPickup'] ?? false,
    enableEmailNotifications: json['enableEmailNotifications'] ?? true,
    enableSmsNotifications: json['enableSmsNotifications'] ?? false,
    enablePushNotifications: json['enablePushNotifications'] ?? true,
    enableMarketingEmails: json['enableMarketingEmails'] ?? false,
    enableOrderAlerts: json['enableOrderAlerts'] ?? true,
    telegramChatId: json['telegramChatId'],
    telegramEnabled: json['telegramEnabled'] ?? false,
    storeStatus: json['storeStatus'],
    publicationStatus: json['publicationStatus'],
    frozenAt: json['frozenAt'],
    freezeReason: json['freezeReason'],
    isPublished: json['isPublished'] ?? false,
    publishedAt: json['publishedAt'],
    publicUrl: json['publicUrl'],
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
    'customCss': customCss,
    'customJs': customJs,
    'enablePaypal': enablePaypal,
    'enableCod': enableCod,
    'enableD17': enableD17,
    'enableAdeex': enableAdeex,
    'enableJax': enableJax,
    'enableIntigo': enableIntigo,
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
    'konnectMerchantId': konnectMerchantId,
    'konnectApiKey': konnectApiKey,
    'konnectStatus': konnectStatus,
    'd17MerchantNumber': d17MerchantNumber,
    'd17QrCodeUrl': d17QrCodeUrl,
    'd17Status': d17Status,
    'facebookPixelId': facebookPixelId,
    'googleAnalyticsId': googleAnalyticsId,
    'bannerUrl': bannerUrl,
    'faviconUrl': faviconUrl,
    'fontFamily': fontFamily,
    'darkMode': darkMode,
    'stripePublishableKey': stripePublishableKey,
    'paypalClientId': paypalClientId,
    'freeShippingThreshold': freeShippingThreshold,
    'estimatedDeliveryDays': estimatedDeliveryDays,
    'enableLocalPickup': enableLocalPickup,
    'enableEmailNotifications': enableEmailNotifications,
    'enableSmsNotifications': enableSmsNotifications,
    'enablePushNotifications': enablePushNotifications,
    'enableMarketingEmails': enableMarketingEmails,
    'enableOrderAlerts': enableOrderAlerts,
    'telegramChatId': telegramChatId,
    'telegramEnabled': telegramEnabled,
    'storeStatus': storeStatus,
    'publicationStatus': publicationStatus,
    'frozenAt': frozenAt,
    'freezeReason': freezeReason,
    'isPublished': isPublished,
    'publishedAt': publishedAt,
    'publicUrl': publicUrl,
  };
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
