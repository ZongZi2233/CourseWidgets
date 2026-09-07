# Image Sourcing Guide for Wanderlust Showcase

This guide will help you source stunning, high-quality images for the showcase app.

## Quick Start

### Unsplash (Recommended - Free & High Quality)

Visit [Unsplash.com](https://unsplash.com) and search for these specific images:

#### 1. Santorini Villa (`santorini_villa.jpg`)
**Search terms**: "santorini villa", "santorini pool", "greek island luxury"

**Look for**:
- White architecture with blue accents
- Infinity pool overlooking ocean
- Bright, sunny, Mediterranean vibes
- Caldera views

**Example photographers**: @dnevozhai, @chriskaridis, @dronepicr

---

#### 2. Zermatt Chalet (`zermatt_chalet.jpg`)
**Search terms**: "swiss chalet", "zermatt", "mountain luxury home", "alpine architecture"

**Look for**:
- Modern wooden chalet with floor-to-ceiling windows
- Mountain (ideally Matterhorn) in background
- Snow or dramatic alpine scenery
- Contemporary architecture

**Example photographers**: @anniespratt, @pascal_meier, @baileyandsons

---

#### 3. Marrakech Riad (`marrakech_riad.jpg`)
**Search terms**: "moroccan riad", "marrakech courtyard", "moroccan architecture"

**Look for**:
- Intricate tilework and archways
- Courtyard with fountain or pool
- Rich colors (blues, oranges, golds)
- Traditional Moroccan design

**Example photographers**: @marrakech, @elcarito, @benbotha

---

#### 4. Bora Bora Bungalow (`borabora_bungalow.jpg`)
**Search terms**: "overwater bungalow", "bora bora", "maldives resort", "tropical luxury"

**Look for**:
- Overwater bungalows on stilts
- Turquoise lagoon water
- Mountain in background (for Bora Bora)
- Tropical paradise aesthetic

**Example photographers**: @jeremybishop, @asoshiation, @timothyk

---

#### 5. NYC Penthouse (`nyc_penthouse.jpg`)
**Search terms**: "new york penthouse", "manhattan skyline", "luxury apartment view", "city view interior"

**Look for**:
- Floor-to-ceiling windows with city views
- Modern minimalist interior
- Evening/blue hour cityscape
- Sophisticated urban aesthetic

**Example photographers**: @chrisluigi, @scottwebb, @paulgalbraith

---

#### 6. Bali Treehouse (`bali_treehouse.jpg`)
**Search terms**: "bali bamboo house", "jungle villa", "treehouse resort", "tropical architecture"

**Look for**:
- Bamboo or wooden structure
- Surrounded by lush jungle/palm trees
- Open-air design
- Balinese aesthetic

**Example photographers**: @balitreehouse, @marianne_hops, @ikelouie

---

## Download Instructions

1. **Find the perfect image** on Unsplash
2. **Click the image** to open full view
3. **Click the download arrow** (top right)
4. **Select "Original Size"** for best quality
5. **Rename the file** according to the list above
6. **Move to** `showcase/assets/images/`

## Image Specifications

### Technical Requirements
- **Format**: JPG or PNG
- **Min Resolution**: 1080 x 1440 pixels (3:4 ratio)
- **Ideal Resolution**: 1440 x 1920 pixels or higher
- **File Size**: Under 2MB per image (compress if needed)
- **Orientation**: Portrait (vertical)

### Visual Requirements
- **High contrast**: Dark/bright areas for glass overlays
- **Sharp focus**: Professional-quality photography
- **Good composition**: Main subject clearly visible
- **Vibrant colors**: Makes glass effects pop
- **No heavy filters**: Natural, authentic look

## Alternative Sources

### Pexels (Free)
- [pexels.com](https://www.pexels.com)
- Similar license to Unsplash
- Use same search terms

### Pixabay (Free)
- [pixabay.com](https://www.pixabay.com)
- Large selection
- Good for architecture and nature

### Burst by Shopify (Free)
- [burst.shopify.com](https://burst.shopify.com)
- Business-focused stock photos
- Good for modern interiors

## Using Your Own Photos

If you have access to your own travel or property photography:

1. **Export at high resolution** (minimum 1440px height)
2. **Use portrait orientation** (crop if needed)
3. **Enhance if needed**: Adjust brightness, contrast, saturation
4. **Avoid over-processing**: Keep natural look
5. **Test glass overlay**: Make sure text remains readable

## Placeholder Strategy

If you're not ready for final images, use:

1. **Solid gradients** (already handled in code as fallback)
2. **Low-res images** temporarily (replace before recording demos)
3. **Figma mockups** with proper dimensions

## Image Optimization

Before adding images to the project:

```bash
# Install ImageMagick (if not installed)
brew install imagemagick  # macOS
sudo apt-get install imagemagick  # Linux

# Optimize all images at once
cd showcase/assets/images/
magick mogrify -resize 1440x1920^ -quality 85 *.jpg
```

Or use online tools:
- [TinyPNG](https://tinypng.com) - Great compression
- [Squoosh](https://squoosh.app) - Google's image optimizer

## Copyright & Attribution

### Unsplash License
- ✅ Free to use for commercial projects
- ✅ No attribution required (but appreciated)
- ✅ Can modify images
- ❌ Can't sell unmodified photos
- ❌ Can't create competing image service

### Best Practices
1. **Keep a credits list** in case you want to attribute later
2. **Download license info** when downloading
3. **Never claim photos as your own**
4. **Consider photographer credit** in app settings or about page

## Testing Images

After adding images, test that:

1. ✅ App launches without errors
2. ✅ All 6 destination cards show images
3. ✅ Hero transitions work smoothly
4. ✅ Text overlays are readable on images
5. ✅ Glass effects are visible and attractive
6. ✅ App performs well (no lag from large files)

## Quick Quality Checklist

Good images for this showcase:
- ✅ Bright, well-lit scenes
- ✅ Clear subject matter
- ✅ Professional composition
- ✅ High resolution (sharp, not pixelated)
- ✅ Vibrant colors
- ✅ Portrait orientation
- ✅ Room for text overlay at bottom

Avoid:
- ❌ Low resolution / blurry
- ❌ Dark, muddy images
- ❌ Heavy filters or over-processed
- ❌ Landscape orientation
- ❌ Cluttered composition
- ❌ Watermarks

## Need Help?

If you're having trouble finding the right images:

1. Search using the exact phrases above on Unsplash
2. Filter by "orientation: portrait"
3. Look at similar image suggestions
4. Check the "Collections" feature for curated sets
5. Follow the example photographers mentioned

## Final Note

**The images make or break this showcase.** Spend 30-60 minutes finding the absolute best photos. The glass effects are designed to enhance beautiful imagery—mediocre photos will make even the best glass effects look bad.

Think of it this way: You're creating a luxury travel magazine. Every image should make someone say "wow, I want to go there."
