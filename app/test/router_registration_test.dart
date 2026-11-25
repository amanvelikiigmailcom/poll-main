import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flyprox_app/router/app_router.dart';
import 'package:mocktail/mocktail.dart';

class _Context extends Mock implements BuildContext {}

class _RouterState extends Mock implements GoRouterState {}

Iterable<GoRoute> registeredRoutes(List<RouteBase> routes) sync* {
  for (final route in routes) {
    if (route is GoRoute) {
      yield route;
      yield* registeredRoutes(route.routes);
    } else if (route is ShellRoute) {
      yield* registeredRoutes(route.routes);
    } else if (route is StatefulShellRoute) {
      for (final branch in route.branches) {
        yield* registeredRoutes(branch.routes);
      }
    }
  }
}

void main() {
  test(
    'current onboarding, game, social and settings routes stay registered',
    () {
      final router = createAppRouter();
      addTearDown(router.dispose);
      final paths = registeredRoutes(
        router.configuration.routes,
      ).map((route) => route.path).toSet();

      expect(
        paths,
        containsAll([
          AppRoutes.splash,
          AppRoutes.onboarding,
          AppRoutes.phone,
          AppRoutes.invitationCode,
          AppRoutes.otp,
          AppRoutes.age,
          AppRoutes.ageBlocked,
          AppRoutes.profileDetails,
          AppRoutes.schoolSetup,
          AppRoutes.schoolWaiting,
          AppRoutes.namesEntry,
          AppRoutes.username,
          AppRoutes.pushPrompt,
          AppRoutes.home,
          AppRoutes.vote,
          AppRoutes.timer,
          AppRoutes.starReceived,
          AppRoutes.search,
          AppRoutes.likesFilled,
          AppRoutes.likesEmpty,
          AppRoutes.likesResult,
          AppRoutes.likesShare,
          AppRoutes.profile,
          AppRoutes.editProfile,
          AppRoutes.collection,
          AppRoutes.invite,
          AppRoutes.premium,
          AppRoutes.settings,
          AppRoutes.activity,
          AppRoutes.friends,
          AppRoutes.friendRequests,
          AppRoutes.blockedUsers,
          AppRoutes.notificationsSettings,
          AppRoutes.languageSettings,
          AppRoutes.settingsQuiz,
          AppRoutes.deleteAccount,
          AppRoutes.privacy,
          AppRoutes.terms,
          '/p/:handle',
          '/people/:id',
        ]),
      );
      for (final retiredPath in [
        '/register',
        '/location',
        '/school',
        '/class',
        '/contacts',
        '/photo',
        '/before-vote',
        '/before-vote-2',
        '/star-taking',
      ]) {
        expect(paths, isNot(contains(retiredPath)));
      }
    },
  );

  test(
    'retired premium result URL retains its home compatibility redirect',
    () async {
      final router = createAppRouter();
      addTearDown(router.dispose);
      final route = registeredRoutes(
        router.configuration.routes,
      ).singleWhere((route) => route.path == AppRoutes.premiumResult);

      expect(route.redirect, isNotNull);
      expect(await route.redirect!(_Context(), _RouterState()), AppRoutes.home);
    },
  );
}
