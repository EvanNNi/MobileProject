# Luma

Luma is a Flutter + Firebase second-hand marketplace app. It helps users photograph unused items, generate AI-assisted listing information, estimate resale prices, publish listings, browse nearby items on a map, save favourites, and chat with sellers.

## Main Features

- Buyer/seller account system with Firebase Authentication.
- AI item recognition, listing copy generation, and price estimation through Firebase Functions.
- Multi-image item publishing with camera and album upload.
- Firestore-backed marketplace, search, filters, favourites, views, likes, and listing management.
- Mapbox-powered location selection and nearby item map browsing.
- Firestore-backed chat conversations and image messages.
- Chinese/English UI switching.

## Required Local Configuration

Do not commit API tokens or private `.env` files to GitHub. The repository intentionally excludes local secrets with `.gitignore`.

### Mapbox Token

The app reads the Mapbox token from Flutter dart defines:

```bash
flutter run --dart-define=MAPBOX_ACCESS_TOKEN=your_mapbox_public_token
```

For a release build:

```bash
flutter build ios --release --dart-define=MAPBOX_ACCESS_TOKEN=your_mapbox_public_token
```

For installing an already built release app to a USB-connected iPhone:

```bash
flutter install --release -d <device_id>
```

Important: do not hardcode the Mapbox token in `lib/services/mapbox_config.dart` or `ios/Runner/Info.plist`. GitHub push protection may block pushes that contain Mapbox tokens.

### Firebase

The iOS Firebase app configuration is stored at:

```text
ios/Runner/GoogleService-Info.plist
```

The app currently uses Firebase Authentication, Firestore, Storage, and Cloud Functions. Firestore and Storage security rules are kept in:

```text
firestore.rules
storage.rules
```

### OpenAI Secret For Firebase Functions

The OpenAI API key must be stored as a Firebase Functions secret, not in source code:

```bash
firebase functions:secrets:set OPENAI_API_KEY --project mobileprojectserver
```

Optional model setting:

```env
OPENAI_LISTING_MODEL=gpt-5-mini
```

For local Firebase Functions configuration, place it in `functions/.env` or `functions/.env.mobileprojectserver`. These files are ignored by Git.

See `functions/README.md` and `docs/backend_requirements.md` for backend details.

## Development Commands

Install Flutter dependencies:

```bash
flutter pub get
```

Run static analysis:

```bash
flutter analyze
```

Run on a connected iPhone with Mapbox enabled:

```bash
flutter run -d <device_id> --dart-define=MAPBOX_ACCESS_TOKEN=your_mapbox_public_token
```

Build iOS release:

```bash
flutter build ios --release --dart-define=MAPBOX_ACCESS_TOKEN=your_mapbox_public_token
```

Deploy Firebase Functions:

```bash
cd functions
npm install
npm run build
firebase deploy --only functions --project mobileprojectserver
```

## Git Notes

The repository excludes generated and local-only files, including:

- `build/`
- `.dart_tool/`
- `ios/Pods/`
- `functions/node_modules/`
- `functions/lib/`
- `functions/.env*`
- local UI reference screenshots in `VINT UI/`

If GitHub blocks a push because a token was committed, remove the token from source files, amend or rewrite the commit, and push again.
