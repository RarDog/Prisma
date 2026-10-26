import 'dart:convert';
import 'dart:io';

import 'package:gel_rule_app/features/artists/models/pawchive_account.dart';

class AppSettings {
  const AppSettings({
    required this.enabledProviderIds,
    required this.nsfwEnabled,
    required this.cacheTtlHours,
    required this.cacheMaxItems,
    required this.providerPriority,
    required this.themeMode,
    required this.languageCode,
    required this.appSeedColor,
    required this.hiddenTabs,
    required this.allowExperimentalUpdates,
    required this.desktopColumns,
    required this.mobileColumns,
    required this.blurExplicitContent,
    required this.allowDownloads,
    required this.autoDownloadFavorites,
    required this.selectedFeedProviderIds,
    required this.showPostBadges,
    required this.defaultTopPeriodFilter,
    required this.blacklistedTags,
    required this.whitelistedTags,
    required this.smartBlacklistRules,
    required this.hideViewedPosts,
    required this.mediaQualityMode,
    required this.motionRefreshMode,
    required this.autoBatterySaver60Hz,
    required this.videoPlayerMuted,
    this.videoPlayerVolume = 100.0,
    required this.videoPlayerHalfVolume,
    required this.videoPlayerLoop,
    required this.videoPlayerCover,
    required this.videoPlaybackPositions,
    required this.hiddenPostKeys,
    required this.diagnosticLogLines,
    required this.lastFeedTags,
    required this.lastFeedProviderIds,
    required this.lastFeedTopPeriod,
    required this.lastFeedScrollOffset,
    this.favoriteArtists = const [],
    this.pawchiveAccounts = const [],
    this.pawchiveBidirectionalSync = false,
    this.skippedUpdateVersion,
    this.lastUpdateCheckAt,
    this.defaultRatingFilter,
    this.lastFeedRating,
    this.amoledMode = false,
    this.useDynamicColor = false,
    this.gridMode = 'masonry',
    this.searchPresets = const [],
    this.downloadPathTemplate = '{Artist}/{ID}',
    this.searchHistoryLimit = 500,
    this.tagCacheLimit = 5000,
    this.lastActiveLocation = '/',
    this.showProviderHealthBanner = true,
    this.hasCompletedOnboarding = false,
    this.mangaReaderRtl = true,
    this.mangaSelectedRating = 'All',
    this.mangaScrollOffset = 0.0,
    this.mangaSelectedProviderId = 'mangadex',
    this.mangaReadingMode = 'pagedRtl',
    this.mangaVolumeNavigation = true,
    this.mangaInvertVolumeKeys = false,
    this.novelFontSize = 17.0,
    this.novelLineHeight = 1.6,
    this.novelReaderTheme = 'dark',
    this.debugHudEnabled = false,
    this.debugHudShowCpu = true,
    this.debugHudShowRam = true,
    this.debugHudShowNetwork = true,
    this.debugHudShowFps = true,
    this.debugHudOpacity = 0.85,
    this.debugHudX = 16.0,
    this.debugHudY = 90.0,
    this.desktopSidebarPinned = false,
    this.desktopNavPosition = 'left',
  });

