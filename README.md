# Thavvu Supervisor App

Thavvu Supervisor is a Flutter construction/site operations app. It is built as a multi-module supervisor/HOD dashboard covering daily machine logs, attendance, rental, cash, stock, food, tasks, reports, maps, and transfer workflows.

This README is intended to be the project map for future upgrades. When asking for a change later, send the affected file plus the relevant notes from this README so the upgrade can be made without re-discovering the whole project.

## Project Structure

```text
thavvu_app/
├── README.md
├── pubspec.yaml
├── pubspec.lock
├── analysis_options.yaml
├── devtools_options.yaml
├── test/
│   └── widget_test.dart
├── assets/
│   └── images/
│       └── logo.png
├── lib/
│   ├── main.dart
│   ├── models/
│   │   └── machine_worker_group.dart
│   ├── screens/
│   │   ├── attendance_screen.dart
│   │   ├── attendance_screen_backup_1780046188.dart.bak
│   │   ├── cash_screen.dart
│   │   ├── daily_data_screen.dart
│   │   ├── food_screen.dart
│   │   ├── hod_tasks_screen.dart
│   │   ├── internal_transfer_screen.dart
│   │   ├── login_screen.dart
│   │   ├── machines_entry_screen_.dart
│   │   ├── main_shell.dart
│   │   ├── maps_screen.dart
│   │   ├── other_screens.dart
│   │   ├── overview_screen.dart
│   │   ├── rental_screen.dart
│   │   ├── reports_screen.dart
│   │   ├── splash_screen.dart
│   │   ├── stock_inventory_screen.dart
│   │   ├── tasks_screen.dart
│   │   └── transfers_screen.dart
│   ├── services/
│   │   └── auth_service.dart
│   ├── theme/
│   │   └── app_theme.dart
│   └── widgets/
│       ├── advance_payment_request.dart
│       ├── diesel_consumption_table.dart
│       ├── payment_mode_selector.dart
│       ├── photo_capture_card.dart
│       └── shared_widgets.dart
├── android/
├── ios/
├── macos/
├── linux/
├── windows/
└── fix_*.sh / final_fix.sh
```

The platform folders (`android/`, `ios/`, `macos/`, `linux/`, `windows/`) are Flutter-generated host projects. Most business logic is inside `lib/`.

## App Entry Flow

`lib/main.dart` starts the app, locks orientation to portrait, defines the global `MaterialApp` theme, and opens `SplashScreen`.

Current navigation flow:

```text
main.dart
└── SplashScreen
    └── LoginScreen / MainShell
        ├── OverviewScreen
        ├── DailyDataScreen
        ├── AttendanceScreen
        ├── RentalScreen
        ├── CashModuleScreen
        ├── StockInventoryScreen
        ├── FoodScreen
        ├── MachinesEntryScreen
        ├── MapsScreen
        ├── TasksScreen
        └── ReportsScreen
```

`main_shell.dart` is the main routing/dashboard shell. If a module is renamed, update the references in this file.

## Dependencies

From `pubspec.yaml`:

```yaml
shared_preferences
cupertino_icons
go_router
google_fonts
intl
flutter_svg
fl_chart
google_maps_flutter
flutter_lints
```

The app is mostly local-state/demo-data driven at present. There is no backend API layer yet.

## Important Theme Rule

Use `lib/theme/app_theme.dart` for shared colors, card styles, shadows, and status colors. Several screens also still contain local styling. For future UI upgrades, prefer moving toward shared `AppTheme` constants instead of introducing new one-off colors.

Known app bar/top tab color target: match the `daily_data_screen.dart` top navigation style where possible.

## Dart Files And Responsibilities

### Core

`lib/main.dart`
- App bootstrap.
- Global app theme.
- Portrait orientation lock.
- Opens `SplashScreen`.

`lib/theme/app_theme.dart`
- Central design tokens.
- Colors like `primary`, `success`, `warning`, `danger`, `surface`, `surfaceCard`, borders, shadows, and status backgrounds.
- Use this file first for UI colors.

