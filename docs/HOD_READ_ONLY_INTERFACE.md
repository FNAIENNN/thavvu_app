# HOD Read-Only Interface

## Purpose

The HOD interface mirrors the supervisor app shell, dashboard spacing, blue top navigation, drawer behavior, card styling, and module order. The HOD role is intentionally read-only: it can view supervisor/site/module data but cannot create, submit, approve, reject, edit, delete, upload, or save records from this flow.

## Entry Points

- Login routes HOD credentials to `HodMainShell`.
- Splash routes persisted HOD sessions to `HodMainShell`.
- Supervisor sessions continue to use `MainShell`.

## Navigation Bar Structure

The HOD top bar follows the supervisor shell:

- Logo and menu button on the left.
- Title: `Thavvu HOD`.
- Subtitle: `HOD-001 • Read-only monitoring`.
- Logout action with confirmation.

The drawer contains:

- Main: Alerts, Sites.
- Modules: Maps & Specs, Tasks & Checklist, New Machine Entry, Daily Machines Data, Attendance, Stock Inventory, Rental, Cash, Food, Reports.

This aligns the first HOD screen with the supervisor experience while keeping HOD-specific browsing paths available.

## Module Order

1. Maps & Specs
2. Tasks & Checklist
3. New Machine Entry
4. Daily Machines Data
5. Attendance
6. Stock Inventory
7. Rental
8. Cash
9. Food
10. Reports

`Others` and internal transfer are not exposed in the HOD overview/module grid.

## Hermes Data Integration

The Hermes requirement changed the HOD scope from admin/approval actions to read-only monitoring. The implementation follows that by:

- Creating `HodMainShell` and `HodReadOnlyOverviewScreen`.
- Routing HOD login/splash into the new shell.
- Adding `HodModuleReadOnlyScreen` for module data.
- Reworking `HodSiteModulesScreen` into supervisor-style two-column read-only cards.
- Removing the HOD Thavvu Point creation UI.
- Making `HodMachinesEntryScreen` default to read-only monitoring.
- Keeping alert, site, Thavvu point, module, history, record, and finance data visible without action buttons.

## Key Files

- `lib/screens/hod/hod_main_shell.dart`
- `lib/screens/hod/hod_read_only_overview_screen.dart`
- `lib/screens/hod/hod_module_read_only_screen.dart`
- `lib/screens/hod/hod_site_modules_screen.dart`
- `lib/screens/hod/hod_thavvu_points_screen.dart`
- `lib/screens/hod/modules/hod_machines_entry_screen.dart`
- `lib/screens/login_screen.dart`
- `lib/screens/splash_screen.dart`