  final bool hasCompletedOnboarding;
  final bool mangaReaderRtl;
  final String mangaSelectedRating;
  final double mangaScrollOffset;
  final String mangaSelectedProviderId;
  final String mangaReadingMode;
  final bool mangaVolumeNavigation;
  final bool mangaInvertVolumeKeys;
  final double novelFontSize;
  final double novelLineHeight;
  final String novelReaderTheme;
  final bool debugHudEnabled;
  final bool debugHudShowCpu;
  final bool debugHudShowRam;
  final bool debugHudShowNetwork;
  final bool debugHudShowFps;
  final double debugHudOpacity;
  final double debugHudX;
  final double debugHudY;
  final bool desktopSidebarPinned;
  final String desktopNavPosition;
  final String lastActiveLocation;
  final List<String> favoriteArtists;
  final List<String> pawchiveAccounts;
  final bool pawchiveBidirectionalSync;
  final List<String> enabledProviderIds;
  final bool nsfwEnabled;
  final int cacheTtlHours;
  final int cacheMaxItems;
  final Map<String, int> providerPriority;
  final String themeMode;
  final String languageCode;
  final int appSeedColor;
  final List<String> hiddenTabs;
  final bool allowExperimentalUpdates;
  final int desktopColumns;
  final int mobileColumns;
  final bool blurExplicitContent;
  final bool allowDownloads;
  final bool autoDownloadFavorites;
  final List<String> selectedFeedProviderIds;
  final bool showPostBadges;
  final String defaultTopPeriodFilter;
  final List<String> blacklistedTags;
  final List<String> whitelistedTags;
  final List<String> smartBlacklistRules;
  final bool hideViewedPosts;
  final String mediaQualityMode;
  final String motionRefreshMode;
  final bool autoBatterySaver60Hz;
  final bool videoPlayerMuted;
  final double videoPlayerVolume;
  final bool videoPlayerHalfVolume;
  final bool videoPlayerLoop;
  final bool videoPlayerCover;
  final Map<String, int> videoPlaybackPositions;
  final List<String> hiddenPostKeys;
  final List<String> diagnosticLogLines;
  final List<String> lastFeedTags;
  final List<String> lastFeedProviderIds;
  final String lastFeedTopPeriod;
  final double lastFeedScrollOffset;
  final String? skippedUpdateVersion;
  final String? lastUpdateCheckAt;
  final String? defaultRatingFilter;
  final String? lastFeedRating;
  final bool amoledMode;
  final bool useDynamicColor;
  final String gridMode;
  final List<String> searchPresets;
  final String downloadPathTemplate;
  final int searchHistoryLimit;
  final int tagCacheLimit;
  final bool showProviderHealthBanner;

  static const defaults = AppSettings(
    enabledProviderIds: ['gelbooru', 'rule34', 'realbooru'],
    nsfwEnabled: true,
    cacheTtlHours: 24,
    cacheMaxItems: 2000,
    providerPriority: {'gelbooru': 0, 'rule34': 1, 'realbooru': 2},
    favoriteArtists: [],
    pawchiveAccounts: [],
    pawchiveBidirectionalSync: false,
    themeMode: 'dark',
    languageCode: 'ru',
    appSeedColor: 0xFFE84D8A,
    hiddenTabs: [],
    allowExperimentalUpdates: false,
    desktopColumns: 5,
    mobileColumns: 2,
    blurExplicitContent: true,
    allowDownloads: true,
    autoDownloadFavorites: true,
    selectedFeedProviderIds: [],
    showPostBadges: true,
    defaultTopPeriodFilter: 'none',
    blacklistedTags: [],
    whitelistedTags: [],
    smartBlacklistRules: [],
    hideViewedPosts: false,
    mediaQualityMode: 'auto',
    motionRefreshMode: 'auto',
    autoBatterySaver60Hz: true,
    videoPlayerMuted: false,
    videoPlayerVolume: 100.0,
    videoPlayerHalfVolume: false,
    videoPlayerLoop: false,
    videoPlayerCover: false,
    videoPlaybackPositions: {},
    hiddenPostKeys: [],
    diagnosticLogLines: [],
    lastFeedTags: [],
    lastFeedProviderIds: [],
    lastFeedTopPeriod: 'none',
    lastFeedScrollOffset: 0,
    skippedUpdateVersion: null,
    lastUpdateCheckAt: null,
    defaultRatingFilter: null,
    lastFeedRating: null,
    searchHistoryLimit: 500,
    tagCacheLimit: 5000,
    lastActiveLocation: '/',
    hasCompletedOnboarding: false,
    mangaReaderRtl: true,
    mangaSelectedRating: 'All',
    mangaScrollOffset: 0.0,
    mangaSelectedProviderId: 'mangadex',
    mangaReadingMode: 'pagedRtl',
    mangaVolumeNavigation: true,
    mangaInvertVolumeKeys: false,
    novelFontSize: 17.0,
    novelLineHeight: 1.6,
    novelReaderTheme: 'dark',
    desktopNavPosition: 'left',
  );

