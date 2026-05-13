class Boutique {
  final String id;
  final String name;
  final String slug;
  final String? logoUrl;
  final String? description;
  final String? currency;
  final String? language;
  final bool isActive;
  final String? customDomain;
  final String? primaryColor;
  final String? secondaryColor;
  final String? seoTitle;
  final String? seoDescription;
  final String? seoKeywords;
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

  Boutique({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
    this.description,
    this.currency,
    this.language,
    required this.isActive,
    this.customDomain,
    this.primaryColor,
    this.secondaryColor,
    this.seoTitle,
    this.seoDescription,
    this.seoKeywords,
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
  });

  factory Boutique.fromJson(Map<String, dynamic> json) => Boutique(
    id: json['id'].toString(),
    name: json['name'] ?? '',
    slug: json['slug'] ?? '',
    logoUrl: json['logoUrl'],
    description: json['description'],
    currency: json['currency'],
    language: json['language'],
    isActive: json['isActive'] ?? true,
    customDomain: json['customDomain'],
    primaryColor: json['primaryColor'],
    secondaryColor: json['secondaryColor'],
    seoTitle: json['seoTitle'],
    seoDescription: json['seoDescription'],
    seoKeywords: json['seoKeywords'],
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
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'slug': slug,
    'logoUrl': logoUrl,
    'description': description,
    'currency': currency,
    'language': language,
    'isActive': isActive,
    'customDomain': customDomain,
    'primaryColor': primaryColor,
    'secondaryColor': secondaryColor,
    'seoTitle': seoTitle,
    'seoDescription': seoDescription,
    'seoKeywords': seoKeywords,
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
