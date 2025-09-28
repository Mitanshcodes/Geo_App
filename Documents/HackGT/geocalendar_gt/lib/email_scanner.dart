import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geocalendar_gt/task.dart';
import 'package:geocalendar_gt/task_provider.dart';
import 'package:geocalendar_gt/gt_buildings.dart';

class EmailScanner {
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      await GoogleSignIn.instance.initialize();
      _initialized = true;
    } catch (e) {
      debugPrint('GoogleSignIn initialize failed: $e');
    }
  }

  Future<GoogleSignInAccount?> _signInInteractive(List<String> scopes) async {
    await _ensureInitialized();
    try {
      // First attempt a lightweight restore (may be immediate or null)
      final lightweight = await GoogleSignIn.instance
          .attemptLightweightAuthentication(reportAllExceptions: false);
      if (lightweight != null) return lightweight;
      // Fallback to full interactive authenticate specifying scope hints
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: scopes,
      );
      return account;
    } catch (e) {
      debugPrint('GoogleSignIn authenticate failed: $e');
      return null;
    }
  }

  /// Scans Gmail for package-related emails and creates reminders.
  /// Also supports generic reminder keywords (legacy behavior) and pushes a local Task.
  Future<void> scanPackages(BuildContext context) async {
    const scopes = [
      'https://www.googleapis.com/auth/gmail.readonly',
      'email',
      'openid',
    ];
    final account = await _signInInteractive(scopes);
    if (account == null) return;

    // Acquire authorization headers (contains access token) for Gmail scope.
    final authClient = GoogleSignIn.instance.authorizationClient;
    final authHeaders = await authClient.authorizationHeaders([
      'https://www.googleapis.com/auth/gmail.readonly',
    ], promptIfNecessary: true);
    if (authHeaders == null) {
      debugPrint('Failed to obtain Gmail authorization headers.');
      return;
    }
    final authorization = authHeaders['Authorization'];
    if (authorization == null || !authorization.startsWith('Bearer ')) {
      debugPrint('Authorization header missing bearer token.');
      return;
    }
    final accessToken = authorization.substring('Bearer '.length);

    // Sign into Firebase (if configured) for Firestore writes.
    try {
      final auth = account.authentication;
      final credential = GoogleAuthProvider.credential(idToken: auth.idToken);
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Firebase auth (optional) failed: $e');
    }

    final listUri = Uri.parse(
      'https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=50',
    );
    final listResp = await http.get(
      listUri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (listResp.statusCode != 200) {
      debugPrint('Gmail list failed: ${listResp.statusCode} ${listResp.body}');
      return;
    }
    final listData = json.decode(listResp.body) as Map<String, dynamic>;
    final messages =
        (listData['messages'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // Heuristic keyword sets
    const packageKeywords = [
      'package',
      'delivered',
      'out for delivery',
      'shipped',
      'tracking',
      'parcel',
      'order',
      'ready for pickup',
      'available for pickup',
    ];
    const vendorKeywords = [
      'amazon',
      'ups',
      'fedex',
      'usps',
      'dhl',
      'shein',
      'ebay',
      'walmart',
      'target',
    ];
    const genericReminderKeywords = [
      'remind',
      'reminder',
      'meeting',
      'appointment',
    ];

    // choose a campus pickup location (arbitrary default: Student Center if present)
    final pickup = kGtBuildings.firstWhere(
      (b) => b.name.toLowerCase().contains('student center'),
      orElse: () => kGtBuildings.first,
    );
    final taskProvider = context.read<TaskProvider>();

    for (final msg in messages) {
      final id = msg['id'] as String?;
      if (id == null) continue;

      // Skip if already parsed.
      try {
        final existing = await FirebaseFirestore.instance
            .collection('parsedMessages')
            .doc(id)
            .get();
        if (existing.exists) continue;
      } catch (_) {
        // Firestore may not be initialized; continue local processing.
      }

      final detailUri = Uri.parse(
        'https://gmail.googleapis.com/gmail/v1/users/me/messages/$id?format=full',
      );
      final mResp = await http.get(
        detailUri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (mResp.statusCode != 200) continue;
      final mData = json.decode(mResp.body) as Map<String, dynamic>;

      final payload = mData['payload'] as Map<String, dynamic>?;
      final headers =
          (payload?['headers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      String subject = '';
      String from = '';
      for (final h in headers) {
        final name = (h['name'] as String?)?.toLowerCase();
        if (name == 'subject') subject = h['value'] as String? ?? '';
        if (name == 'from') from = h['value'] as String? ?? '';
      }
      final snippet = (mData['snippet'] as String? ?? '').toLowerCase();
      final subjectLower = subject.toLowerCase();
      final combined = '$subjectLower\n$snippet';

      bool isPackage =
          packageKeywords.any((k) => combined.contains(k)) ||
          vendorKeywords.any((k) => combined.contains(k));
      bool isGenericReminder =
          !isPackage &&
          genericReminderKeywords.any((k) => combined.contains(k));

      if (!isPackage && !isGenericReminder) continue;

      // Derive vendor & status for packages.
      String? vendor;
      String? status;
      if (isPackage) {
        vendor = vendorKeywords.firstWhere(
          (v) => combined.contains(v),
          orElse: () => 'package',
        );
        if (combined.contains('delivered')) {
          status = 'delivered';
        } else if (combined.contains('out for delivery')) {
          status = 'out for delivery';
        } else if (combined.contains('shipped')) {
          status = 'shipped';
        } else if (combined.contains('ready for pickup') ||
            combined.contains('available for pickup')) {
          status = 'pickup';
        }
      }

      // Build Firestore doc (optional if Firestore available)
      final reminderData = <String, dynamic>{
        'title': subject.isNotEmpty
            ? subject
            : (isPackage
                  ? 'Package from ${vendor ?? 'sender'}'
                  : 'Email reminder from $from'),
        'sourceEmailId': id,
        'createdAt': FieldValue.serverTimestamp(),
        'category': isPackage ? 'package' : 'generic',
        if (vendor != null) 'vendor': vendor,
        if (status != null) 'status': status,
      };
      try {
        await FirebaseFirestore.instance
            .collection('reminders')
            .add(reminderData);
        await FirebaseFirestore.instance
            .collection('parsedMessages')
            .doc(id)
            .set({'parsedAt': FieldValue.serverTimestamp()});
      } catch (e) {
        debugPrint('Firestore write skipped/failed: $e');
      }

      // Always push a local Task so user sees it immediately.
      final taskId = id; // reuse Gmail id for stability
      final existingTask = taskProvider.tasks.any((t) => t.id == taskId);
      if (!existingTask) {
        final task = Task(
          id: taskId,
          title: isPackage
              ? 'Package: ${subject.isNotEmpty ? subject : vendor ?? 'Package'}'
              : (subject.isNotEmpty ? subject : 'Reminder from email'),
          locationText: isPackage ? 'Pickup: ${pickup.name}' : 'Email',
          lat: pickup.lat,
          lng: pickup.lng,
        );
        taskProvider.addTask(task);
      }
      debugPrint(
        'Added ${isPackage ? 'package' : 'reminder'} task from email $id',
      );
    }
  }
}
