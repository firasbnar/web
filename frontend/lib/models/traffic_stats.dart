class TrafficStatsModel {
  final int totalVisits;
  final int uniqueVisitors;
  final int todayVisits;
  final int todayUniqueVisitors;
  final int weekVisits;
  final int weekUniqueVisitors;
  final int monthVisits;
  final int monthUniqueVisitors;
  final int activeVisitors;
  final int authenticatedVisitors;
  final int anonymousVisitors;

  TrafficStatsModel({
    required this.totalVisits,
    required this.uniqueVisitors,
    required this.todayVisits,
    required this.todayUniqueVisitors,
    required this.weekVisits,
    required this.weekUniqueVisitors,
    required this.monthVisits,
    required this.monthUniqueVisitors,
    required this.activeVisitors,
    required this.authenticatedVisitors,
    required this.anonymousVisitors,
  });

  factory TrafficStatsModel.fromJson(Map<String, dynamic> json) {
    return TrafficStatsModel(
      totalVisits: json['totalVisits'] ?? 0,
      uniqueVisitors: json['uniqueVisitors'] ?? 0,
      todayVisits: json['todayVisits'] ?? 0,
      todayUniqueVisitors: json['todayUniqueVisitors'] ?? 0,
      weekVisits: json['weekVisits'] ?? 0,
      weekUniqueVisitors: json['weekUniqueVisitors'] ?? 0,
      monthVisits: json['monthVisits'] ?? 0,
      monthUniqueVisitors: json['monthUniqueVisitors'] ?? 0,
      activeVisitors: json['activeVisitors'] ?? 0,
      authenticatedVisitors: (json['authenticatedVisitors'] as num?)?.toInt() ?? 0,
      anonymousVisitors: (json['anonymousVisitors'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'totalVisits': totalVisits,
    'uniqueVisitors': uniqueVisitors,
    'todayVisits': todayVisits,
    'todayUniqueVisitors': todayUniqueVisitors,
    'weekVisits': weekVisits,
    'weekUniqueVisitors': weekUniqueVisitors,
    'monthVisits': monthVisits,
    'monthUniqueVisitors': monthUniqueVisitors,
    'activeVisitors': activeVisitors,
    'authenticatedVisitors': authenticatedVisitors,
    'anonymousVisitors': anonymousVisitors,
  };
}

class GeoData {
  final String country;
  final String? city;
  final int count;

  GeoData({required this.country, this.city, required this.count});

  factory GeoData.fromJson(Map<String, dynamic> json) {
    return GeoData(
      country: json['country'] ?? 'Unknown',
      city: json['city'],
      count: (json['count'] as num).toInt(),
    );
  }
}

class DeviceBreakdown {
  final String deviceType;
  final int count;
  final double percentage;

  DeviceBreakdown({
    required this.deviceType,
    required this.count,
    this.percentage = 0,
  });

  factory DeviceBreakdown.fromJson(Map<String, dynamic> json) {
    return DeviceBreakdown(
      deviceType: json['deviceType'] ?? 'Unknown',
      count: (json['count'] as num).toInt(),
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
    );
  }
}

class BrowserBreakdown {
  final String browser;
  final int count;
  final double percentage;

  BrowserBreakdown({
    required this.browser,
    required this.count,
    this.percentage = 0,
  });

  factory BrowserBreakdown.fromJson(Map<String, dynamic> json) {
    return BrowserBreakdown(
      browser: json['browser'] ?? 'Unknown',
      count: (json['count'] as num).toInt(),
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ReferralSource {
  final String source;
  final int count;
  final double percentage;

  ReferralSource({
    required this.source,
    required this.count,
    this.percentage = 0,
  });

  factory ReferralSource.fromJson(Map<String, dynamic> json) {
    return ReferralSource(
      source: json['source'] ?? 'Unknown',
      count: (json['count'] as num).toInt(),
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
    );
  }
}

class VisitorEntry {
  final String id;
  final String ipHash;
  final String? country;
  final String? city;
  final String? region;
  final String? deviceType;
  final String? browser;
  final String? operatingSystem;
  final String? platform;
  final String? referralSource;
  final int totalVisits;
  final String? firstVisitAt;
  final String? lastActivityAt;
  final bool isActive;
  final bool isAuthenticated;
  final String? userEmail;
  final String? userName;
  final String? createdAt;

  VisitorEntry({
    required this.id,
    required this.ipHash,
    this.country,
    this.city,
    this.region,
    this.deviceType,
    this.browser,
    this.operatingSystem,
    this.platform,
    this.referralSource,
    required this.totalVisits,
    this.firstVisitAt,
    this.lastActivityAt,
    required this.isActive,
    required this.isAuthenticated,
    this.userEmail,
    this.userName,
    this.createdAt,
  });

  factory VisitorEntry.fromJson(Map<String, dynamic> json) {
    return VisitorEntry(
      id: json['id'] ?? '',
      ipHash: json['ipHash'] ?? '',
      country: json['country'],
      city: json['city'],
      region: json['region'],
      deviceType: json['deviceType'],
      browser: json['browser'],
      operatingSystem: json['operatingSystem'],
      platform: json['platform'],
      referralSource: json['referralSource'],
      totalVisits: (json['totalVisits'] as num?)?.toInt() ?? 0,
      firstVisitAt: json['firstVisitAt'],
      lastActivityAt: json['lastActivityAt'],
      isActive: json['isActive'] ?? true,
      isAuthenticated: json['isAuthenticated'] ?? false,
      userEmail: json['userEmail'],
      userName: json['userName'],
      createdAt: json['createdAt'],
    );
  }
}

class TimelinePoint {
  final String date;
  final int visits;
  final int uniqueVisitors;

  TimelinePoint({
    required this.date,
    required this.visits,
    required this.uniqueVisitors,
  });

  factory TimelinePoint.fromJson(Map<String, dynamic> json) {
    return TimelinePoint(
      date: json['date'] ?? '',
      visits: (json['visits'] as num?)?.toInt() ?? 0,
      uniqueVisitors: (json['uniqueVisitors'] as num?)?.toInt() ?? 0,
    );
  }
}

class TrafficOverviewModel {
  final TrafficStatsModel stats;
  final List<GeoData> topCountries;
  final List<GeoData> topCities;
  final List<DeviceBreakdown> deviceBreakdown;
  final List<BrowserBreakdown> browserBreakdown;
  final List<ReferralSource> referralSources;

  TrafficOverviewModel({
    required this.stats,
    required this.topCountries,
    required this.topCities,
    required this.deviceBreakdown,
    required this.browserBreakdown,
    required this.referralSources,
  });

  factory TrafficOverviewModel.fromJson(Map<String, dynamic> json) {
    return TrafficOverviewModel(
      stats: TrafficStatsModel.fromJson(json['stats'] ?? {}),
      topCountries: (json['topCountries'] as List?)
          ?.map((e) => GeoData.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      topCities: (json['topCities'] as List?)
          ?.map((e) => GeoData.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      deviceBreakdown: (json['deviceBreakdown'] as List?)
          ?.map((e) => DeviceBreakdown.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      browserBreakdown: (json['browserBreakdown'] as List?)
          ?.map((e) => BrowserBreakdown.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      referralSources: (json['referralSources'] as List?)
          ?.map((e) => ReferralSource.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}