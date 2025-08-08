import 'package:app_links/app_links.dart'; // Replace uni_links with app_links
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  StreamSubscription<Uri>? _linkSubscription; // Updated stream type
  late AppLinks _appLinks; // AppLinks instance
  String? pendingInviteId;
  Uri? _lastHandledUri;

  void init(BuildContext context) {
    _appLinks = AppLinks(); // Initialize AppLinks

    // Handle deep links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
      _handleUri(uri, context);
    }, onError: (err) {
      debugPrint("Deep link error: $err");
    });

    // Handle deep link on cold start
    _checkInitialUri(context);
  }

  Future<void> _checkInitialUri(BuildContext context) async {
    try {
      final Uri? uri = await _appLinks.getInitialLink();
      if (uri != null) {
        _handleUri(uri, context);
      }
    } catch (e) {
      debugPrint("Failed to get initial URI: $e");
    }
  }

  void _handleUri(Uri uri, BuildContext context) {
    if (_lastHandledUri == uri) {
      // This URI was already handled, ignore to prevent duplicate handling.
      return;
    }
    _lastHandledUri = uri;

    switch (uri.host) {
      case "accept-invite":
        final inviteId = uri.queryParameters['invite_id'];
        if (inviteId != null && inviteId.isNotEmpty) {
          _processInvite(inviteId, context);
        }
        break;

      case "password-reset":
        Navigator.pushNamed(context, '/reset-password');
        break;

      default:
        debugPrint("Unknown deep link host: ${uri.host}");
    }
  }

  Future<void> _processInvite(String inviteId, BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      pendingInviteId = inviteId;
      Navigator.pushNamed(context, '/'); 
    } else {
      await _acceptInvite(inviteId, context);
    }
  }

  Future<void> acceptPendingInvite(BuildContext context) async {
    if (pendingInviteId != null) {
      final inviteId = pendingInviteId!;
      pendingInviteId = null;
      await _acceptInvite(inviteId, context);
    }
  }

  Future<void> _acceptInvite(String inviteId, BuildContext context) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'accept_invite',
        params: {'invite_id': inviteId},
      );

      if (response is Map && response['status'] == 'SUCCESS') {
        final householdId = response['household_id'];
        if (householdId != null && householdId is String) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('selected_household_id', householdId);

          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invite invalid or expired")),
      );
    } catch (e) {
      debugPrint("Error accepting invite: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to accept invite: $e")),
      );
    }
  }

  void dispose() {
    _linkSubscription?.cancel(); // Cancel the subscription
  }
}