`lib/services/auth_service.dart`
- Local authentication helper.
- Uses `shared_preferences`.
- Stores simple login/user state.

`lib/models/machine_worker_group.dart`
- Simple model for mapping machine worker groups.

### Screens

`lib/screens/splash_screen.dart`
- Startup/loading screen.
- Decides where the user should land after launch.

`lib/screens/login_screen.dart`
- Login UI and authentication entry.
- Works with `AuthService`.

`lib/screens/main_shell.dart`
- Primary dashboard shell.
- Contains drawer/module navigation.
- Routes module taps to screens.
- Important: Cash module widget is `CashModuleScreen`, not `CashScreen`.

`lib/screens/overview_screen.dart`
- Dashboard overview cards and module shortcuts.
- Uses `_ModuleCard`.
- Good place for changing first-screen module visibility.

`lib/screens/daily_data_screen.dart`
- Daily machine/activity logs.
- Models include `MachineSummary`, `PaymentTransaction`, `MachineLogRecord`, and `DieselLogEntry`.
- Contains the reference payment UI pattern:
  - Cash Payment toggle.
  - Advance Request toggle.
  - Cash Payment Table.
  - Advance Payment Request Table.
  - Payment proof preview.
  - Machine IDs Book toggle.
- Use this file as the source style for payment sections in other modules.

`lib/screens/attendance_screen.dart`
- Attendance for regular and outside workers.
- Handles worker profiles, batch shifts, attendance actions, salary/payment ledgers, supplier bills, and payment tabs.
- Important classes: `Worker`, `OutsideWorker`, `WorkerBatch`, `AttendanceWorkerProfile`, `WorkerPaymentLedgerEntry`, `SupplierBillPaymentRequest`.
- Attendance capture/tap logic lives here, so face/biometric duplicate-capture fixes belong in this file.

`lib/screens/cash_screen.dart`
- Cash module screen widget: `CashModuleScreen`.
- Handles:
  - Cash Pay.
  - Request Pay.
  - Contra requests.
  - History.
  - Transport split billing.
- Important classes:
  - `CashTransaction`
  - `CashExpenseItem`
  - `FinanceRequest`
  - `ContraRequest`
  - `TransportSplitBill`
- Current important behavior:
  - Asset cash pay supports multiple items with quantity and amount.
  - Cash/asset/transport/request flows support invoice/bill upload fields.
  - Transport supports vehicle photo plus invoice/bill.
  - Request Pay uses Daily Data-style UPI/Bank request selection.

`lib/screens/rental_screen.dart`
- Rental module.
- Covers machine rentals, rental line items, payment transactions, fuel logs, transfer-related rental assets, vehicle rentals, aqua tools, and detailed machine lifecycle pages.
- Important classes:
  - `RentalLineItem`
  - `RentalPaymentTransaction`
  - `RentalItem`
  - `MachineFuelLog`
  - `VehicleRentalEntry`
  - `MachineRentalDetailPage`
- Current important behavior:
  - Rental payment section follows Daily Data-style cash/advance ledger tables.
  - Rental supports multiple items and fuel-related lifecycle records.

`lib/screens/machines_entry_screen_.dart`
- Machine entry and diesel entry module.
- Used for HOD machine registration and supervisor diesel entries.
- Important classes:
  - `MachineCatalogItem`
  - `DieselEntry`
  - `VehicleDayRecord`
  - `MachinePaymentTransaction`
- Current important behavior:
  - Machine payment area uses Daily Data-style cash/advance switches and tables.
  - Uses `AdvancePaymentRequest`, `DieselConsumptionTable`, and `PhotoCaptureCard`.

`lib/screens/stock_inventory_screen.dart`
- Large stock/inventory module.
- Includes stock points, stock movements, GIN bills, uploaded documents, submissions, aqua stock, consumables, returns, and embedded internal transfer workflows.
- Important classes:
  - `StockPoint`
  - `StockMovement`
  - `GINBill`
  - `AquaStockItem`
  - `OtherConsumableRecord`
  - `TransferRecord`
  - `InternalTransferTab`
