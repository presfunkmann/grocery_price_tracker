# Grocery Price Tracker

A Flutter app to track grocery prices over time, helping you identify deals and compare prices across stores.

## Features

### Receipt Scanning
- Scan receipts using your camera or photo gallery
- AI-powered parsing using Claude API to extract items, quantities, and prices
- Supports both Mexican (MXN) and US (USD) receipts
- Review and edit parsed items before saving
- Swipe-to-dismiss receipt image viewer during import

### Price Tracking
- Track price history for all your grocery items
- View price trends with interactive charts
- See min, max, and average prices at a glance
- Visual indicators show if current price is a deal or expensive

### Product Management
- Organize products with variants (Organic, Regular, Free-range, etc.)
- Track brands for each purchase
- Filter price history by variant or brand
- Compare variants side-by-side with comparison charts
- Edit product names anytime
- Swipe to delete products (with confirmation)

### Multi-Currency & Unit Support
- Primary currency: MXN (Mexican Peso)
- Secondary currency: USD with easy toggle
- Weight units: kg and lb with automatic conversion
- Volume units: L and gal
- Configurable exchange rate

### Store Tracking
- Track which store each purchase was made at
- Auto-complete for existing stores
- Edit store name during receipt import

## Tech Stack

- **Framework**: Flutter (iOS first, Android-ready)
- **State Management**: Riverpod
- **Database**: SQLite via Drift
- **OCR**: Google ML Kit Text Recognition
- **AI Parsing**: Claude API (Haiku model)
- **Charts**: fl_chart
- **Secure Storage**: flutter_secure_storage

## Setup

1. Clone the repository
2. Run `flutter pub get`
3. Add your Claude API key in Settings (get one at [console.anthropic.com](https://console.anthropic.com))
4. Run on a physical iOS device (OCR requires device, not simulator)

## Usage

### Adding Purchases Manually
1. Tap "Add Purchase" on the home screen
2. Enter product name (or select existing)
3. Fill in price, quantity, unit, and store
4. Optionally add variant and brand
5. Save

### Scanning Receipts
1. Tap the scan icon on the home screen
2. Take a photo or select from gallery
3. Wait for OCR and AI parsing
4. Review parsed items - edit any mistakes
5. Tap receipt icon to view original image
6. Save selected items

### Viewing Price History
1. Tap any product on the home screen
2. View price chart and statistics
3. Filter by variant or brand
4. Toggle "Compare Variants" to see side-by-side
5. Swipe left on any purchase to delete it

## Cost

- OCR: Free (on-device)
- AI Parsing: ~$0.01-0.03 per receipt (Claude Haiku)
