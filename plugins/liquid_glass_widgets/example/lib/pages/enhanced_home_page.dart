import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:liquid_glass_widgets_example/constants/glass_settings.dart';

/// Enhanced showcase home page with beautiful demos
class EnhancedHomePage extends StatefulWidget {
  const EnhancedHomePage({super.key});

  @override
  State<EnhancedHomePage> createState() => _EnhancedHomePageState();
}

class _EnhancedHomePageState extends State<EnhancedHomePage> {
  int _selectedPropertyIndex = 0;

  @override
  Widget build(BuildContext context) {
    return AdaptiveLiquidGlassLayer(
      settings: RecommendedGlassSettings.standard,
      quality: GlassQuality.standard,
      child: CustomScrollView(
        slivers: [
          // Hero Section
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: _HeroSection(),
            ),
          ),

          // Quick Feature Showcase
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Interactive Widgets',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to explore',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _QuickFeatureShowcase(),
                ],
              ),
            ),
          ),

          // Real-World Example: Property Cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'Real-World Example',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Property rental interface',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _PropertyShowcase(
                    selectedIndex: _selectedPropertyIndex,
                    onPropertySelected: (index) {
                      setState(() => _selectedPropertyIndex = index);
                    },
                  ),
                ],
              ),
            ),
          ),

          // Widget Categories
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'Widget Library',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '31 production-ready widgets',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _CategoryCard(
                    icon: CupertinoIcons.square_stack_3d_up_fill,
                    title: 'Containers',
                    count: '3 widgets',
                    description: 'GlassCard, GlassPanel, GlassContainer',
                    color: Colors.purple,
                  ),
                  const SizedBox(height: 12),
                  _CategoryCard(
                    icon: CupertinoIcons.hand_point_right_fill,
                    title: 'Interactive',
                    count: '9 widgets',
                    description: 'Buttons, Switches, Sliders, Controls',
                    color: Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _CategoryCard(
                    icon: CupertinoIcons.keyboard,
                    title: 'Input',
                    count: '6 widgets',
                    description: 'TextField, SearchBar, Picker, Forms',
                    color: Colors.pink,
                  ),
                  const SizedBox(height: 12),
                  _CategoryCard(
                    icon: CupertinoIcons.square_stack_fill,
                    title: 'Overlays',
                    count: '4 widgets',
                    description: 'Dialogs, Sheets, Menus',
                    color: Colors.cyan,
                  ),
                  const SizedBox(height: 12),
                  _CategoryCard(
                    icon: CupertinoIcons.rectangle_3_offgrid_fill,
                    title: 'Surfaces',
                    count: '5 widgets',
                    description: 'AppBar, BottomBar, TabBar, Toolbar',
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero section with animated title and CTA
class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          // Animated gradient text
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.blue, Colors.purple, Colors.pink],
            ).createShader(bounds),
            child: const Text(
              'Liquid Glass',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'iOS 26 Design System',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Production-ready Flutter widgets with stunning glass effects',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: GlassButton.custom(
                  onTap: () {},
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.play_fill, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GlassIconButton(
                icon: CupertinoIcons.doc_text,
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 40),
          // Stats
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(label: 'Widgets', value: '31'),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                _StatItem(label: 'Tests', value: '211'),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                _StatItem(label: 'Quality', value: 'A+'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

/// Quick interactive feature showcase
class _QuickFeatureShowcase extends StatefulWidget {
  @override
  State<_QuickFeatureShowcase> createState() => _QuickFeatureShowcaseState();
}

class _QuickFeatureShowcaseState extends State<_QuickFeatureShowcase> {
  bool _switchValue = true;
  double _sliderValue = 0.6;
  int _selectedSegment = 0;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Try It Out',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          // Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Glass Switch',
                style: TextStyle(color: Colors.white),
              ),
              GlassSwitch(
                value: _switchValue,
                onChanged: (value) => setState(() => _switchValue = value),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Slider
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Glass Slider',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              GlassSlider(
                value: _sliderValue,
                onChanged: (value) => setState(() => _sliderValue = value),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Segmented Control
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Segmented Control',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              GlassSegmentedControl(
                segments: const ['Design', 'Code', 'Test'],
                selectedIndex: _selectedSegment,
                onSegmentSelected: (index) {
                  setState(() => _selectedSegment = index);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Property showcase (inspired by real estate demo)
class _PropertyShowcase extends StatelessWidget {
  const _PropertyShowcase({
    required this.selectedIndex,
    required this.onPropertySelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onPropertySelected;

  @override
  Widget build(BuildContext context) {
    final properties = [
      _PropertyData(
        name: 'Modern Loft',
        location: 'Downtown, SF',
        price: '\$4,200/mo',
        bedrooms: 2,
        bathrooms: 2,
        sqft: '1,200',
        image: '🏙️',
      ),
      _PropertyData(
        name: 'Beach House',
        location: 'Malibu, CA',
        price: '\$6,800/mo',
        bedrooms: 3,
        bathrooms: 3,
        sqft: '2,400',
        image: '🏖️',
      ),
      _PropertyData(
        name: 'Mountain Cabin',
        location: 'Aspen, CO',
        price: '\$3,500/mo',
        bedrooms: 2,
        bathrooms: 1,
        sqft: '900',
        image: '⛰️',
      ),
    ];

    return Column(
      children: [
        // Property cards
        SizedBox(
          height: 280,
          child: PageView.builder(
            itemCount: properties.length,
            onPageChanged: onPropertySelected,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: _PropertyCard(property: properties[index]),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Page indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            properties.length,
            (index) => Container(
              width: index == selectedIndex ? 24 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: index == selectedIndex
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PropertyData {
  final String name;
  final String location;
  final String price;
  final int bedrooms;
  final int bathrooms;
  final String sqft;
  final String image;

  _PropertyData({
    required this.name,
    required this.location,
    required this.price,
    required this.bedrooms,
    required this.bathrooms,
    required this.sqft,
    required this.image,
  });
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.property});

  final _PropertyData property;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder
          Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.withValues(alpha: 0.3),
                  Colors.purple.withValues(alpha: 0.3),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(GlassDefaults.borderRadius),
              ),
            ),
            child: Center(
              child: Text(
                property.image,
                style: const TextStyle(fontSize: 64),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            property.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.location_solid,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                property.location,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      property.price,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _PropertyFeature(
                      icon: CupertinoIcons.bed_double_fill,
                      value: '${property.bedrooms} bed',
                    ),
                    const SizedBox(width: 16),
                    _PropertyFeature(
                      icon: CupertinoIcons.drop_fill,
                      value: '${property.bathrooms} bath',
                    ),
                    const SizedBox(width: 16),
                    _PropertyFeature(
                      icon: CupertinoIcons.square_fill,
                      value: '${property.sqft} sqft',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyFeature extends StatelessWidget {
  const _PropertyFeature({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.white.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

/// Category card widget
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.icon,
    required this.title,
    required this.count,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String count;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        count,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            CupertinoIcons.chevron_right,
            color: Colors.white.withValues(alpha: 0.5),
            size: 20,
          ),
        ],
      ),
    );
  }
}
