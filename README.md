## Travel Itinerary App – Flutter & Firebase

Create, share, and manage group or solo itineraries with a visually striking hologram design. Users can display their next destination with a country flag, collaborate in groups, split expenses with receipts, and share trips via QR codes. Google Maps is scaffolded but currently disabled.

### Features

- **Sun/Moon Themes**
  - Sun: white with soft orange/yellow aura background.
  - Moon: deep night gradient with subtle starfield.

- **Modern UI**
  - Iridescent gradient backgrounds with glassmorphic cards/dialogs.
  - Material 3 dynamic theming, light/dark toggle, system theme awareness.
  - High-contrast typography using Google Fonts.

- **User Profile Personalization**
  - User can set “Next Destination” or “Recent Trip”.
  - Country flag shown beside name from country code (`country_flags` or `circle_flags`).
  - Inline lists for Current, Wishlist, and Past itineraries.

- **Itinerary & Group Functionality**
  - Timeline-based daily plans with times, media, locations, and ratings.
  - Share via QR code or link; group invites and collaboration.
  - Group participation and comments.

- **Itinerary Editor (Create/Edit/Delete)**
  - Basics: title, country, dates, cities, budget.
  - Transport: flights/trains/cars with depart/arrive times and prices.
  - Lodging: hotels/airbnbs/family with check-in/out and prices.
  - Activities: must-dos and wishlists with times and optional prices.
  - Photos: add images to any section or gallery (Storage-backed).
  - Notifications: local/email/SMS rules (stubs ready to wire).
  - Weather: toggle with units (metric/imperial). Wire your API later.

// Map is scaffolded but disabled for now.
- **Interactive Map + Emoji System (scaffolded, disabled)**
  - Emoji filters and markers page in place; UI entry point disabled.

- **Expense Splitting**
  - Attach receipts, split costs by user, automate requests, track settlements.

- **Crowdsourced Real-Time Info**
  - TSA waits and airport tips visible on relevant itineraries.

### Design Notes

- **Hologram Gradient**
  - `LinearGradient(colors: [Color(0xFF0FF4C6), Color(0xFF7C50FD), Color(0xFFFC6FF4)])`

- **Contrast & Typography**
  - Use white or neon blue over hologram background.
  - Google Fonts (e.g., Poppins). Optionally adapt with `palette_generator`.

- **Glassmorphism**
  - Cards/dialogs use semi-transparent white with blur.

- **Flags in Profile**
  - `country_flags` or `circle_flags` to render flags from a country code.

### Theme Setup (Excerpt)

```dart
final hologramGradient = LinearGradient(
  colors: [Color(0xFF0FF4C6), Color(0xFF7C50FD), Color(0xFFFC6FF4)],
);

final ThemeData appTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Color(0xFF7C50FD),
    brightness: Brightness.light,
  ),
  textTheme: GoogleFonts.poppinsTextTheme().apply(
    bodyColor: Colors.white,
    displayColor: Colors.white,
  ),
  cardColor: Colors.white.withOpacity(0.12),
  dialogBackgroundColor: Colors.white.withOpacity(0.2),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    iconTheme: IconThemeData(color: Colors.white),
  ),
  useMaterial3: true,
);
```

### Example: Flag in Profile

```dart
// Using circle_flags
// CircleFlag('US', size: 32);

// Using country_flags
// CountryFlag.fromCountryCode('us');
```

### Example: Itinerary List UI (Excerpt)

```dart
ListView.builder(
  itemCount: itineraries.length,
  itemBuilder: (context, index) {
    final trip = itineraries[index];
    return Card(
      child: ListTile(
        leading: Text(trip.flagEmoji, style: const TextStyle(fontSize: 24)),
        title: Text(trip.title),
        subtitle: Text('${trip.startDate} - ${trip.endDate}'),
        trailing: const Icon(Icons.keyboard_arrow_right),
      ),
    );
  },
);
```

### Packages

- **Theming & Fonts**: `google_fonts`, Material 3 ThemeData
- **Flags**: `country_flags`, `circle_flags`
- **Contrast/Palette**: `palette_generator`
- **Maps**: `google_maps_flutter` (files present; API disabled)
- **Emoji**: `emoji_picker_flutter`

### App Structure (Key Files)

