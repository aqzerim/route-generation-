import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SearchBar extends StatefulWidget {
  final Function(double lat, double lon) onPlaceSelected;

  const SearchBar({required this.onPlaceSelected, super.key});

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _searchResults = [];

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'Search place',
            border: OutlineInputBorder(),
          ),
          onChanged: _searchPlaces,
        ),
        if (_searchResults.isNotEmpty)
          Container(
            height: 200,
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final place = _searchResults[index];
                return ListTile(
                  title: Text(place['display_name']),
                  onTap: () {
                    // Pass selected place lat/lon to parent
                    widget.onPlaceSelected(
                        double.parse(place['lat']), double.parse(place['lon']));
                    _controller.text = place['display_name'];
                    setState(() {
                      _searchResults = [];
                    });
                  },
                );
              },
            ),
          )
      ],
    );
  }
}
