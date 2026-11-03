const brandApiUrls = String.fromEnvironment(
  'BRAND_API_URLS',
  defaultValue:
      'https://web8.dogssr.site/api/v1,https://035888.xyz/api/v1,'
      'https://web2.dogssr.site/api/v1',
);

const brandConfigUrls = String.fromEnvironment(
  'BRAND_CONFIG_URLS',
  defaultValue: 'https://web2.dogssr.site/app/config.json',
);

const brandSiteUrl = String.fromEnvironment(
  'BRAND_SITE_URL',
  defaultValue: 'https://web2.dogssr.site',
);

const brandProfileLabel = String.fromEnvironment(
  'BRAND_PROFILE_LABEL',
  defaultValue: '狗云',
);

/// Xboard reads `flag` before the User-Agent; an unknown UA gets base64 links.
const brandSubscribeFlag = String.fromEnvironment(
  'BRAND_SUBSCRIBE_FLAG',
  defaultValue: 'meta',
);

/// FlClash's first-run disclaimer names FlClash and denies providing service.
const brandShowsDisclaimer = bool.fromEnvironment('BRAND_SHOW_DISCLAIMER');

List<String> splitBrandUrls(String value) => [
  for (final url in value.split(','))
    if (url.trim().isNotEmpty) url.trim().replaceFirst(RegExp(r'/+$'), ''),
];
