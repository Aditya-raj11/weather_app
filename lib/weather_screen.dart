import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import 'package:weather_app/secrets.dart';
import 'package:weather_app/additional_info_item.dart';
import 'package:weather_app/weather_forecast_item.dart';
import 'package:weather_app/main.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  late Future<Map<String, dynamic>> weather;
  final TextEditingController _searchController = TextEditingController();
  String _cityName = 'Cuttack';
  List<String> _citySuggestions = [];
  bool _isCelsius = true;

  // --- Helpers ---

  static String _kelvinToString(double k, bool celsius) {
    if (celsius) {
      return '${(k - 273.15).toStringAsFixed(1)}°C';
    }
    return '${((k - 273.15) * 9 / 5 + 32).toStringAsFixed(1)}°F';
  }

  static String _msToKmph(num ms) => '${(ms * 3.6).toStringAsFixed(1)} km/h';

  String _convertTemp(dynamic kelvin) =>
      _kelvinToString((kelvin as num).toDouble(), _isCelsius);

  static IconData _skyIcon(String sky) =>
      (sky == 'Clouds' || sky == 'Rain') ? Icons.cloud : Icons.sunny;

  // --- API calls ---

  Future<Map<String, dynamic>> _fetchWeather(String city) async {
    final res = await http.get(Uri.parse(
        'https://api.openweathermap.org/data/2.5/forecast?q=$city,IN&APPID=$openWeatherApiKey'));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['cod'] != '200') throw 'City not found. Try another city.';
    return data;
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() => _citySuggestions = []);
      return;
    }
    final res = await http.get(Uri.parse(
        'http://api.geonames.org/searchJSON?name_startsWith=$query&country=IN&featureClass=P&maxRows=20&username=aditya_raj'));
    if (res.statusCode == 200) {
      final cities = (jsonDecode(res.body)['geonames'] as List);
      setState(() =>
          _citySuggestions = cities.map((c) => c['name'].toString()).toList());
    }
  }

  // --- State changes ---

  @override
  void initState() {
    super.initState();
    weather = _fetchWeather(_cityName);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectCity(String city) {
    FocusScope.of(context).unfocus();
    setState(() {
      _cityName = city;
      _searchController.text = city;
      weather = _fetchWeather(city);
      _citySuggestions = [];
    });
  }

  void _refresh() => setState(() => weather = _fetchWeather(_cityName));

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final appState = MyApp.of(context);
    final isDark = appState.isDarkMode;

    final inputBorder = OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.white),
      borderRadius: BorderRadius.circular(50),
    );

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          onChanged: _fetchSuggestions,
          onSubmitted: _selectCity,
          decoration: InputDecoration(
            hintText: 'Search city...',
            border: inputBorder,
            enabledBorder: inputBorder,
            focusedBorder: inputBorder,
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _selectCity(_searchController.text),
            ),
          ),
        ),
        actions: [
          // °C / °F chip
          ActionChip(
            label: Text(
              _isCelsius ? '°C' : '°F',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () => setState(() => _isCelsius = !_isCelsius),
          ),
          const SizedBox(width: 4),
          // Theme toggle
          IconButton(
            onPressed: appState.toggleTheme,
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: isDark ? 'Light Mode' : 'Dark Mode',
          ),
          // Refresh
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -- Suggestions dropdown --
                if (_citySuggestions.isNotEmpty)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: Card(
                      elevation: 4,
                      margin: EdgeInsets.zero,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(bottom: Radius.circular(16)),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _citySuggestions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) => ListTile(
                          dense: true,
                          title: Text(_citySuggestions[i]),
                          onTap: () => _selectCity(_citySuggestions[i]),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // -- Main weather Future --
                FutureBuilder<Map<String, dynamic>>(
                  future: weather,
                  builder: (_, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 300,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return SizedBox(
                        height: 200,
                        child: Center(
                          child: Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final data = snapshot.data!;
                    final current = data['list'][0];
                    final currentTemp = current['main']['temp'];
                    final currentSky = current['weather'][0]['main'] as String;
                    final humidity = current['main']['humidity'];
                    final windSpeed = current['wind']['speed'];
                    final pressure = current['main']['pressure'];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // -- Main card --
                        SizedBox(
                          width: double.infinity,
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                            elevation: 2,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 24, horizontal: 16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _convertTemp(currentTemp),
                                        style: const TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Icon(
                                        _skyIcon(currentSky),
                                        size: 80,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        currentSky,
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // -- Forecast heading --
                        const Text(
                          'Weather Forecast',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),

                        // -- Forecast list --
                        SizedBox(
                          height: 140,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: 5,
                            itemBuilder: (_, i) {
                              final item = data['list'][i + 1];
                              final sky = item['weather'][0]['main'] as String;
                              final time =
                                  DateTime.parse(item['dt_txt'] as String);
                              return WeatherForecastItem(
                                time: DateFormat.j().format(time),
                                temperature: _convertTemp(item['main']['temp']),
                                icon: _skyIcon(sky),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 24),

                        // -- Additional info heading --
                        const Text(
                          'Additional Information',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),

                        // -- Additional info row --
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            AdditionalInfoItem(
                              icon: Icons.water_drop,
                              label: 'Humidity',
                              value: '$humidity%',
                            ),
                            AdditionalInfoItem(
                              icon: Icons.air,
                              label: 'Wind Speed',
                              value: _msToKmph(windSpeed as num),
                            ),
                            AdditionalInfoItem(
                              icon: Icons.beach_access,
                              label: 'Pressure',
                              value: '$pressure hPa',
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
