import { StatusBar } from "expo-status-bar";
import { SafeAreaView, StyleSheet } from "react-native";
import { getInitialRoute } from "./app/routes";
import { HomeScreen } from "./features/home/HomeScreen";
import { colors } from "./theme/tokens";

export default function App() {
  const initialRoute = getInitialRoute();

  return (
    <SafeAreaView style={styles.container}>
      <HomeScreen routeTitle={initialRoute.title} />
      <StatusBar style="dark" />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
});