- Note: this file also defines a local `AppTheme` class near the top. Be careful because it can conflict conceptually with `lib/theme/app_theme.dart`.

`lib/screens/internal_transfer_screen.dart`
- Separate internal transfer module.
- Handles new transfer, delivering, and receiving tabs.
- Important classes:
  - `TransferRecord`
  - `NewTransferTab`
  - `DeliveringTab`
  - `ReceivingTab`
- If internal transfer is removed from navigation, check both this file and any embedded transfer UI in `stock_inventory_screen.dart`.

`lib/screens/food_screen.dart`
- Food module.
- Tracks regular worker food and outside worker food.
- Important classes:
  - `WorkerFood`
  - `OutsideWorkerFood`

`lib/screens/tasks_screen.dart`
- General tasks screen.

`lib/screens/hod_tasks_screen.dart`
- HOD-specific task screen.

`lib/screens/reports_screen.dart`
- Reports screen.
- Good place for summaries/exports in the future.

`lib/screens/maps_screen.dart`
- Maps/specs module.
- Includes `_MapGridPainter`.
- Uses visual/custom map UI and may later integrate `google_maps_flutter`.

`lib/screens/other_screens.dart`
- Miscellaneous operational expenses.
- Covers bike petrol and snacks/extras.
- Important classes:
  - `PetrolEntry`
  - `SnackEntry`
  - `OthersScreen`

`lib/screens/transfers_screen.dart`
- Simple transfers screen.
- Separate from the more detailed internal transfer modules.

`lib/screens/attendance_screen_backup_1780046188.dart.bak`
- Backup copy of attendance screen.
- Do not edit unless intentionally restoring old logic.

### Widgets

`lib/widgets/shared_widgets.dart`
- Reusable UI widgets:
  - `ModuleHeader`
  - `SectionHeader`
  - `AppFormField`
  - `SubmitButton`
  - `HodApprovalBadge`
  - `NoteBox`
  - `StepCard`
  - `StatsCard`
  - `InfoCard`
  - `FilterChipWidget`
  - `StatusBadge`
  - `LoadingOverlay`

`lib/widgets/advance_payment_request.dart`
- Reusable advance payment request card.
- Supports UPI/Bank mode and Manual/Photo/Voice entry method.
- Used by machine/payment request flows.

`lib/widgets/diesel_consumption_table.dart`
- Reusable diesel table entry widget.
- Used by machine entry flows.

`lib/widgets/payment_mode_selector.dart`
- Reusable payment mode selector.
- Defines `PaymentMode { cash, upi, bank }`.

`lib/widgets/photo_capture_card.dart`
- Simple photo capture placeholder/card.
- Used where a mandatory photo capture is required.

## Key Module Upgrade Notes

### Payment UI Style

Daily Data is the reference for payment UI. If another module needs payment UI consistency, copy the behavior and visual hierarchy from `daily_data_screen.dart`:

- `Cash Payment` switch.
- Available balance/info box.
- Amount input.
- Validation info.
- `Cash Payment Table`.
- `Advance Request` switch.
- UPI/Bank request mode.
- Account/details entry.
- `Advance Payment Request Table`.
- Request status, proof preview, and Machine IDs Book toggle.

Current modules already using this pattern:

- `daily_data_screen.dart`
- `attendance_screen.dart`
- `rental_screen.dart`
- `machines_entry_screen_.dart`
- `cash_screen.dart` request mode area

### Cash Module Upgrade Points

Use `lib/screens/cash_screen.dart`.

Common changes and where they belong:

- Cash Pay categories: `_buildCategorySelector`, `_buildFoodOthersForm`, `_buildAssetsForm`.
- Asset multiple items: `CashExpenseItem`, `_cashPayItems`, `_addCashPayItem`, `_submitCashPay`.
- Request Pay: `_buildRequestAmountSection`, `_buildRequestOptionFields`, `_submitRequestPay`.
- Bank/UPI saved accounts: `_showAddUpiAccountSheet`, `_showAddBankAccountSheet`.
- Contra: `_sendContraRequest`, `_buildContraTab`.
- Transport split billing: `_buildTransportForm`, `_submitTransportSplit`, `_buildTransportSplitHistory`.
- Upload buttons: `_buildCashUploadButton`.

