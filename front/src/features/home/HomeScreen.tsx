import { StyleSheet, Text, TouchableOpacity, View } from "react-native";
import { SUPPORTED_PLATFORMS } from "../../app/supported-platforms";
import { colors, spacing, typography } from "../../theme/tokens";

type HomeScreenProps = {
  routeTitle: string;
};

export function HomeScreen({ routeTitle }: HomeScreenProps) {
  return (
    <View style={styles.screen}>
      <View style={styles.header}>
        <Text style={styles.route}>{routeTitle}</Text>
        <Text style={styles.title}>Maum On</Text>
        <Text style={styles.subtitle}>마음 기록을 이어갈 준비가 되었습니다.</Text>
      </View>

      <View style={styles.panel}>
        <Text style={styles.panelLabel}>오늘의 시작</Text>
        <Text style={styles.panelValue}>체크인 대기 중</Text>
        <Text style={styles.panelDescription}>Android와 iOS에서 같은 홈 계약을 사용합니다.</Text>
      </View>

      <View style={styles.platforms}>
        {SUPPORTED_PLATFORMS.map((platform) => (
          <View key={platform} style={styles.platformPill}>
            <Text style={styles.platformText}>{platform.toUpperCase()}</Text>
          </View>
        ))}
      </View>

      <TouchableOpacity style={styles.primaryAction} activeOpacity={0.8}>
        <Text style={styles.primaryActionText}>체크인 시작</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    padding: spacing.xl,
    gap: spacing.lg,
    justifyContent: "center",
  },
  header: {
    gap: spacing.sm,
  },
  route: {
    color: colors.muted,
    fontSize: typography.caption,
    fontWeight: "700",
  },
  title: {
    color: colors.text,
    fontSize: typography.title,
    fontWeight: "800",
  },
  subtitle: {
    color: colors.secondaryText,
    fontSize: typography.body,
    lineHeight: 24,
  },
  panel: {
    borderRadius: 8,
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.surface,
    padding: spacing.lg,
    gap: spacing.xs,
  },
  panelLabel: {
    color: colors.muted,
    fontSize: typography.caption,
    fontWeight: "700",
  },
  panelValue: {
    color: colors.text,
    fontSize: typography.heading,
    fontWeight: "800",
  },
  panelDescription: {
    color: colors.secondaryText,
    fontSize: typography.body,
    lineHeight: 22,
  },
  platforms: {
    flexDirection: "row",
    gap: spacing.sm,
  },
  platformPill: {
    borderRadius: 6,
    backgroundColor: colors.accentSoft,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
  },
  platformText: {
    color: colors.accent,
    fontSize: typography.caption,
    fontWeight: "800",
  },
  primaryAction: {
    minHeight: 52,
    borderRadius: 8,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: colors.accent,
  },
  primaryActionText: {
    color: colors.onAccent,
    fontSize: typography.body,
    fontWeight: "800",
  },
});
