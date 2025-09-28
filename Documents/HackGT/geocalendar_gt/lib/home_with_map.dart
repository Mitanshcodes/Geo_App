import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geocalendar_gt/task_provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocalendar_gt/location.dart';
import 'package:geocalendar_gt/email_scanner.dart';

class HomeWithMap extends StatelessWidget {
  const HomeWithMap({super.key});

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskProvider>().tasks;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // Left navigation rail
            NavigationRail(
              backgroundColor: const Color(0xFF071023),
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.map),
                  label: Text('Map'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.list),
                  label: Text('Tasks'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),

            // Middle: map view
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Card(
                  color: const Color(0xFF0B1220),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 8,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Positioned.fill(child: GoogleMapWidget(tasks: tasks)),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),

            // Right: chat/task panel
            Container(
              width: 360,
              color: const Color(0xFF071226),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Tasks',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Add Task',
                          onPressed: () => Navigator.pushNamed(context, '/add'),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                        IconButton(
                          tooltip: 'Scan Gmail (Packages)',
                          onPressed: () async {
                            await EmailScanner().scanPackages(context);
                            // Optionally show feedback
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Gmail scan completed'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.mark_email_unread_outlined),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: tasks.length,
                      itemBuilder: (c, i) {
                        final t = tasks[i];
                        String initials = '';
                        if (t.title.trim().isNotEmpty) {
                          final parts = t.title.trim().split(RegExp(r'\s+'));
                          initials = parts
                              .take(2)
                              .map(
                                (s) => s.isNotEmpty ? s[0].toUpperCase() : '',
                              )
                              .join();
                        }
                        return Card(
                          color: const Color(0xFF0E1622),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: InkWell(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: const Color(0xFF0B1220),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                ),
                                builder: (sheetCtx) {
                                  final titleCtrl = TextEditingController(
                                    text: t.title,
                                  );
                                  final locCtrl = TextEditingController(
                                    text: t.locationText,
                                  );
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: MediaQuery.of(
                                        sheetCtx,
                                      ).viewInsets.bottom,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Edit task',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          TextField(
                                            controller: titleCtrl,
                                            decoration: const InputDecoration(
                                              labelText: 'Title',
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextField(
                                            controller: locCtrl,
                                            decoration: const InputDecoration(
                                              labelText: 'Location',
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              ElevatedButton.icon(
                                                onPressed: () {
                                                  // save
                                                  context
                                                      .read<TaskProvider>()
                                                      .updateTask(
                                                        t.id,
                                                        title: titleCtrl.text
                                                            .trim(),
                                                        locationText: locCtrl
                                                            .text
                                                            .trim(),
                                                      );
                                                  Navigator.of(sheetCtx).pop();
                                                },
                                                icon: const Icon(Icons.save),
                                                label: const Text('Save'),
                                              ),
                                              const SizedBox(width: 12),
                                              OutlinedButton.icon(
                                                onPressed: () {
                                                  // delete
                                                  context
                                                      .read<TaskProvider>()
                                                      .removeTask(t.id);
                                                  Navigator.of(sheetCtx).pop();
                                                },
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                                label: const Text('Delete'),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      Colors.redAccent,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Coordinates: ${t.lat.toStringAsFixed(6)}, ${t.lng.toStringAsFixed(6)}',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 8,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor:
                                        Colors.deepPurpleAccent.shade200,
                                    child: Text(
                                      initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          t.locationText.isNotEmpty
                                              ? t.locationText
                                              : 'No location',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white12,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '${t.lat.toStringAsFixed(3)}, ${t.lng.toStringAsFixed(3)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // NLP quick input at bottom
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Quick Add (NLP)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        // reuse the AddTaskScreen's nlp controller approach by opening the Add screen
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, '/add'),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Open NLP Composer'),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GoogleMapWidget extends StatefulWidget {
  final List tasks;
  const GoogleMapWidget({super.key, required this.tasks});

  @override
  State<GoogleMapWidget> createState() => _GoogleMapWidgetState();
}

class _GoogleMapWidgetState extends State<GoogleMapWidget> {
  GoogleMapController? _controller;

  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(33.7756, -84.398),
    zoom: 15.0,
  );

  Set<Marker> _markersFromTasks() {
    final markers = <Marker>{};
    for (var t in widget.tasks) {
      final m = Marker(
        markerId: MarkerId(t.id),
        position: LatLng(t.lat, t.lng),
        infoWindow: InfoWindow(title: t.title, snippet: t.locationText),
      );
      markers.add(m);
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: _initialCamera,
          onMapCreated: (c) => _controller = c,
          myLocationEnabled: true,
          markers: _markersFromTasks(),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: FloatingActionButton(
            onPressed: () async {
              final pos = await LocationService().getCurrentPosition();
              if (pos != null && _controller != null) {
                _controller!.animateCamera(
                  CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
                );
              }
            },
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}
