# Quick Start Guide - 1 Hour to Launch

Follow these steps to get your showcase running with stunning visuals.

## Step 1: Get Images (30-45 minutes)

### Option A: Unsplash (Recommended)

1. Go to [unsplash.com](https://unsplash.com)
2. Search and download these 6 images:

| Search Term | Save As | What to Look For |
|------------|---------|------------------|
| "santorini villa pool" | `santorini_villa.jpg` | White architecture, blue water, sunny |
| "swiss chalet mountains" | `zermatt_chalet.jpg` | Modern wood, floor-to-ceiling windows, snow |
| "moroccan riad courtyard" | `marrakech_riad.jpg` | Colorful tiles, arches, fountain |
| "overwater bungalow" | `borabora_bungalow.jpg` | Stilts, turquoise water, tropical |
| "new york penthouse view" | `nyc_penthouse.jpg` | City skyline, modern interior, evening |
| "bali bamboo house jungle" | `bali_treehouse.jpg` | Bamboo structure, palm trees, open-air |

3. Download **"Original Size"** for each
4. Rename files as shown above
5. Move all 6 images to `showcase/assets/images/`

### Option B: Use Placeholders (5 minutes)

Skip images for now - the app has gradient fallbacks. You can test functionality, just won't look impressive for screenshots.

---

## Step 2: Install & Run (5 minutes)

```bash
# Navigate to showcase folder
cd showcase

# Get dependencies
flutter pub get

# Run on your preferred device
flutter run

# Or specify device
flutter run -d chrome          # Web
flutter run -d macos          # macOS
flutter run -d ios            # iOS Simulator
flutter run -d android        # Android Emulator
```

**Expected result**: App launches showing 6 destination cards with either your images or gradient placeholders.

---

## Step 3: Test Features (5 minutes)

### Home Page
- ✅ Scroll through destination cards
- ✅ Tap search bar (see glass keyboard)
- ✅ Tap heart icon (toggle favorite)
- ✅ Switch bottom bar tabs
- ✅ Watch animated background

### Detail Page
- ✅ Tap any destination card
- ✅ See hero transition animation
- ✅ Scroll page (watch parallax effect)
- ✅ Tap favorite icon
- ✅ Tap back button
- ✅ Tap "Contact" or "Book Now"

**Issues?** Check [Troubleshooting](#troubleshooting) below.

---

## Step 4: Record Demos (15-30 minutes)

### Setup Recording

**macOS Simulator:**
```bash
# Start recording (Cmd+R in simulator)
# Or via terminal:
xcrun simctl io booted recordVideo showcase_demo.mov
```

**Android Emulator:**
- Click "..." (More) in emulator controls
- Select "Screen record"

### What to Capture

1. **Home Feed (10 seconds)**
   - Show app launch
   - Scroll slowly through 3-4 cards
   - Highlight glass bottom bar

2. **Interaction Flow (15 seconds)**
   - Tap a stunning destination card
   - Show hero transition
   - Scroll detail page (show parallax)
   - Tap back

3. **Detail Close-up (10 seconds)**
   - Navigate to detail page
   - Show glass action buttons (back, share, favorite)
   - Scroll to show content sections
   - Show glass booking bar at bottom

### Create GIF

```bash
# Convert video to GIF using ffmpeg
ffmpeg -i showcase_demo.mov -vf "fps=30,scale=360:-1:flags=lanczos" -c:v gif showcase_demo.gif

# Or use online: https://ezgif.com/video-to-gif
```

**Recommended GIF specs:**
- Width: 360-480px (keeps file size reasonable)
- FPS: 24-30
- Duration: 10-15 seconds
- File size: Under 5MB

---

## Step 5: Screenshots (10 minutes)

Capture these specific views:

### 1. Hero Shot - Home Feed
- Show 2-3 complete destination cards
- Include top bar with "Wanderlust" branding
- Include bottom glass navigation bar
- **Purpose**: Main README hero image

### 2. Detail Page Full View
- Navigate to best-looking destination
- Capture from top (hero image) to booking bar
- **Purpose**: Show detail page functionality

### 3. Glass Widget Focus
- Close-up of bottom bar during tab switch
- Or search bar with glass effect visible
- **Purpose**: Highlight specific glass widgets

### 4. Transition Moment
- Capture mid-transition (home → detail)
- Shows hero animation in action
- **Purpose**: Demonstrate smooth animations

**How to capture:**
- iOS Simulator: Cmd+S (saves to Desktop)
- Android: Screenshot button in emulator controls
- Or use built-in screen capture tools

---

## Step 6: Update Main README (10 minutes)

Add this to your main package README:

```markdown
# Liquid Glass Widgets

![Wanderlust Showcase](showcase/assets/wanderlust_hero.gif)

Beautiful, adaptive glass morphism widgets for Flutter.

## ✨ See It In Action

Check out [Wanderlust](./showcase), our luxury travel showcase app that demonstrates how glass morphism can enhance stunning imagery without hiding it.

[More demo screenshots...]

## Features

- 🎨 **Premium Glass Effects** - Blur, lighting, and adaptive coloring
- 🎯 **Production Ready** - Battle-tested in real applications
- 📱 **Fully Responsive** - Adapts to any screen size
- ⚡ **High Performance** - Optimized rendering and caching

[Rest of your README...]
```

---

## Troubleshooting

### Images Not Showing

**Problem**: Gradient placeholders instead of images

**Solutions**:
1. Check file names exactly match:
   - `santorini_villa.jpg` (not `Santorini-Villa.jpg`)
2. Verify images are in `showcase/assets/images/`
3. Run `flutter pub get` again
4. Hot restart (not just hot reload)

### Build Errors

**Problem**: Package not found or import errors

**Solutions**:
```bash
# Clean build
flutter clean
flutter pub get

# Check you're in showcase folder
cd showcase

# Rebuild
flutter run
```

### Package Import Errors

**Problem**: `liquid_glass_widgets` not found

**Solutions**:
1. Check `pubspec.yaml` has correct path:
   ```yaml
   liquid_glass_widgets:
     path: ../
   ```
2. Ensure you're running from `showcase` folder, not root
3. Run `flutter pub get` in showcase folder

### Performance Issues

**Problem**: Laggy animations or slow scrolling

**Solutions**:
1. Use release mode: `flutter run --release`
2. Test on real device, not just simulator
3. Check image file sizes (should be under 2MB each)
4. Optimize images using TinyPNG or similar

### Glass Effects Not Visible

**Problem**: Widgets look flat, no glass effect

**Solutions**:
1. Ensure you have imagery (not gradient fallbacks)
2. Try different destinations (some may have better contrast)
3. Check device supports backdrop filters
4. Test on physical device

---

## Quick Reference

### File Locations

```
showcase/
├── lib/
│   ├── main.dart              ← App entry
│   ├── pages/
│   │   ├── home_page.dart     ← Main feed
│   │   └── detail_page.dart   ← Destination detail
│   └── data/
│       └── destinations_data.dart  ← Edit to add destinations
└── assets/
    └── images/                ← PUT IMAGES HERE
```

### Commands

```bash
# Get dependencies
flutter pub get

# Run app
flutter run

# Run in release mode (better performance)
flutter run --release

# Clean build
flutter clean && flutter pub get

# Analyze code
flutter analyze
```

### Image Requirements

- **Format**: JPG or PNG
- **Size**: 1440x1920px (portrait)
- **File size**: Under 2MB
- **Orientation**: Portrait (vertical)

---

## Next Steps After Launch

1. **Share on social media** with your GIF/screenshots
2. **Update Medium article** with new showcase visuals
3. **Add to package pub.dev** description
4. **Consider blog post** about building the showcase
5. **Collect feedback** and iterate

---

## Need Help?

- **Images**: See `IMAGE_GUIDE.md` for detailed sourcing help
- **Architecture**: See `SHOWCASE_SUMMARY.md` for technical details
- **Documentation**: See `README.md` for full feature list

---

## Success Checklist

Before considering this "done":

- [ ] 6 high-quality images added
- [ ] App runs without errors
- [ ] All interactions tested
- [ ] At least 1 GIF recorded
- [ ] 3-4 screenshots captured
- [ ] Main README updated with showcase link
- [ ] Showcase runs in release mode smoothly

---

**Estimated total time**: 1 hour (with images) or 15 minutes (without images for testing)

**Ready to wow people?** Go get those images! 🚀
