// removed unused import
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_state.dart';
import '../../models/weather_models.dart';
import '../widgets/weather_details_grid.dart';
import '../widgets/hourly_forecast_strip.dart';
import '../widgets/daily_forecast_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _search = TextEditingController();
  late AnimationController _controller;
  late Animation<double> _anim;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
  _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 6000));
  _anim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  _controller.repeat(reverse: true);
  _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().init();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _search.dispose();
  _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cw = app.current;

    final gradientColors = _colorsFor(cw?.icon ?? '01d');
    // keep PageView in sync with app.pageIndex
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        final desired = app.pageIndex.clamp(0, 1 + app.favorites.length - 1);
        final current = (_pageController.page ?? _pageController.initialPage).round();
        if (current != desired) {
          _pageController.jumpToPage(desired);
        }
      }
    });

    return Scaffold(
  body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _anim.value;
          final c1 = Color.lerp(gradientColors[0], gradientColors[1], t)!;
          final c2 = Color.lerp(gradientColors[2], gradientColors[3], 1 - t)!;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c1, c2],
              ),
            ),
            child: _content(context, app),
          );
        },
      ),
    );
  }

  Widget _content(BuildContext context, AppState app) {
    if (app.error != null) {
      return Center(child: Text(app.error!, textAlign: TextAlign.center));
    }
    if (app.current == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final cw = app.current!;
    return SafeArea(
      child: PageView.builder(
        controller: _pageController,
        // page 0 = current location, pages 1..N = favorites[0..N-1]
        itemCount: 1 + app.favorites.length,
  onPageChanged: (page) => app.selectPage(page),
        itemBuilder: (context, pageIdx) {
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                const Text('Weather', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                Row(children: [
                  IconButton(
                    tooltip: 'Use current location',
                    onPressed: () async {
                      // go to page 0 (current)
                      if (_pageController.hasClients) {
                        _pageController.animateToPage(0, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
                      }
                      await app.selectPage(0);
                    },
                    icon: const Icon(Icons.my_location),
                  ),
                  IconButton(
                    tooltip: 'Toggle C/F',
                    onPressed: () => app.toggleUnits(),
                    icon: const Icon(Icons.thermostat),
                  ),
                  IconButton(
                    tooltip: 'Toggle Theme',
                    onPressed: () => app.toggleTheme(),
                    icon: const Icon(Icons.dark_mode_outlined),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => app.refresh(),
                    icon: const Icon(Icons.refresh),
                  ),
                  Builder(builder: (ctx) {
                    final city = app.activeCity ?? app.current?.city;
                    final isFav = city != null && app.favorites.contains(city);
                    return IconButton(
                      tooltip: 'Add/Remove Favorite',
                      onPressed: () async {
                        if (city == null) return;
                        final messenger = ScaffoldMessenger.of(ctx);
                        if (isFav) {
                          await app.removeFavorite(city);
                          messenger.showSnackBar(SnackBar(content: Text('Removed $city from favorites')));
                        } else {
                          await app.addFavorite(city, select: false);
                          messenger.showSnackBar(SnackBar(content: Text('Added $city to favorites')));
                        }
                      },
                      icon: Icon(isFav ? Icons.star : Icons.star_border),
                    );
                  }),
                ])
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
                Expanded(
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Search city (e.g., Montreal)',
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.08),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: (v) async {
                    if (v.trim().isNotEmpty) {
                      final city = v.trim();
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await app.searchCity(city);
                      if (!ok) {
                        messenger.showSnackBar(const SnackBar(content: Text('City not found')));
                        // ensure current-location page is visible
                        if (_pageController.hasClients) {
                          _pageController.animateToPage(0, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
                        }
                        return;
                      }
                      // add to favorites and navigate
                      await app.addFavorite(city, select: true);
                      _search.clear();
                      messenger.showSnackBar(SnackBar(content: Text('Showing $city')));
                      final target = 1 + (app.favorites.length - 1);
                      if (_pageController.hasClients) {
                        _pageController.animateToPage(target, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  final v = _search.text.trim();
                  if (v.isNotEmpty) {
                    final city = v;
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await app.searchCity(city);
                    if (!ok) {
                      messenger.showSnackBar(const SnackBar(content: Text('City not found')));
                      if (_pageController.hasClients) {
                        _pageController.animateToPage(0, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
                      }
                      return;
                    }
                    await app.addFavorite(city, select: true);
                    _search.clear();
                    messenger.showSnackBar(SnackBar(content: Text('Showing $city')));
                    final target = 1 + (app.favorites.length - 1);
                    if (_pageController.hasClients) {
                      _pageController.animateToPage(target, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
                    }
                  }
                },
                child: const Icon(Icons.search),
              )
            ],
          ),
          const SizedBox(height: 12),
          // page indicator depends on how many saved cities are available
          _pageIndicator(app),
          const SizedBox(height: 8),
          _currentHeader(cw, app),
          const SizedBox(height: 12),
          
          const Text('Next 24h (3-hourly)', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          HourlyForecastStrip(items: app.hourly),
          const SizedBox(height: 12),
          const Text('Details', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          WeatherDetailsGrid(weather: cw),
          const SizedBox(height: 12),
          const Text('Next 5 Days', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DailyForecastList(items: app.daily),
          const SizedBox(height: 24),
          const Text('Data from OpenWeatherMap (free 5 day / 3-hour API).'),
            ],
          );
        },
      ),
    );
  }

  Widget _currentHeader(CurrentWeather cw, AppState app) {
    final df = DateFormat('EEE, MMM d – HH:mm');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${cw.city}, ${cw.country}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(df.format(DateTime.now())),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('${app.displayTemp(cw.temp).toStringAsFixed(1)}${app.tempUnit()}',
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Expanded(child: Text(cw.description, style: const TextStyle(fontSize: 16))),
            ],
          ),
        ],
      ),
    );
  }

  List<Color> _colorsFor(String icon) {
    switch (icon) {
      case '01d':
        return [Colors.blue.shade300, Colors.blue.shade700, Colors.lightBlue.shade200, Colors.indigo.shade400];
      case '01n':
        return [Colors.indigo.shade700, Colors.indigo.shade900, Colors.blueGrey.shade700, Colors.black87];
      default:
        return [Colors.teal.shade300, Colors.blueGrey.shade600, Colors.blueGrey.shade400, Colors.indigo.shade700];
    }
  }

  Widget _pageIndicator(AppState app) {
    final favCount = app.favorites.length;
    // total indicators = 1 (current location) + favorites
    final total = 1 + favCount;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == app.pageIndex;
        if (i == 0) {
          // current location icon only (no circle). blue when active, white when inactive.
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Icon(
              Icons.my_location,
              size: active ? 18 : 16,
              color: active ? Colors.blue : Colors.white,
            ),
          );
        }
        // favorite dots (i-1 -> favorite index)
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 12 : 8,
          height: active ? 12 : 8,
          decoration: BoxDecoration(
            color: active ? Theme.of(context).colorScheme.primary : Colors.white54,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}
