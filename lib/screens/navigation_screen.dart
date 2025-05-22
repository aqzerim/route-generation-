import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class NavigationScreen extends StatefulWidget {
  final double lat;
  final double lng;

  const NavigationScreen(this.lat, this.lng, {super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final Location location = Location();
  final PolylinePoints polylinePoints = PolylinePoints();

  LatLng? currentLocation;
  Marker? currentMarker;
  late Marker destinationMarker;
  Map<PolylineId, Polyline> polylines = {};
  StreamSubscription<LocationData>? locationSubscription;

  // For search bar
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _initLocation();
    destinationMarker = _createMarker(
      LatLng(widget.lat, widget.lng),
      "Destination",
      BitmapDescriptor.hueCyan,
    );
  }

  @override
  void dispose() {
    locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) serviceEnabled = await location.requestService();
    if (!serviceEnabled) return;

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    final loc = await location.getLocation();
    setState(() {
      currentLocation = LatLng(loc.latitude!, loc.longitude!);
      currentMarker =
          _createMarker(currentLocation!, "You", BitmapDescriptor.hueBlue);
    });

    _subscribeToLocationUpdates();
    _fetchDirections();
  }

  void _subscribeToLocationUpdates() {
    location.changeSettings(accuracy: LocationAccuracy.high);
    locationSubscription = location.onLocationChanged.listen((loc) {
      setState(() {
        currentLocation = LatLng(loc.latitude!, loc.longitude!);
        currentMarker =
            _createMarker(currentLocation!, "You", BitmapDescriptor.hueBlue);
      });
      _moveCamera(currentLocation!);
    });
  }

  Future<void> _moveCamera(LatLng target) async {
    final controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: target,
      zoom: 16,
    )));
  }

  Marker _createMarker(LatLng position, String title, double hue) {
    return Marker(
      markerId: MarkerId(title),
      position: position,
      icon: BitmapDescriptor.defaultMarkerWithHue(hue),
      infoWindow: InfoWindow(title: title),
    );
  }

  Future<void> _fetchDirections(
      {double? newDestLat, double? newDestLng}) async {
    if (currentLocation == null) return;

    final destLat = newDestLat ?? widget.lat;
    final destLng = newDestLng ?? widget.lng;

    final result = await polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin:
            PointLatLng(currentLocation!.latitude, currentLocation!.longitude),
        destination: PointLatLng(destLat, destLng),
        mode: TravelMode.driving,
      ),
      googleApiKey:
          'Your_API_KEY', // Replace with your key or handle accordingly
    );

    if (result.points.isEmpty) {
      debugPrint('Polyline error: ${result.errorMessage}');
      return;
    }

    final polylineCoordinates =
        result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();

    final polyline = Polyline(
      polylineId: PolylineId('route'),
      color: Colors.blue,
      width: 5,
      points: polylineCoordinates,
    );

    setState(() {
      polylines[polyline.polylineId] = polyline;
      destinationMarker = _createMarker(
          LatLng(destLat, destLng), "Destination", BitmapDescriptor.hueCyan);
    });

    _moveCamera(LatLng(destLat, destLng));
  }

  // Nominatim OSM Search
  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5');

    final response = await http.get(url,
        headers: {'User-Agent': 'YourAppName/1.0 (your-email@example.com)'});

    if (response.statusCode == 200) {
      setState(() {
        _searchResults = json.decode(response.body);
      });
    } else {
      setState(() {
        _searchResults = [];
      });
    }
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((end.latitude - start.latitude) * p) / 2 +
        cos(start.latitude * p) *
            cos(end.latitude * p) *
            (1 - cos((end.longitude - start.longitude) * p)) /
            2;
    return 12742 * asin(sqrt(a));
  }

  Future<void> _openInGoogleMaps() async {
    final uri = Uri.parse(
        'google.navigation:q=${destinationMarker.position.latitude},${destinationMarker.position.longitude}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Can't open Google Maps")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: currentLocation!,
                    zoom: 16,
                  ),
                  myLocationEnabled: true,
                  markers: {
                    if (currentMarker != null) currentMarker!,
                    destinationMarker,
                  },
                  polylines: Set<Polyline>.of(polylines.values),
                  onMapCreated: (controller) =>
                      _controller.complete(controller),
                ),
                Positioned(
                  top: 50,
                  left: 15,
                  right: 15,
                  child: Material(
                    elevation: 5,
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search destination',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 15, vertical: 10),
                            border: InputBorder.none,
                          ),
                          onChanged: _searchPlaces,
                        ),
                        if (_searchResults.isNotEmpty)
                          Container(
                            height: 200,
                            color: Colors.white,
                            child: ListView.builder(
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final place = _searchResults[index];
                                return ListTile(
                                  title: Text(place['display_name']),
                                  onTap: () {
                                    final lat = double.parse(place['lat']);
                                    final lon = double.parse(place['lon']);
                                    _searchController.text =
                                        place['display_name'];
                                    setState(() {
                                      _searchResults = [];
                                      destinationMarker = _createMarker(
                                        LatLng(lat, lon),
                                        'Destination',
                                        BitmapDescriptor.hueCyan,
                                      );
                                    });
                                    _fetchDirections(
                                        newDestLat: lat, newDestLng: lon);
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: BackButton(),
                ),
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FloatingActionButton(
                    backgroundColor: Colors.blue,
                    onPressed: _openInGoogleMaps,
                    child: const Icon(Icons.navigation_outlined),
                  ),
                ),
              ],
            ),
    );
  }
}