  AppSettings copyWith({
    List<String>? enabledProviderIds,
    bool? nsfwEnabled,
    int? cacheTtlHours,
    int? cacheMaxItems,
    Map<String, int>? providerPriority,
    String? themeMode,
    String? languageCode,
    int? appSeedColor,
    List<String>? hiddenTabs,
    bool? allowExperimentalUpdates,
    int? desktopColumns,
    int? mobileColumns,
    bool? blurExplicitContent,
    bool? allowDownloads,
    bool? autoDownloadFavorites,
    List<String>? selectedFeedProviderIds,
    bool? showPostBadges,
    String? defaultTopPeriodFilter,
    List<String>? blacklistedTags,
    List<String>? whitelistedTags,
    List<String>? smartBlacklistRules,
    bool? hideViewedPosts,
    String? mediaQualityMode,
    String? motionRefreshMode,
    bool? autoBatterySaver60Hz,
    bool? videoPlayerMuted,
    double? videoPlayerVolume,
    bool? videoPlayerHalfVolume,
    bool? videoPlayerLoop,
    bool? videoPlayerCover,
    Map<String, int>? videoPlaybackPositions,
    List<String>? hiddenPostKeys,
    List<String>? diagnosticLogLines,
    List<String>? lastFeedTags,
    List<String>? lastFeedProviderIds,
    String? lastFeedTopPeriod,
    double? lastFeedScrollOffset,
    String? skippedUpdateVersion,
    String? lastUpdateCheckAt,
    String? defaultRatingFilter,
    bool clearDefaultRatingFilter = false,
    String? lastFeedRating,
    bool clearLastFeedRating = false,
    List<String>? favoriteArtists,
    List<String>? pawchiveAccounts,
    bool? pawchiveBidirectionalSync,
    bool? amoledMode,
    bool? useDynamicColor,
    String? gridMode,
    List<String>? searchPresets,
    String? downloadPathTemplate,
    int? searchHistoryLimit,
    int? tagCacheLimit,
    bool? showProviderHealthBanner,
    String? lastActiveLocation,
    bool? hasCompletedOnboarding,
    bool? mangaReaderRtl,
    String? mangaSelectedRating,
    double? mangaScrollOffset,
    String? mangaSelectedProviderId,
    String? mangaReadingMode,
    bool? mangaVolumeNavigation,
    bool? mangaInvertVolumeKeys,
    double? novelFontSize,
    double? novelLineHeight,
    String? novelReaderTheme,
    bool? debugHudEnabled,
    bool? debugHudShowCpu,
    bool? debugHudShowRam,
    bool? debugHudShowNetwork,
    bool? debugHudShowFps,
    double? debugHudOpacity,
    double? debugHudX,
    double? debugHudY,
    bool? desktopSidebarPinned,
    String? desktopNavPosition,
  }) {
    return AppSettings(
      lastActiveLocation: lastActiveLocation ?? this.lastActiveLocation,
      favoriteArtists: favoriteArtists ?? this.favoriteArtists,
      pawchiveAccounts: pawchiveAccounts ?? this.pawchiveAccounts,
      pawchiveBidirectionalSync:
          pawchiveBidirectionalSync ?? this.pawchiveBidirectionalSync,
      enabledProviderIds: enabledProviderIds ?? this.enabledProviderIds,
      nsfwEnabled: nsfwEnabled ?? this.nsfwEnabled,
      cacheTtlHours: cacheTtlHours ?? this.cacheTtlHours,
      cacheMaxItems: cacheMaxItems ?? this.cacheMaxItems,
      providerPriority: providerPriority ?? this.providerPriority,
      themeMode: themeMode ?? this.themeMode,
      languageCode: languageCode ?? this.languageCode,
      appSeedColor: appSeedColor ?? this.appSeedColor,
      hiddenTabs: hiddenTabs ?? this.hiddenTabs,
      allowExperimentalUpdates:
          allowExperimentalUpdates ?? this.allowExperimentalUpdates,
      desktopColumns: desktopColumns ?? this.desktopColumns,
      mobileColumns: mobileColumns ?? this.mobileColumns,
      blurExplicitContent: blurExplicitContent ?? this.blurExplicitContent,
      allowDownloads: allowDownloads ?? this.allowDownloads,
      autoDownloadFavorites:
          autoDownloadFavorites ?? this.autoDownloadFavorites,
      selectedFeedProviderIds:
          selectedFeedProviderIds ?? this.selectedFeedProviderIds,
      showPostBadges: showPostBadges ?? this.showPostBadges,
      defaultTopPeriodFilter:
          defaultTopPeriodFilter ?? this.defaultTopPeriodFilter,
      blacklistedTags: blacklistedTags ?? this.blacklistedTags,
      whitelistedTags: whitelistedTags ?? this.whitelistedTags,
      smartBlacklistRules: smartBlacklistRules ?? this.smartBlacklistRules,
      hideViewedPosts: hideViewedPosts ?? this.hideViewedPosts,
      mediaQualityMode: mediaQualityMode ?? this.mediaQualityMode,
      motionRefreshMode: motionRefreshMode ?? this.motionRefreshMode,
      autoBatterySaver60Hz: autoBatterySaver60Hz ?? this.autoBatterySaver60Hz,
      videoPlayerMuted: videoPlayerMuted ?? this.videoPlayerMuted,
      videoPlayerVolume: videoPlayerVolume ?? this.videoPlayerVolume,
      videoPlayerHalfVolume:
          videoPlayerHalfVolume ?? this.videoPlayerHalfVolume,
      videoPlayerLoop: videoPlayerLoop ?? this.videoPlayerLoop,
      videoPlayerCover: videoPlayerCover ?? this.videoPlayerCover,
      videoPlaybackPositions:
          videoPlaybackPositions ?? this.videoPlaybackPositions,
      hiddenPostKeys: hiddenPostKeys ?? this.hiddenPostKeys,
      diagnosticLogLines: diagnosticLogLines ?? this.diagnosticLogLines,
      lastFeedTags: lastFeedTags ?? this.lastFeedTags,
      lastFeedProviderIds: lastFeedProviderIds ?? this.lastFeedProviderIds,
      lastFeedTopPeriod: lastFeedTopPeriod ?? this.lastFeedTopPeriod,
      lastFeedScrollOffset: lastFeedScrollOffset ?? this.lastFeedScrollOffset,
      skippedUpdateVersion: skippedUpdateVersion ?? this.skippedUpdateVersion,
      lastUpdateCheckAt: lastUpdateCheckAt ?? this.lastUpdateCheckAt,
      defaultRatingFilter: clearDefaultRatingFilter
          ? null
          : defaultRatingFilter ?? this.defaultRatingFilter,
      lastFeedRating:
          clearLastFeedRating ? null : lastFeedRating ?? this.lastFeedRating,
      amoledMode: amoledMode ?? this.amoledMode,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
      gridMode: gridMode ?? this.gridMode,
      searchPresets: searchPresets ?? this.searchPresets,
      downloadPathTemplate: downloadPathTemplate ?? this.downloadPathTemplate,
      searchHistoryLimit: searchHistoryLimit ?? this.searchHistoryLimit,
      tagCacheLimit: tagCacheLimit ?? this.tagCacheLimit,
      showProviderHealthBanner:
          showProviderHealthBanner ?? this.showProviderHealthBanner,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      mangaReaderRtl: mangaReaderRtl ?? this.mangaReaderRtl,
      mangaSelectedRating: mangaSelectedRating ?? this.mangaSelectedRating,
      mangaScrollOffset: mangaScrollOffset ?? this.mangaScrollOffset,
      mangaSelectedProviderId:
          mangaSelectedProviderId ?? this.mangaSelectedProviderId,
      mangaReadingMode: mangaReadingMode ?? this.mangaReadingMode,
      mangaVolumeNavigation: mangaVolumeNavigation ?? this.mangaVolumeNavigation,
      mangaInvertVolumeKeys:
          mangaInvertVolumeKeys ?? this.mangaInvertVolumeKeys,
      novelFontSize: novelFontSize ?? this.novelFontSize,
      novelLineHeight: novelLineHeight ?? this.novelLineHeight,
      novelReaderTheme: novelReaderTheme ?? this.novelReaderTheme,
      debugHudEnabled: debugHudEnabled ?? this.debugHudEnabled,
      debugHudShowCpu: debugHudShowCpu ?? this.debugHudShowCpu,
      debugHudShowRam: debugHudShowRam ?? this.debugHudShowRam,
      debugHudShowNetwork: debugHudShowNetwork ?? this.debugHudShowNetwork,
      debugHudShowFps: debugHudShowFps ?? this.debugHudShowFps,
      debugHudOpacity: debugHudOpacity ?? this.debugHudOpacity,
      debugHudX: debugHudX ?? this.debugHudX,
      debugHudY: debugHudY ?? this.debugHudY,
      desktopSidebarPinned: desktopSidebarPinned ?? this.desktopSidebarPinned,
      desktopNavPosition: desktopNavPosition ?? this.desktopNavPosition,
    );
  }

