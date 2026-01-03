# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter grocery price tracking app. Scans receipts using on-device OCR, parses them with Claude API, and tracks price history over time.

## Common Commands

```bash
# Get dependencies
flutter pub get

# Run code generation (required after modifying Drift tables or Riverpod providers)
dart run build_runner build --delete-conflicting-outputs

# Build for iOS
flutter build ios

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Clean build artifacts
flutter clean
```

## Architecture

**State Management**: Riverpod with code generation (`riverpod_annotation`). Providers are in `lib/providers/`.

**Database**: Drift (SQLite). Tables defined in `lib/core/database/tables.dart`, database operations in `lib/core/database/database.dart`. After modifying tables, run `build_runner` to regenerate `database.g.dart`.

**Feature Structure**: `lib/features/` contains screen-based modules:
- `home/` - Dashboard showing recent purchases
- `products/` - Product list view
- `product_detail/` - Price history charts and statistics
- `add_purchase/` - Manual purchase entry form
- `scan_receipt/` - Camera capture and receipt review flow
- `settings/` - API key configuration and exchange rate

**Services** (`lib/core/services/`):
- `ocr_service.dart` - Google ML Kit text recognition (on-device, requires physical iOS device)
- `receipt_parser_service.dart` - Claude API integration for parsing OCR text into structured items
- `unit_converter.dart` / `currency_converter.dart` - Unit and currency conversion utilities

**Data Flow for Receipt Scanning**:
1. User captures image -> `image_picker`
2. Image processed -> `OcrService` (ML Kit)
3. OCR text + existing products sent to Claude API -> `ReceiptParserService`
4. User reviews parsed items -> `ReviewItemsScreen`
5. Confirmed items saved -> `AppDatabase`

## Key Implementation Details

- Primary currency is MXN with USD conversion via configurable exchange rate
- Claude API key stored in `flutter_secure_storage`, configured in Settings screen
- OCR requires physical iOS device (doesn't work on arm64 simulator)
- Database schema is at version 2; migrations handle adding variant/brand columns
