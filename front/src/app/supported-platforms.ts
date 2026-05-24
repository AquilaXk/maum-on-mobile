export const SUPPORTED_PLATFORMS = ["android", "ios"] as const;

export type SupportedPlatform = (typeof SUPPORTED_PLATFORMS)[number];