### Rental Module Upgrade Points

Use `lib/screens/rental_screen.dart`.

Common changes and where they belong:

- Main rental form: `_RentalScreenState`.
- Rental items and multiple item entry: `RentalLineItem`, `RentalItem`, related item form methods.
- Payment ledger: `RentalPaymentTransaction`, `_rentalPaymentLedger`, `_buildAdvancePayment`, `_buildRentalCashPaymentTable`, `_buildRentalAdvanceRequestTable`.
- Fuel ledger and lifecycle: `MachineFuelLog`, `MachineRentalDetailPage`.
- Machine detail page behavior: `_MachineRentalDetailPageState`.

### Attendance Upgrade Points

Use `lib/screens/attendance_screen.dart`.

Common changes and where they belong:

- Regular workers: `RegularWorkersTab`.
- Outside workers: `OutsideWorkersTab`.
- Payment/salary ledgers: `PaymentsTab`.
- Supplier bill payment: `SupplierBillsPaymentTab`.
- Capture/biometric/face duplicate tap issues: attendance action methods and button handlers in this file.

### Machine Entry Upgrade Points

Use `lib/screens/machines_entry_screen_.dart`.

Common changes and where they belong:

- HOD form submit: `_submitHODForm`.
- Supervisor diesel submit: `_submitSupervisorForm`.
- Payment area: `_buildFairAmount`, `_buildAdvancePayments`, `MachinePaymentTransaction`.
- Diesel draft entries: `_saveDieselDraftEntry`, `_buildDieselConsumptionTable`.

### Navigation Upgrade Points

Use `lib/screens/main_shell.dart`.

Common changes and where they belong:

- Drawer modules: drawer module tile list.
- Route switch: `_handleModuleRoute`.
- Bottom navigation: `_handleBottomNavTap`.
- Module removal from shell: remove route, drawer tile, and any overview shortcut.

Use `lib/screens/overview_screen.dart` for overview first-screen cards.

## Running The Project

Install packages:

```bash
flutter pub get
```

Run on Chrome:

```bash
flutter run -d chrome
```

Run on connected device/emulator:

```bash
flutter run
```

Format changed Dart files:

```bash
dart format lib/screens/cash_screen.dart
```

Analyze changed files:

```bash
flutter analyze lib/screens/cash_screen.dart
```

Run tests:

```bash
flutter test
```

Current test coverage is only a placeholder smoke test in `test/widget_test.dart`.

## Known Analyzer Situation

The project currently has many non-blocking analyzer warnings, mostly:

- `deprecated_member_use` for Flutter APIs such as `withOpacity`, `value`, `groupValue`, and `onChanged`.
- `prefer_const_constructors`.
- Some unused private helpers.

When making upgrades, focus first on real compile errors (`Error:` / analyzer `error`) and behavior bugs. Cleanup lints separately to avoid mixing refactors with feature work.

## How To Request Future Upgrades

For fastest future changes, send:

1. The exact file to change.
2. The module name.
3. The current bug or required behavior.
4. Any reference file or snippet to copy style from.
5. Whether to preserve existing UI or redesign it.

Good examples:

```text
In lib/screens/cash_screen.dart, update Request Pay bank mode.
Use Daily Data payment table style. Do not change Contra.
```

```text
In lib/screens/attendance_screen.dart, fix face recognition double capture.
One tap must create only one attendance record.
```

```text
In lib/screens/rental_screen.dart, add bill upload to rental payment only.
Keep existing fuel ledger unchanged.
```

## Safe Editing Rules For This Project

