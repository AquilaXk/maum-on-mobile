export const APP_ROUTES = [
  {
    key: "home",
    path: "/",
    title: "홈",
    initial: true,
  },
] as const;

export type AppRoute = (typeof APP_ROUTES)[number];
export type AppRouteKey = AppRoute["key"];

export function getInitialRoute(): AppRoute {
  return APP_ROUTES.find((route) => route.initial) ?? APP_ROUTES[0];
}
