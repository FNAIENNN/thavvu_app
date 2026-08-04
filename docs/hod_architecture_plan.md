# HOD Architecture Plan for Thavvu

## Goal
Create a dedicated HOD workspace inside the same Flutter app without mixing HOD screens directly into supervisor screens. Supervisor and HOD will stay connected through shared models/services, but their UI screens will live in separate folders.

## Current Situation
- Most active screens are currently in `lib/screens/`.
- HOD logic already exists in places like `main_shell.dart`, `hod_module_review_screen.dart`, `hod_tasks_screen.dart`, `hod_workflow_store.dart`, and `hod_workflow_models.dart`.
- The next upgrade should move HOD-specific UI into `lib/screens/hod/` and keep supervisor UI separate.

## Proposed Folder Structure

```text
lib/
  screens/
    supervisor/                 # Future home for supervisor screens
      overview_screen.dart
      machines_entry_screen.dart
      daily_data_screen.dart
      attendance_screen.dart
      stock_inventory_screen.dart
      rental_screen.dart
      cash_screen.dart
      food_screen.dart
      tasks_screen.dart
      reports_screen.dart
      maps_screen.dart
      internal_transfer_screen.dart
      transfers_screen.dart
      other_screens.dart

    hod/                        # Dedicated HOD area
      hod_alerts_screen.dart     # First screen after HOD login
      hod_dashboard_screen.dart  # Optional HOD summary/home wrapper
      hod_sites_screen.dart      # View all sites + search
      hod_site_detail_screen.dart
      hod_site_modules_screen.dart

      modules/                  # HOD-coded versions of supervisor modules
        hod_overview_screen.dart
        hod_machines_entry_screen.dart
        hod_daily_data_screen.dart
        hod_attendance_screen.dart
        hod_stock_inventory_screen.dart
        hod_rental_screen.dart
        hod_cash_screen.dart
        hod_food_screen.dart
        hod_tasks_screen.dart
        hod_reports_screen.dart
        hod_maps_screen.dart
        hod_internal_transfer_screen.dart
        hod_transfers_screen.dart
        hod_other_screens.dart

  models/
    hod_workflow_models.dart     # Shared role/site/request/action models
    alert_models.dart            # Future: alert/domain models
    site_models.dart             # Future: site/module models

  services/
    auth_service.dart
    hod_workflow_store.dart      # Shared local store until backend is connected
    hod_alert_service.dart       # Future: gathers alerts across app/modules
    site_service.dart            # Future: sites and site module data
```

## HOD Login Flow
1. User logs in as HOD.
2. App checks role from `AuthService`.
3. If role is HOD, route to `lib/screens/hod/hod_alerts_screen.dart` first.
4. Alert screen gathers HOD alerts across all sites/modules.
5. Alerts are grouped by site, for example:
   - Vijayawada River Bed: 4 alerts
   - Akividu Canal Line: 2 alerts
   - Rajahmundry Lift Point: 3 alerts
6. Below the alert/site summary, show a full-width `View All Sites` button bar.
7. Tapping `View All Sites` opens `hod_sites_screen.dart`.

## HOD Alerts Screen
Purpose: first HOD screen after login.

Responsibilities:
- Load alert count per site.
- Show notification-style cards.
- Each site card should show:
  - site/place name
  - alert count badge
  - short latest alert text
  - affected module icons/emojis
- Tapping a site opens that site's module screen/detail flow.
- `View All Sites` button opens all sites list.

Future file:
- `lib/screens/hod/hod_alerts_screen.dart`

Future data source:
- `HodAlertService.getAlertsForHod(hodId)`
- Internally can use `HodWorkflowStore` first, then backend later.

## HOD Sites Screen
Purpose: list all sites available to HOD.

Responsibilities:
- Search bar at top.
- List/card view of all sites.
- Each site card should show:
  - place name, e.g. Vijayawada
  - site name, e.g. Vijayawada River Bed
  - site ID
  - supervisors assigned
  - alert count badge
  - module count/status summary
- Tapping a site opens HOD site modules.

Future file:
- `lib/screens/hod/hod_sites_screen.dart`

## HOD Site Modules Screen
Purpose: show modules for one selected site.

Responsibilities:
- Modules must match supervisor module style, look, icons/emojis, and order.
- HOD modules must be separately coded under `lib/screens/hod/modules/`.
- Tapping module opens HOD version of that module.

Module order:
1. Overview
2. New Machine / Machines
3. Daily Data
4. Attendance
5. Stock
6. Rental
7. Food
8. Cash
9. Tasks
10. Reports
11. Maps
12. Internal Transfer
13. Transfers
14. Other

Future files:
- `lib/screens/hod/hod_site_modules_screen.dart`
- `lib/screens/hod/modules/*.dart`

## Supervisor vs HOD Separation Rule
- Supervisor screens should submit work/actions.
- HOD screens should review, approve, reject, assign, configure, or monitor work.
- Shared data should go through models/services, not by importing supervisor screens into HOD screens.
- HOD UI can copy supervisor style/widgets but should not reuse supervisor screen classes directly.

## Shared Connection Layer
Supervisor and HOD stay connected through shared services:

```text
Supervisor screen -> shared service/store -> HOD alert/review screen
HOD decision      -> shared service/store -> Supervisor status/update screen
```

Current useful service:
- `lib/services/hod_workflow_store.dart`

Future services:
- `lib/services/hod_alert_service.dart`
- `lib/services/site_service.dart`

## Recommended Implementation Phases

### Phase 1: Structure only
Already started by creating empty HOD files under:
- `lib/screens/hod/`
- `lib/screens/hod/modules/`

No routing changes yet, so current app should not break.

### Phase 2: Extract HOD home flow
- Move HOD alert UI out of `main_shell.dart` into `hod_alerts_screen.dart`.
- After HOD login, navigate to HOD shell/alerts instead of blended `MainShell`.
- Keep supervisor login on existing supervisor shell.

### Phase 3: Sites list
- Implement `hod_sites_screen.dart`.
- Add search bar.
- Add site cards.
- Add alert counts per site.

### Phase 4: Site modules
- Implement `hod_site_modules_screen.dart`.
- Reuse the same module names, icons, emojis, colors, and card style as supervisor.
- Route each module to its HOD module file.

### Phase 5: HOD module screens
For each module:
- Start with the same visual layout as supervisor.
- Replace supervisor entry behavior with HOD controls.
- Example:
  - Supervisor Cash: request/spend/upload bill.
  - HOD Cash: approve limit, configure expense items, review payments.

### Phase 6: Shared alert aggregation
- Add a service that reads pending module records and produces site-level alerts.
- Alerts should include:
  - siteId
  - siteName
  - module
  - title
  - message
  - priority
  - createdAt
  - targetRoute

## Validation Commands
Run after each real implementation phase:

```bash
cd /Users/ram/Downloads/thavvu_app
flutter analyze
flutter test
flutter build web
```

## Important Notes
- Empty files are intentionally not imported yet.
- Do not move existing supervisor files until the router/shell is ready.
- Avoid mixing new HOD code inside `main_shell.dart`; use dedicated HOD files going forward.
- Keep HOD module styling consistent with supervisor module cards/icons/emojis.
