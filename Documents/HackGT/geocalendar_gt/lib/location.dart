import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocalendar_gt/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:geocalendar_gt/gt_buildings.dart';

class LocationService {
  // The list of GT buildings is now a member of the class
  final List<GTBuilding> gtBuildings = kGtBuildings;

  final Set<String> _recentlyNotified = {};
  final Map<String, DateTime> _lastNotified = {};
  final Duration _cooldown = const Duration(minutes: 30);

  // Local cache of reminders kept in sync via a snapshot listener.
  final List<Map<String, dynamic>> _reminderCache = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _remSub;

  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied.');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
      return null;
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  void startLocationListener({bool firebaseReady = false}) {
    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      // smaller filter to be more responsive; geofencing recommended for production
      distanceFilter: 50,
    );

    // start listening to Firestore reminders and keep local cache in sync
    if (firebaseReady) {
      try {
        _subscribeReminders();
      } catch (e) {
        debugPrint('Skipping Firestore reminder subscription: $e');
      }
    } else {
      debugPrint('Firebase not ready – skipping reminder subscription');
    }

    Geolocator.getPositionStream(locationSettings: locationSettings).listen((
      Position position,
    ) {
      debugPrint("User moved to: ${position.latitude}, ${position.longitude}");
      _checkReminders(position);
    });
  }

  void stopLocationListener() {
    _remSub?.cancel();
    _remSub = null;
  }

  void _subscribeReminders() {
    _remSub ??= FirebaseFirestore.instance
        .collection('reminders')
        .snapshots()
        .listen((snapshot) {
          _reminderCache.clear();
          for (final doc in snapshot.docs) {
            final data = doc.data();
            // normalize a reminder record: id, title, location (GeoPoint), radius (meters)
            if (data['location'] == null) continue;
            final reminder = <String, dynamic>{
              'id': doc.id,
              'title': data['title'] ?? '',
              'location': data['location'] as GeoPoint,
              'radius': (data['radius'] as num?)?.toDouble() ?? 200.0,
            };
            _reminderCache.add(reminder);
          }
          debugPrint('Reminders cache updated: ${_reminderCache.length} items');
        }, onError: (e) => debugPrint('Reminder subscription error: $e'));
  }

  // 2. This function is now fixed and checks both lists
  Future<void> _checkReminders(Position userPosition) async {
    // --- Check against hardcoded GT Buildings ---
    for (final building in gtBuildings) {
      final reminderPoint = GeoPoint(building.lat, building.lng);
      final double distanceInMeters = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        reminderPoint.latitude,
        reminderPoint.longitude,
      );

      if (distanceInMeters < 200) {
        debugPrint('✅ User is close to (Hardcoded): "${building.name}".');
        final id = 'building:${building.name}';
        if (!_recentlyNotified.contains(id)) {
          await NotificationService().showNotification(
            id.hashCode,
            'Nearby place',
            'You are ${distanceInMeters.toStringAsFixed(0)}m from ${building.name}',
          );
          _recentlyNotified.add(id);
        }
      }
    }

    // --- Check against cached Firestore reminders ---
    for (final reminder in _reminderCache) {
      try {
        final reminderPoint = reminder['location'] as GeoPoint;
        final radius = (reminder['radius'] as double?) ?? 200.0;
        final double distanceInMeters = Geolocator.distanceBetween(
          userPosition.latitude,
          userPosition.longitude,
          reminderPoint.latitude,
          reminderPoint.longitude,
        );

        final id = 'reminder:${reminder['id']}';

        // If user left the area (with hysteresis), allow future notifications
        if (distanceInMeters > radius + 50) {
          _lastNotified.remove(id);
          _recentlyNotified.remove(id);
        }

        if (distanceInMeters < radius) {
          debugPrint('✅ User is close to (Firestore): "${reminder['title']}".');
          if (_canNotify(id)) {
            await NotificationService().showNotification(
              id.hashCode,
              'Reminder nearby',
              'You are ${distanceInMeters.toStringAsFixed(0)}m from ${reminder['title'] ?? 'a reminder'}',
            );
            _markNotified(id);
          }
        }
      } catch (e) {
        debugPrint('Error checking reminder: $e');
      }
    }
  }

  bool _canNotify(String id) {
    final last = _lastNotified[id];
    if (last == null) return true;
    return DateTime.now().difference(last) > _cooldown;
  }

  void _markNotified(String id) {
    _lastNotified[id] = DateTime.now();
    _recentlyNotified.add(id);
  }
}
