import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import 'package:weather_app/secrets.dart';
import 'package:weather_app/additional_info_item.dart';
import 'package:weather_app/weather_forecast_item.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  late Future<Map<String, dynamic>> weather;
  final TextEditingController searchController = TextEditingController();
  String cityName = 'Cuttack'; // Default city
  List<String> citySuggestions = [];

  Future<Map<String, dynamic>> getCurrentWeather(String city) async {
    try {
      final res = await http.get(
        Uri.parse(
            'https://api.openweathermap.org/data/2.5/forecast?q=$city,IN&APPID=$openWeatherApiKey'),
      );
      final data = jsonDecode(res.body);
      if (data['cod'] != '200') {
        throw 'City not found. Try another city.';
      }
      return data;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> fetchCitySuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        citySuggestions = []; // Clear suggestions when query is empty
      });
      return;
    }

    final url = Uri.parse(
        'http://api.geonames.org/searchJSON?name_startsWith=$query&country=IN&featureClass=P&maxRows=20&username=aditya_raj');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final cities = data['geonames'] as List;
      setState(() {
        citySuggestions =
            cities.map((city) => city['name'].toString()).toList();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    weather = getCurrentWeather(cityName);
  }

  void searchWeather(String selectedCity) {
    FocusScope.of(context).unfocus(); // Hide keyboard
    setState(() {
      cityName = selectedCity;
      searchController.text = selectedCity;
      weather = getCurrentWeather(cityName);
      citySuggestions = []; // Clear suggestions after selection
    });
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderSide: BorderSide(color: Colors.white),
      borderRadius: BorderRadius.all(Radius.circular(50)),
    );

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: searchController,
          onChanged: (value) => fetchCitySuggestions(value),
          decoration: InputDecoration(
            hintText: 'Search city...',
            border: border,
            enabledBorder: border,
            focusedBorder: border,
            suffixIcon: IconButton(
              icon: Icon(Icons.search),
              onPressed: () => searchWeather(searchController.text),
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                weather = getCurrentWeather(cityName);
              });
            },
            icon: Icon(Icons.refresh),
          )
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard
        child: SingleChildScrollView(
          physics: ClampingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              children: [
                // City Suggestions (Max Height: Half Screen)
                if (citySuggestions.isNotEmpty)
                  SizedBox(
                    height: citySuggestions.length * 40.0 >
                            MediaQuery.of(context).size.height * 0.4
                        ? MediaQuery.of(context).size.height *
                            0.5 // Max height (half screen)
                        : citySuggestions.length *
                            50.0, // Adjust height dynamically
                    child: Card(
                      elevation: 2,
                      color: const Color.fromARGB(31, 61, 61, 61),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                        // Rounded bottom corners
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: citySuggestions.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            // tileColor: Colors.white,
                            title: Text(citySuggestions[index]),
                            onTap: () => searchWeather(citySuggestions[index]),
                          );
                        },
                      ),
                    ),
                  ),
                SizedBox(
                  height: 15,
                ),
                // Weather Data (Scrollable)
                FutureBuilder(
                  future: weather,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text(snapshot.error.toString()));
                    }

                    final data = snapshot.data!;
                    final currentWeatherData = data['list'][0];

                    final currentTemp = currentWeatherData['main']['temp'];
                    final currentSky = currentWeatherData['weather'][0]['main'];
                    final currentPressure =
                        currentWeatherData['main']['pressure'];
                    final currentWindSpeed =
                        currentWeatherData['wind']['speed'];
                    final currentHumidity =
                        currentWeatherData['main']['humidity'];
                    // final currentT = int.parse(currentTemp);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main weather card
                        SizedBox(
                          width: double.infinity,
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                            elevation: 1,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    children: [
                                      Text(
                                        '$currentTemp K',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Icon(
                                        currentSky == 'Clouds' ||
                                                currentSky == 'Rain'
                                            ? Icons.cloud
                                            : Icons.sunny,
                                        size: 64,
                                      ),
                                      SizedBox(height: 14),
                                      Text('$currentSky',
                                          style: TextStyle(fontSize: 32)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),

                        // Weather Forecast
                        Text(
                          'Weather Forecast',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 16),
                        SizedBox(
                          height: 140,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: 5,
                            itemBuilder: (context, index) {
                              final hourlyForecast = data['list'][index + 1];
                              final hourlySky =
                                  hourlyForecast['weather'][0]['main'];
                              final hourlyTemp =
                                  hourlyForecast['main']['temp'].toString();
                              final time =
                                  DateTime.parse(hourlyForecast['dt_txt']);

                              return WeatherForecastItem(
                                time: DateFormat.j().format(time),
                                temperature: hourlyTemp,
                                icon:
                                    hourlySky == 'Clouds' || hourlySky == 'Rain'
                                        ? Icons.cloud
                                        : Icons.sunny,
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 20),

                        // Additional Information
                        Text(
                          'Additional Information',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            AdditionalInfoItem(
                                icon: Icons.water_drop,
                                label: 'Humidity',
                                value: '$currentHumidity%'),
                            AdditionalInfoItem(
                                icon: Icons.air,
                                label: 'Wind Speed',
                                value: '$currentWindSpeed m/s'),
                            AdditionalInfoItem(
                                icon: Icons.beach_access,
                                label: 'Pressure',
                                value: '$currentPressure hPa'),
                          ],
                        ),
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