- `_flutter/clonetrip/lib/main.dart`: App entry, theme, tabs (My Trips, Wishlist, Groups), theme toggle.
- `_flutter/clonetrip/lib/models/`: `user_profile.dart`, `itinerary.dart`, `group.dart`, `expense.dart`.
- `_flutter/clonetrip/lib/services/`: `firestore_service.dart` (streams + writes), `storage_service.dart` (receipt uploads).
- `_flutter/clonetrip/lib/pages/`: `expenses_page.dart` (balances and list), `map_page.dart` (scaffolded), `itinerary_editor_page.dart` (CRUD editor).
- `_flutter/clonetrip/lib/widgets/`: `qr_share_sheet.dart`, `add_itinerary_sheet.dart`, `add_expense_sheet.dart`.
- `_flutter/clonetrip/lib/data_service_scope.dart`: Inherited provider for `DataService`.

### Firebase Setup

1) Auth: Anonymous sign-in enabled in code.
2) Firestore: Add config files and ensure rules are deployed (see below).
3) Storage: Add config and deploy rules.
4) Optional Maps: API keys removed; UI hidden. You can re-enable later by adding keys and restoring the FAB.

Place Firebase config files:
- Android: `_flutter/clonetrip/android/app/google-services.json`
- iOS: `_flutter/clonetrip/ios/Runner/GoogleService-Info.plist`

Initialize (already in code):
- `Firebase.initializeApp()` at startup
- `FirebaseAuth.instance.signInAnonymously()`

### Firestore Collections

- `users/{userId}`: `displayName`, `countryCode`, `nextDestination`, `recentTrip`
- `itineraries/{itineraryId}`: `userId`, `title`, `countryCode`, `startDateIso?`, `endDateIso?`, `isWishlist`,
  - `cities[]`, `totalBudget?`, `photoUrls[]`
  - `transports[]` items like `{mode, from, to, departIso, arriveIso, price?}`
  - `stays[]` items like `{type, name, checkInIso, checkOutIso, price?}`
  - `activities[]` items like `{title, whenIso, mustDo, price?}`
  - `notificationRules[]` items like `{type: local|email|sms, whenIso, message}`
  - `weatherEnabled` (bool), `weatherUnits` ('metric' | 'imperial')
- `groups/{groupId}`: `name`, `memberUserIds` (array), `itineraryIds` (array)
  - `groups/{groupId}/expenses/{expenseId}`: `payerUserId`, `amount`, `currency`, `splits` (map), `description`, `createdAtIso`, `receiptUrl?`
  - `groups/{groupId}/invites/{code}`: `active`, `createdAt`

### Data Layer

- Streams:
  - `watchUserProfile(userId)`
  - `watchItineraries(userId, wishlist)`
  - `watchGroups(userId)`
  - `watchExpenses(groupId)`
- Writes:
  - `createItinerary(userId, title, countryCode, [isWishlist])`
  - `createExpense(groupId, payerUserId, amount, currency, splits, description, [receiptUrl])`
  - `createGroupInvite(groupId)` → `https://example.com/invite/{groupId}/{code}`
  - `acceptGroupInvite(groupId, code, userId)`

### Security Rules

- Firestore: See `/firestore.rules`. Rules restrict access to owners and group members.
- Storage: See `/storage.rules`. Receipts path: `groups/{groupId}/expenses/{expenseId}/receipt.jpg` requires auth.

### Run

1) `flutter pub get`
2) Add Firebase config files (Android/iOS) and ensure Firebase project is set up.
3) `flutter run` (from `_flutter/clonetrip`)

### Screenshots

Place images in `/docs/screenshots/` and update names as needed.

- Home (Hologram Theme)

  ![Home](/docs/screenshots/home.png)

- Profile Header (Flag)

  ![Profile](/docs/screenshots/profile.png)

- Trips & Wishlist

  ![Trips](/docs/screenshots/trips.png)

  ![Wishlist](/docs/screenshots/wishlist.png)

- Groups + QR Invite

  ![Groups](/docs/screenshots/groups.png)

- Expenses + Receipt

  ![Expenses](/docs/screenshots/expenses.png)

### Demo

Place a short screen recording at `/docs/demo/demo.gif`.

![Demo](/docs/demo/demo.gif)

### Notifications & Weather

- Local notifications: integrate a package like `flutter_local_notifications` and schedule using the `notificationRules` stored in each itinerary.
- Email/SMS: use a backend function or third-party API (e.g., Firebase Extensions, Twilio, SendGrid). We provide stubs via `notificationRules`; implement sending on schedule.
- Weather: call a weather API per city/date; cache results in Firestore.

### Roadmap

- Enable Maps UI and API keys, emoji markers backed by Firestore.
- Deep-links for invites and automatic join processing.
- Full receipt upload flow: create expense → upload file → update `receiptUrl` → show thumbnails.
- Date pickers and country picker in forms.
