import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maum_on_mobile_front/core/platform/deep_link_channel.dart';
import 'package:maum_on_mobile_front/core/platform/external_url_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExternalUrlLauncher', () {
    const channel = MethodChannel(urlLauncherChannelName);
    late List<MethodCall> calls;
    late bool nativeResult;

    setUp(() {
      calls = <MethodCall>[];
      nativeResult = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return nativeResult;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('launches allowlisted https, http, tel, and mailto URIs', () async {
      expect(
        await launchExternalUri(Uri.parse('https://maum-on.app/privacy')),
        isTrue,
      );
      expect(
        await launchExternalUri(Uri.parse('http://localhost:8080/oauth')),
        isTrue,
      );
      expect(await launchExternalUri(Uri(scheme: 'tel', path: '109')), isTrue);
      expect(
        await launchExternalUri(
          Uri(scheme: 'mailto', path: 'support@maum-on.app'),
        ),
        isTrue,
      );

      expect(calls, hasLength(4));
      expect(calls[0].method, 'launchUrl');
      expect(calls[0].arguments, {'url': 'https://maum-on.app/privacy'});
      expect(calls[2].arguments, {'url': 'tel:109'});
      expect(calls[3].arguments, {'url': 'mailto:support@maum-on.app'});
    });

    test('blocks unsafe or malformed URIs before invoking native channel',
        () async {
      final disallowed = <Uri>[
        Uri.parse('javascript:alert(1)'),
        Uri.parse('file:///etc/passwd'),
        Uri.parse('data:text/plain,hello'),
        Uri.parse('intent://scan/#Intent;end'),
        Uri.parse('https://'),
        Uri(scheme: 'http', path: '/no-host'),
        Uri(scheme: 'tel', path: ''),
        Uri(scheme: 'mailto', path: '   '),
      ];

      for (final uri in disallowed) {
        expect(await launchExternalUri(uri), isFalse);
      }
      expect(calls, isEmpty);
    });

    test('returns false on MissingPluginException or PlatformException',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      expect(
        await launchExternalUri(Uri.parse('https://maum-on.app/terms')),
        isFalse,
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'UNAVAILABLE');
      });
      expect(
        await launchExternalUri(Uri.parse('https://maum-on.app/terms')),
        isFalse,
      );
    });
  });

  group('MethodChannelDeepLinkSource', () {
    const channel = MethodChannel(deepLinksChannelName);
    late String? initialLink;

    setUp(() {
      initialLink = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getInitialLink') {
          final current = initialLink;
          initialLink = null;
          return current;
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('reads initial link and delivers live onDeepLink stream events',
        () async {
      initialLink = 'maumon://auth/callback?provider=kakao&code=c1&state=s1';
      final source = MethodChannelDeepLinkSource();
      addTearDown(source.dispose);

      final initial = await source.getInitialUri();
      expect(initial?.scheme, 'maumon');
      expect(initial?.queryParameters['code'], 'c1');
      expect(await source.getInitialUri(), isNull);

      final received = <Uri>[];
      final sub = source.uriStream.listen(received.add);
      addTearDown(sub.cancel);

      const codec = StandardMethodCodec();
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        deepLinksChannelName,
        codec.encodeMethodCall(
          const MethodCall(
            'onDeepLink',
            'maumon://auth/callback?provider=apple&code=c2&state=s2',
          ),
        ),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.single.queryParameters['provider'], 'apple');
      expect(received.single.queryParameters['code'], 'c2');
    });

    test('returns null cleanly when plugin is missing', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      final source = MethodChannelDeepLinkSource();
      addTearDown(source.dispose);

      expect(await source.getInitialUri(), isNull);
    });
  });
}