- Prefer editing the one module file requested.
- Do not rename screen widgets without updating `main_shell.dart`.
- Keep `CashModuleScreen` as the cash screen widget unless deliberately renaming it.
- Use `AppTheme` colors where available.
- After edits, run `dart format` on changed files.
- Run focused `flutter analyze` on changed files.
- Do not remove backup files or generated platform files unless specifically requested.
- Avoid broad cleanup while making feature changes.

## Important Current Widget Names

Use these names when wiring routes:

```dart
OverviewScreen
DailyDataScreen
AttendanceScreen
RentalScreen
CashModuleScreen
StockInventoryScreen
FoodScreen
MachinesEntryScreen
MapsScreen
TasksScreen
ReportsScreen
```

## Assets

Current app asset:

```text
assets/images/logo.png
```

`pubspec.yaml` includes:

```yaml
assets:
  - assets/
  - assets/images/
```

## Release & Publishing

**App identity** — the reverse-domain ID is `com.thavvu.app`:

- Android: `applicationId` / `namespace` in `android/app/build.gradle.kts` and
  `MainActivity` at `android/app/src/main/kotlin/com/thavvu/app/MainActivity.kt`.
- iOS: `PRODUCT_BUNDLE_IDENTIFIER = com.thavvu.app` in
  `ios/Runner.xcodeproj/project.pbxproj`; display name `Thavvu` in `Info.plist`.

**Android release signing** — `android/app/build.gradle.kts` signs `release`
builds with the upload keystore when `android/key.properties` exists, otherwise
falls back to the debug key (so fresh clones and CI PRs still build).

```text
android/key.properties            # gitignored — REQUIRED for store builds
android/app/upload-keystore.jks   # gitignored — the upload certificate
```

A backup of the keystore and its credentials lives outside the repo at
`~/thavvu-keystore-backup/README.txt`. Keep that safe — it is the only way to
publish future updates under `com.thavvu.app`. Never commit the keystore or
`key.properties`.

**Builds**

```bash
flutter build appbundle --release   # Google Play upload  (build/app/outputs/bundle/release/app-release.aab)
flutter build apk --release --split-per-abi  # sideloadable per-ABI APKs
flutter build web --release         # PWA/web  (deployed via Vercel)
```

**CI** — `.github/workflows/ci.yml` runs on push to `main` / `release/**` and on
PRs: `flutter analyze` (errors fatal only) + `flutter test`, then builds of the
AppBundle, split APKs and web. For CI to produce a *signed* AppBundle, set repo
secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
`ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS` (see the workflow). Without them CI
still builds but signs with the debug fallback.

**Store identity reminders** — the current launcher art is a generated Thavvu
`T` monogram in AppTheme blue. The bundled `assets/images/logo.png` asset still
carries ORYXEN wordmark artwork used in-app; decide on final brand art before
submitting to the App Store (icon + screenshots are required for both stores).

## Supervisor Account Provisioning (HOD → real login)

The HOD "Create Supervisor Login" flow provisions a **real, email-confirmed
Supabase Auth account** via the `admin_create_supervisor` SECURITY DEFINER RPC
(migration `00034_admin_create_supervisor.sql`). The generated credentials
therefore work on the actual login screen:

- The RPC creates the `auth.users` row (bcrypt password, `email_confirmed_at`
  set), the `auth.identities` email row, and the `profiles` row (via the
  existing `on_auth_user_created` trigger).
- If the HOD picks a **Site** and **Thavvu Point** in the create sheet, the
  supervisor is immediately assigned (`thavvu_point_assignments` +
  `site_memberships`) so they can start real work in realtime.
- Only authenticated HOD accounts may call it (checked inside the function).
- When Supabase is unavailable (widget tests), `HodSiteWorkspaceService`
  falls back to the old local-only record; in production a failed RPC raises
  a clear error instead of creating a phantom account.

## Notes About Existing Scripts

Several shell scripts exist in the root, such as:

```text
fix_all_issues.sh
fix_final_errors.sh
fix_remaining.sh
final_fix.sh
```

These appear to be previous repair scripts. Treat them as historical helpers. Do not run them unless you inspect them first and know exactly what they change.