  Map<String, dynamic> toJson() => {
        'favoriteArtists': favoriteArtists,
        'pawchiveAccounts': pawchiveAccounts,
        'pawchiveBidirectionalSync': pawchiveBidirectionalSync,
        'enabledProviderIds': enabledProviderIds,
        'nsfwEnabled': nsfwEnabled,
        'cacheTtlHours': cacheTtlHours,
        'cacheMaxItems': cacheMaxItems,
        'providerPriority': providerPriority,
        'themeMode': themeMode,
        'languageCode': languageCode,
        'appSeedColor': appSeedColor,
        'hiddenTabs': hiddenTabs,
        'allowExperimentalUpdates': allowExperimentalUpdates,
        'desktopColumns': desktopColumns,
        'mobileColumns': mobileColumns,
        'blurExplicitContent': blurExplicitContent,
        'allowDownloads': allowDownloads,
        'autoDownloadFavorites': autoDownloadFavorites,
        'selectedFeedProviderIds': selectedFeedProviderIds,
        'showPostBadges': showPostBadges,
        'defaultTopPeriodFilter': defaultTopPeriodFilter,
        'blacklistedTags': blacklistedTags,
        'whitelistedTags': whitelistedTags,
        'smartBlacklistRules': smartBlacklistRules,
        'hideViewedPosts': hideViewedPosts,
        'mediaQualityMode': mediaQualityMode,
        'motionRefreshMode': motionRefreshMode,
        'autoBatterySaver60Hz': autoBatterySaver60Hz,
        'videoPlayerMuted': videoPlayerMuted,
        'videoPlayerVolume': videoPlayerVolume,
        'videoPlayerHalfVolume': videoPlayerHalfVolume,
        'videoPlayerLoop': videoPlayerLoop,
        'videoPlayerCover': videoPlayerCover,
        'videoPlaybackPositions': videoPlaybackPositions,
        'hiddenPostKeys': hiddenPostKeys,
        'diagnosticLogLines': diagnosticLogLines,
        'lastFeedTags': lastFeedTags,
        'lastFeedProviderIds': lastFeedProviderIds,
        'lastFeedTopPeriod': lastFeedTopPeriod,
        'lastFeedScrollOffset': lastFeedScrollOffset,
        'skippedUpdateVersion': skippedUpdateVersion,
        'lastUpdateCheckAt': lastUpdateCheckAt,
        'defaultRatingFilter': defaultRatingFilter,
        'lastFeedRating': lastFeedRating,
        'amoledMode': amoledMode,
        'useDynamicColor': useDynamicColor,
        'gridMode': gridMode,
        'searchPresets': searchPresets,
        'downloadPathTemplate': downloadPathTemplate,
        'searchHistoryLimit': searchHistoryLimit,
        'tagCacheLimit': tagCacheLimit,
        'showProviderHealthBanner': showProviderHealthBanner,
        'lastActiveLocation': lastActiveLocation,
        'hasCompletedOnboarding': hasCompletedOnboarding,
        'mangaReaderRtl': mangaReaderRtl,
        'mangaSelectedRating': mangaSelectedRating,
        'mangaScrollOffset': mangaScrollOffset,
        'mangaSelectedProviderId': mangaSelectedProviderId,
        'mangaReadingMode': mangaReadingMode,
        'novelFontSize': novelFontSize,
        'novelLineHeight': novelLineHeight,
        'novelReaderTheme': novelReaderTheme,
        'mangaVolumeNavigation': mangaVolumeNavigation,
        'mangaInvertVolumeKeys': mangaInvertVolumeKeys,
        'debugHudEnabled': debugHudEnabled,
        'debugHudShowCpu': debugHudShowCpu,
        'debugHudShowRam': debugHudShowRam,
        'debugHudShowNetwork': debugHudShowNetwork,
        'debugHudShowFps': debugHudShowFps,
        'debugHudOpacity': debugHudOpacity,
        'debugHudX': debugHudX,
        'debugHudY': debugHudY,
        'desktopSidebarPinned': desktopSidebarPinned,
        if (!Platform.isAndroid && !Platform.isIOS)
          'desktopNavPosition': desktopNavPosition,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        enabledProviderIds: List<String>.from(
          (json['enabledProviderIds'] as List?) ?? defaults.enabledProviderIds,
        ),
        nsfwEnabled: (json['nsfwEnabled'] as bool?) ?? defaults.nsfwEnabled,
        cacheTtlHours:
            (json['cacheTtlHours'] as num?)?.toInt() ?? defaults.cacheTtlHours,
        cacheMaxItems:
            (json['cacheMaxItems'] as num?)?.toInt() ?? defaults.cacheMaxItems,
        providerPriority: Map<String, int>.from(
          (json['providerPriority'] as Map?) ?? defaults.providerPriority,
        ),
        themeMode: (json['themeMode'] as String?) ?? defaults.themeMode,
        languageCode:
            (json['languageCode'] as String?) ?? defaults.languageCode,
        appSeedColor:
            (json['appSeedColor'] as num?)?.toInt() ?? defaults.appSeedColor,
        hiddenTabs: List<String>.from(
            (json['hiddenTabs'] as List?) ?? defaults.hiddenTabs),
        allowExperimentalUpdates: (json['allowExperimentalUpdates'] as bool?) ??
            defaults.allowExperimentalUpdates,
        desktopColumns: (json['desktopColumns'] as num?)?.toInt() ??
            defaults.desktopColumns,
        mobileColumns:
            (json['mobileColumns'] as num?)?.toInt() ?? defaults.mobileColumns,
        blurExplicitContent: (json['blurExplicitContent'] as bool?) ??
            defaults.blurExplicitContent,
        allowDownloads:
            (json['allowDownloads'] as bool?) ?? defaults.allowDownloads,
        autoDownloadFavorites: (json['autoDownloadFavorites'] as bool?) ??
            defaults.autoDownloadFavorites,
        selectedFeedProviderIds: List<String>.from(
          (json['selectedFeedProviderIds'] as List?) ??
              defaults.selectedFeedProviderIds,
        ),
        showPostBadges:
            (json['showPostBadges'] as bool?) ?? defaults.showPostBadges,
        defaultTopPeriodFilter: (json['defaultTopPeriodFilter'] as String?) ??
            defaults.defaultTopPeriodFilter,
        blacklistedTags: List<String>.from(
          (json['blacklistedTags'] as List?) ?? defaults.blacklistedTags,
        ),
        whitelistedTags: List<String>.from(
          (json['whitelistedTags'] as List?) ?? defaults.whitelistedTags,
        ),
        smartBlacklistRules: List<String>.from(
          (json['smartBlacklistRules'] as List?) ??
              (json['blacklistedTags'] as List?) ??
              defaults.smartBlacklistRules,
        ),
        hideViewedPosts:
            (json['hideViewedPosts'] as bool?) ?? defaults.hideViewedPosts,
        mediaQualityMode:
            (json['mediaQualityMode'] as String?) ?? defaults.mediaQualityMode,
        motionRefreshMode: (json['motionRefreshMode'] as String?) ??
            defaults.motionRefreshMode,
        autoBatterySaver60Hz: (json['autoBatterySaver60Hz'] as bool?) ??
            defaults.autoBatterySaver60Hz,
        videoPlayerMuted:
            (json['videoPlayerMuted'] as bool?) ?? defaults.videoPlayerMuted,
        videoPlayerVolume: (json['videoPlayerVolume'] as num?)?.toDouble() ??
            defaults.videoPlayerVolume,
        videoPlayerHalfVolume: (json['videoPlayerHalfVolume'] as bool?) ??
            defaults.videoPlayerHalfVolume,
        videoPlayerLoop:
            (json['videoPlayerLoop'] as bool?) ?? defaults.videoPlayerLoop,
        videoPlayerCover:
            (json['videoPlayerCover'] as bool?) ?? defaults.videoPlayerCover,
        videoPlaybackPositions: Map<String, int>.from(
          (json['videoPlaybackPositions'] as Map?) ??
              defaults.videoPlaybackPositions,
        ),
        hiddenPostKeys: List<String>.from(
          (json['hiddenPostKeys'] as List?) ?? defaults.hiddenPostKeys,
        ),
        diagnosticLogLines: List<String>.from(
          (json['diagnosticLogLines'] as List?) ?? defaults.diagnosticLogLines,
        ),
        lastFeedTags: List<String>.from(
          (json['lastFeedTags'] as List?) ?? defaults.lastFeedTags,
        ),
        lastFeedProviderIds: List<String>.from(
          (json['lastFeedProviderIds'] as List?) ??
              (json['selectedFeedProviderIds'] as List?) ??
              defaults.lastFeedProviderIds,
        ),
        lastFeedTopPeriod: (json['lastFeedTopPeriod'] as String?) ??
            (json['defaultTopPeriodFilter'] as String?) ??
            defaults.lastFeedTopPeriod,
        lastFeedScrollOffset:
            (json['lastFeedScrollOffset'] as num?)?.toDouble() ??
                defaults.lastFeedScrollOffset,
        favoriteArtists: List<String>.from(
          (json['favoriteArtists'] as List?) ?? defaults.favoriteArtists,
        ),
        pawchiveAccounts: List<String>.from(
          (json['pawchiveAccounts'] as List?) ?? defaults.pawchiveAccounts,
        ),
        pawchiveBidirectionalSync:
            (json['pawchiveBidirectionalSync'] as bool?) ??
                defaults.pawchiveBidirectionalSync,
        skippedUpdateVersion: json['skippedUpdateVersion'] as String?,
        lastUpdateCheckAt: json['lastUpdateCheckAt'] as String?,
        defaultRatingFilter: json['defaultRatingFilter'] as String?,
        lastFeedRating: json['lastFeedRating'] as String?,
        amoledMode: (json['amoledMode'] as bool?) ?? false,
        useDynamicColor: (json['useDynamicColor'] as bool?) ?? false,
        gridMode: (json['gridMode'] as String?) ?? 'masonry',
        searchPresets: List<String>.from(
          (json['searchPresets'] as List?) ?? const [],
        ),
        downloadPathTemplate:
            (json['downloadPathTemplate'] as String?) ?? '{Artist}/{ID}',
        searchHistoryLimit: (json['searchHistoryLimit'] as num?)?.toInt() ??
            defaults.searchHistoryLimit,
        tagCacheLimit:
            (json['tagCacheLimit'] as num?)?.toInt() ?? defaults.tagCacheLimit,
        showProviderHealthBanner: (json['showProviderHealthBanner'] as bool?) ??
            defaults.showProviderHealthBanner,
        lastActiveLocation: (json['lastActiveLocation'] as String?) ??
            defaults.lastActiveLocation,
        hasCompletedOnboarding:
            (json['hasCompletedOnboarding'] as bool?) ?? false,
        mangaReaderRtl:
            (json['mangaReaderRtl'] as bool?) ?? defaults.mangaReaderRtl,
        mangaSelectedRating: (json['mangaSelectedRating'] as String?) ??
            defaults.mangaSelectedRating,
        mangaScrollOffset: (json['mangaScrollOffset'] as num?)?.toDouble() ??
            defaults.mangaScrollOffset,
        mangaSelectedProviderId: (json['mangaSelectedProviderId'] as String?) ??
            defaults.mangaSelectedProviderId,
        mangaReadingMode:
            (json['mangaReadingMode'] as String?) ?? defaults.mangaReadingMode,
        novelFontSize:
            (json['novelFontSize'] as num?)?.toDouble() ??
                defaults.novelFontSize,
        novelLineHeight:
            (json['novelLineHeight'] as num?)?.toDouble() ??
                defaults.novelLineHeight,
        novelReaderTheme:
            (json['novelReaderTheme'] as String?) ??
                defaults.novelReaderTheme,
        mangaVolumeNavigation: (json['mangaVolumeNavigation'] as bool?) ??
            defaults.mangaVolumeNavigation,
        mangaInvertVolumeKeys: (json['mangaInvertVolumeKeys'] as bool?) ??
            defaults.mangaInvertVolumeKeys,
        debugHudEnabled:
            (json['debugHudEnabled'] as bool?) ?? defaults.debugHudEnabled,
        debugHudShowCpu:
            (json['debugHudShowCpu'] as bool?) ?? defaults.debugHudShowCpu,
        debugHudShowRam:
            (json['debugHudShowRam'] as bool?) ?? defaults.debugHudShowRam,
        debugHudShowNetwork: (json['debugHudShowNetwork'] as bool?) ??
            defaults.debugHudShowNetwork,
        debugHudShowFps:
            (json['debugHudShowFps'] as bool?) ?? defaults.debugHudShowFps,
        debugHudOpacity: (json['debugHudOpacity'] as num?)?.toDouble() ??
            defaults.debugHudOpacity,
        debugHudX:
            (json['debugHudX'] as num?)?.toDouble() ?? defaults.debugHudX,
        debugHudY:
            (json['debugHudY'] as num?)?.toDouble() ?? defaults.debugHudY,
        desktopSidebarPinned: (json['desktopSidebarPinned'] as bool?) ??
            defaults.desktopSidebarPinned,
        desktopNavPosition: (json['desktopNavPosition'] as String?) ??
            defaults.desktopNavPosition,
      );

  List<PawchiveAccount> get parsedPawchiveAccounts {
    final list = <PawchiveAccount>[];
    for (final raw in pawchiveAccounts) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          list.add(PawchiveAccount.fromJson(decoded));
        }
      } catch (_) {}
    }
    return list;
  }

  PawchiveAccount? get activePawchiveAccount {
    final accounts = parsedPawchiveAccounts;
    if (accounts.isEmpty) return null;
    return accounts.firstWhere((a) => a.isActive, orElse: () => accounts.first);
  }
}

