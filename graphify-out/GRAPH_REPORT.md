# Graph Report - tiknol-mobile-flutter  (2026-06-26)

## Corpus Check
- 97 files · ~74,636 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1390 nodes · 1685 edges · 104 communities (91 shown, 13 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 44|Community 44]]
- [[_COMMUNITY_Community 45|Community 45]]
- [[_COMMUNITY_Community 46|Community 46]]
- [[_COMMUNITY_Community 47|Community 47]]
- [[_COMMUNITY_Community 48|Community 48]]
- [[_COMMUNITY_Community 49|Community 49]]
- [[_COMMUNITY_Community 50|Community 50]]
- [[_COMMUNITY_Community 51|Community 51]]
- [[_COMMUNITY_Community 52|Community 52]]
- [[_COMMUNITY_Community 53|Community 53]]
- [[_COMMUNITY_Community 54|Community 54]]
- [[_COMMUNITY_Community 55|Community 55]]
- [[_COMMUNITY_Community 56|Community 56]]
- [[_COMMUNITY_Community 57|Community 57]]
- [[_COMMUNITY_Community 58|Community 58]]
- [[_COMMUNITY_Community 59|Community 59]]
- [[_COMMUNITY_Community 60|Community 60]]
- [[_COMMUNITY_Community 61|Community 61]]
- [[_COMMUNITY_Community 62|Community 62]]
- [[_COMMUNITY_Community 63|Community 63]]
- [[_COMMUNITY_Community 64|Community 64]]
- [[_COMMUNITY_Community 65|Community 65]]
- [[_COMMUNITY_Community 66|Community 66]]
- [[_COMMUNITY_Community 67|Community 67]]
- [[_COMMUNITY_Community 68|Community 68]]
- [[_COMMUNITY_Community 69|Community 69]]
- [[_COMMUNITY_Community 70|Community 70]]
- [[_COMMUNITY_Community 71|Community 71]]
- [[_COMMUNITY_Community 72|Community 72]]
- [[_COMMUNITY_Community 73|Community 73]]
- [[_COMMUNITY_Community 74|Community 74]]
- [[_COMMUNITY_Community 75|Community 75]]
- [[_COMMUNITY_Community 76|Community 76]]
- [[_COMMUNITY_Community 77|Community 77]]
- [[_COMMUNITY_Community 78|Community 78]]
- [[_COMMUNITY_Community 79|Community 79]]
- [[_COMMUNITY_Community 80|Community 80]]
- [[_COMMUNITY_Community 81|Community 81]]
- [[_COMMUNITY_Community 91|Community 91]]
- [[_COMMUNITY_Community 92|Community 92]]
- [[_COMMUNITY_Community 93|Community 93]]
- [[_COMMUNITY_Community 94|Community 94]]
- [[_COMMUNITY_Community 95|Community 95]]
- [[_COMMUNITY_Community 96|Community 96]]
- [[_COMMUNITY_Community 97|Community 97]]
- [[_COMMUNITY_Community 98|Community 98]]
- [[_COMMUNITY_Community 99|Community 99]]
- [[_COMMUNITY_Community 100|Community 100]]
- [[_COMMUNITY_Community 101|Community 101]]
- [[_COMMUNITY_Community 102|Community 102]]

## God Nodes (most connected - your core abstractions)
1. `Hero Animations Reference` - 15 edges
2. `Physics-Based Animations Reference` - 15 edges
3. `authProvider` - 14 edges
4. `Curves Reference` - 14 edges
5. `Staggered Animations Reference` - 14 edges
6. `apiClientProvider` - 13 edges
7. `cartProvider` - 13 edges
8. `_PosScreenState` - 13 edges
9. `UI/UX Pro Max - Design Intelligence` - 13 edges
10. `Tiknol Mobile Flutter — Session Recap` - 13 edges

## Surprising Connections (you probably didn't know these)
- `AuthService` --references--> `apiClientProvider`  [EXTRACTED]
  services/auth_service.dart → lib/core/api_client.dart
- `ProductService` --references--> `apiClientProvider`  [EXTRACTED]
  services/product_service.dart → lib/core/api_client.dart
- `login` --references--> `apiClientProvider`  [EXTRACTED]
  services/auth_service.dart → lib/core/api_client.dart
- `logout` --references--> `apiClientProvider`  [EXTRACTED]
  services/auth_service.dart → lib/core/api_client.dart
- `VoucherService` --references--> `apiClientProvider`  [EXTRACTED]
  services/voucher_service.dart → lib/core/api_client.dart

## Import Cycles
- None detected.

## Communities (104 total, 13 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.18
Nodes (12): apiClientProvider, ../core/api_client.dart, _saveServerUrl, login, logout, cancelOrder, createCashOrder, createOnlinePayment (+4 more)

### Community 1 - "Community 1"
Cohesion: 0.06
Nodes (31): AnimatedListState, IconData, ../payment_webview.dart, ../../services/order_service.dart, ../../services/printer_service.dart, ../../services/receipt_service.dart, ../../services/receipt_template_service.dart, ../../services/voucher_service.dart (+23 more)

### Community 2 - "Community 2"
Cohesion: 0.12
Nodes (25): Notifier, cartItemCountProvider, auth, build, categoriesProvider, category, CategoryFilterNotifier, categoryFilterProvider (+17 more)

### Community 3 - "Community 3"
Cohesion: 0.15
Nodes (12): baseUrl, branchIdKey, branchNameKey, connectTimeout, Constants, receiveTimeout, staffSessionKey, userIdKey (+4 more)

### Community 4 - "Community 4"
Cohesion: 0.17
Nodes (11): int get, CartItem, copyWith, key, product, qty, selectedSize, selectedTemp (+3 more)

### Community 5 - "Community 5"
Cohesion: 0.15
Nodes (12): category, CustomizationOptions, fromJson, hasCustomization, id, image, isAvailable, name (+4 more)

### Community 6 - "Community 6"
Cohesion: 0.11
Nodes (17): package:cached_network_image/cached_network_image.dart, ../../providers/cart_provider.dart, ../providers/product_provider.dart, _buildPhoneHeader, _buildPhoneLayout, _buildProductGrid, _buildTabletHeader, _buildTabletLayout (+9 more)

### Community 7 - "Community 7"
Cohesion: 0.29
Nodes (12): cartProvider, cartTotalProvider, _onTap, _showCustomizationSheet, orderServiceProvider, voucherServiceProvider, build, _CartPanelState (+4 more)

### Community 8 - "Community 8"
Cohesion: 0.15
Nodes (12): package:webview_flutter/webview_flutter.dart, build, _checkUrl, _controller, createState, initState, _isLoading, orderId (+4 more)

### Community 9 - "Community 9"
Cohesion: 0.13
Nodes (19): package:dio/dio.dart, AuthNotifier, AuthState, branchId, branchName, build, copyWith, error (+11 more)

### Community 10 - "Community 10"
Cohesion: 0.14
Nodes (13): accent, AppColors, AppTheme, bg, border, danger, darkBg, darkSurface (+5 more)

### Community 11 - "Community 11"
Cohesion: 0.16
Nodes (13): api, auth, branchId, build, _buildOrderGrid, kitchenOrdersProvider, KitchenScreen, onStatusUpdate (+5 more)

### Community 12 - "Community 12"
Cohesion: 0.05
Nodes (42): Accessibility, Advanced Techniques, Animation Duration, Basic Hero Animation, Best Practices, Common Patterns, Complete Radial Hero Example, Conditional Hero Mode (+34 more)

### Community 13 - "Community 13"
Cohesion: 0.09
Nodes (27): ../providers/history_provider.dart, historyProvider, Route /pos, build, _buildCompactList, _buildHeader, _buildPhoneLayout, _buildQuickFilters (+19 more)

### Community 14 - "Community 14"
Cohesion: 0.40
Nodes (4): package:flutter_riverpod/flutter_riverpod.dart, package:flutter_test/flutter_test.dart, package:tiknol_reserve_mobile/main.dart, main

### Community 15 - "Community 15"
Cohesion: 0.05
Nodes (42): Accessibility, Adaptive Staggering, Advanced Techniques, Basic Staggered Animation, Calculate Total Duration, Common Patterns, Complex Staggered Patterns, Conditional Staggering (+34 more)

### Community 16 - "Community 16"
Cohesion: 0.05
Nodes (41): Accessibility, Adaptive Scroll Physics, Basic Fling, Basic Spring, Best Practices, Bouncing Scroll, Bouncy Button Press, Clamping Scroll (+33 more)

### Community 17 - "Community 17"
Cohesion: 0.07
Nodes (32): DateTime?, ansi_ljust(), DesignSystemGenerator, _detect_page_type(), format_ascii_box(), format_markdown(), format_master_md(), format_page_override_md() (+24 more)

### Community 18 - "Community 18"
Cohesion: 0.05
Nodes (37): AnimatedBuilder Pattern, AnimatedWidget Pattern, Animation Status Handling, AnimationController, Basic Status Loop, Bounce Effect, Built-in Transitions, Common Patterns (+29 more)

### Community 19 - "Community 19"
Cohesion: 0.07
Nodes (28): 10. Known Issues & Next Steps, 11. File Changes Summary, 1. Status Implementasi, 2. Arsitektur Flutter App, 3. Backend API yang Digunakan, 4. Perubahan Backend (Security Fixes) yang Berpengaruh, 5. Bug Fixes yang Sudah Dilakukan, 6. Environment Variables (+20 more)

### Community 20 - "Community 20"
Cohesion: 0.07
Nodes (28): AnimatedAlign, AnimatedContainer, AnimatedContainer (Multiple Properties), AnimatedDefaultTextStyle, AnimatedOpacity, AnimatedPadding, AnimatedPhysicalModel, AnimatedPositioned (+20 more)

### Community 21 - "Community 21"
Cohesion: 0.09
Nodes (26): MaterialPageRoute, StatelessWidget, static const List, build, ExplicitAnimationApp, GrowTransition, LogoAnimationDemo, LogoWidget (+18 more)

### Community 22 - "Community 22"
Cohesion: 0.08
Nodes (25): 1. Ringkasan Temuan, 2.1 API Base URL Hardcoded, 2.2 Debug Mode di Production, 2.3 Tidak Ada Certificate Pinning, 2.4 Tidak Ada Biometric Auth, 2.5 Tidak Ada Session Timeout, 2.6 Deep Link Validation, 2.7 Error Messages Expose Stack Trace (+17 more)

### Community 23 - "Community 23"
Cohesion: 0.08
Nodes (25): 1. Animation Optimization, 1. Controller Management, 1. Image Optimization, 1. ListView.builder vs ListView, 1. Performance Overlay, 1. Widget Rebuild Optimization, 2. Const Constructors, 2. Custom Performance Monitor (+17 more)

### Community 24 - "Community 24"
Cohesion: 0.08
Nodes (25): AnimationController, Offset, animation, _animationDuration, borderRadius, build, _buildAnimation, color (+17 more)

### Community 25 - "Community 25"
Cohesion: 0.11
Nodes (14): Any, Bool, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, FlutterSceneDelegate, AppDelegate (+6 more)

### Community 26 - "Community 26"
Cohesion: 0.15
Nodes (15): BM25, detect_domain(), _load_csv(), BM25 ranking algorithm for text search, Lowercase, split, remove punctuation, filter short words, Build BM25 index from documents, Score all documents against query, Load CSV and return list of dicts (+7 more)

### Community 27 - "Community 27"
Cohesion: 0.04
Nodes (47): package:file_picker/file_picker.dart, build, PrinterDirtyNotifier, printerDirtyProvider, setValue, build, _buildBodyCard, _buildConnectionCard (+39 more)

### Community 28 - "Community 28"
Cohesion: 0.11
Nodes (24): AnimatedWidget, Animation, SingleTickerProviderStateMixin, static final, AnimatedBuilderDemo, _AnimatedBuilderDemoState, AnimatedLogo, AnimatedWidgetDemo (+16 more)

### Community 29 - "Community 29"
Cohesion: 0.12
Nodes (16): Accessibility (Required), Animation Types, Core Philosophy, Custom Widget Examples, Development Workflow, Flutter UI/UX Development, Performance Guidelines, Phase 1: Analyze Requirements (+8 more)

### Community 30 - "Community 30"
Cohesion: 0.12
Nodes (16): 1. AnimatedContainer, 1. Custom Tween Animation, 1. Hero Navigation, 1. Optimized Animations, 1. Spring Animation, 2. AnimatedOpacity & AnimatedScale, 2. Animation Curves, 2. Custom Hero Animation (+8 more)

### Community 31 - "Community 31"
Cohesion: 0.13
Nodes (14): 1. Builder Pattern, 1. ListView Optimization, 1. Responsive Grid, 1. Swipeable List Item, 2. Expandable Section, 2. Pull to Refresh, 2. RepaintBoundary, 2. State Management Pattern (+6 more)

### Community 32 - "Community 32"
Cohesion: 0.29
Nodes (13): blend(), derive_row(), derive_ui_reasoning(), h2r(), is_dark(), lum(), on_color(), r2h() (+5 more)

### Community 33 - "Community 33"
Cohesion: 0.14
Nodes (13): Common Skill Categories, Find Skills, How to Help Users Find Skills, Step 1: Understand What They Need, Step 2: Check the Leaderboard First, Step 3: Search for Skills, Step 4: Verify Quality Before Recommending, Step 5: Present Options to the User (+5 more)

### Community 34 - "Community 34"
Cohesion: 0.14
Nodes (20): class, PaymentWebView, _PaymentWebViewState, State, StatefulWidget, CircularHeroExample, _CircularHeroExampleState, _animated (+12 more)

### Community 35 - "Community 35"
Cohesion: 0.15
Nodes (12): Architecting Flutter Applications, Architectural Layers, Contents, Data Layer, Data Layer: Service and Repository, Examples, Logic Layer (Domain - Optional), Project Structure (+4 more)

### Community 36 - "Community 36"
Cohesion: 0.15
Nodes (12): 1. Access Theme in Widgets, 1. Dynamic Color Theme, 1. Multi-Theme System, 1. Responsive Theme Builder, 2. Brand Theme, 2. Theme Switcher Widget, 2. Theme Switching Animation, Custom Theme System (+4 more)

### Community 37 - "Community 37"
Cohesion: 0.17
Nodes (11): constants.dart, ApiClient, clearSession, client, _dio, refreshBaseUrl, secureStorageProvider, _storage (+3 more)

### Community 38 - "Community 38"
Cohesion: 0.14
Nodes (17): ChangeNotifier, ConsumerState, ConsumerStatefulWidget, _GoRouterRefreshNotifier, authProvider, cartProductQtyProvider, _fetchPage, build (+9 more)

### Community 39 - "Community 39"
Cohesion: 0.18
Nodes (10): dart:convert, dart:io, dart:typed_data, package:esc_pos_utils_plus/esc_pos_utils_plus.dart, package:image/image.dart, package:intl/intl.dart, generateAsciiPreview, generateEscPosBytes (+2 more)

### Community 40 - "Community 40"
Cohesion: 0.18
Nodes (10): Adaptive Layout using LayoutBuilder, Constraining Width on Large Screens, Contents, Device and Orientation Behaviors, Examples, Implementing Adaptive Layouts, Space Measurement Guidelines, Widget Sizing and Constraints (+2 more)

### Community 41 - "Community 41"
Cohesion: 0.18
Nodes (10): discount, errorMessage, ref, valid, validate, voucherCode, voucherId, voucherName (+2 more)

### Community 42 - "Community 42"
Cohesion: 0.18
Nodes (11): 10. Charts & Data (LOW), 1. Accessibility (CRITICAL), 2. Touch & Interaction (CRITICAL), 3. Performance (HIGH), 4. Style Selection (HIGH), 5. Layout & Responsive (HIGH), 6. Typography & Color (MEDIUM), 7. Animation (MEDIUM) (+3 more)

### Community 43 - "Community 43"
Cohesion: 0.20
Nodes (9): API Service Template, Basic App Structure, Flutter App Template, Navigation Template, Responsive App Template, Screen Templates, State Management Template, Usage Example (+1 more)

### Community 44 - "Community 44"
Cohesion: 0.20
Nodes (10): Back (Overshoot), Bounce, Built-in Curves, Cubic (Stronger Ease), Custom Curves in Flutter API, Decelerate (Fast then Slow), Ease (Sigmoid), Elastic (Bouncy) (+2 more)

### Community 45 - "Community 45"
Cohesion: 0.31
Nodes (4): Bundle, Configuration, FlutterActivity, MainActivity

### Community 46 - "Community 46"
Cohesion: 0.05
Nodes (37): bluetooth_classic_service.dart, BluetoothCharacteristic?, BluetoothDevice?, BluetoothDevice? get, package:flutter_blue_plus/flutter_blue_plus.dart, _bleCharacteristic, _bleDevice, _classicService (+29 more)

### Community 47 - "Community 47"
Cohesion: 0.22
Nodes (8): Available Domains, Available Stacks, How to Use, Output Formats, Prerequisites, Rule Categories by Priority, Search Reference, UI/UX Pro Max - Design Intelligence

### Community 48 - "Community 48"
Cohesion: 0.25
Nodes (7): Constraints, Decision Guide, Flutter Animations, Principle 0, Resource Routing, Validation, Workflow

### Community 49 - "Community 49"
Cohesion: 0.43
Nodes (6): code_sign_if_enabled(), install_bcsymbolmap(), install_dsym(), install_framework(), strip_invalid_archs(), Pods-Runner-frameworks.sh script

### Community 50 - "Community 50"
Cohesion: 0.18
Nodes (10): List, ../models/cart_item.dart, addItem, build, cart, CartNotifier, clear, fold (+2 more)

### Community 51 - "Community 51"
Cohesion: 0.29
Nodes (6): ../models/product.dart, Ref, fetchProducts, ProductService, productServiceProvider, ref

### Community 52 - "Community 52"
Cohesion: 0.29
Nodes (6): Design principles, Frontend Design, Ground it in the subject, More on writing in design, Process: brainstorm, explore, plan, critique, build, critique again, Restraint and self-critique

### Community 53 - "Community 53"
Cohesion: 0.29
Nodes (6): Accessibility, Core Concept, Curve Comparison, Curves Reference, Reduced Motion, Respecting User Preferences

### Community 54 - "Community 54"
Cohesion: 0.33
Nodes (5): handle_new_rx_page(), __lldb_init_module(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages., SBDebugger, SBFrame

### Community 55 - "Community 55"
Cohesion: 0.33
Nodes (6): Accessibility, Interaction, Layout, Light/Dark Mode, Pre-Delivery Checklist, Visual Quality

### Community 56 - "Community 56"
Cohesion: 0.33
Nodes (6): How to Use This Skill, Step 1: Analyze User Requirements, Step 2: Generate Design System (REQUIRED), Step 2b: Persist Design System (Master + Overrides Pattern), Step 3: Supplement with Detailed Searches (as needed), Step 4: Stack Guidelines (React Native)

### Community 57 - "Community 57"
Cohesion: 0.40
Nodes (5): Common Patterns, Loading Spinner, Modal Popup, Page Transition, Success Checkmark

### Community 58 - "Community 58"
Cohesion: 0.40
Nodes (5): Creating a Custom Curve, Custom Curves, Exponential Curve, Shake Curve, Smooth Step Curve

### Community 59 - "Community 59"
Cohesion: 0.40
Nodes (5): Using Curves, With Curves.elasticOut, With Explicit Animation (CurvedAnimation), With Implicit Animation, With Interval

### Community 60 - "Community 60"
Cohesion: 0.40
Nodes (5): Common Rules for Professional UI, Icons & Visual Elements, Interaction (App), Layout & Spacing, Light/Dark Mode Contrast

### Community 61 - "Community 61"
Cohesion: 0.40
Nodes (5): Example Workflow, Step 1: Analyze Requirements, Step 2: Generate Design System (REQUIRED), Step 3: Supplement with Detailed Searches (as needed), Step 4: Stack Guidelines

### Community 63 - "Community 63"
Cohesion: 0.06
Nodes (33): BluetoothConnection?, bool get, dart:async, package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart, package:permission_handler/permission_handler.dart, BluetoothClassicService, BluetoothDeviceInfo, clearSavedDevice (+25 more)

### Community 64 - "Community 64"
Cohesion: 0.50
Nodes (4): Common Sticking Points, Pre-Delivery Checklist, Query Strategy, Tips for Better Results

### Community 65 - "Community 65"
Cohesion: 0.50
Nodes (4): Must Use, Recommended, Skip, When to Apply

### Community 71 - "Community 71"
Cohesion: 0.06
Nodes (33): alignment, bold, copyWith, fontSize, fromJson, fromJsonString, itemFormat, logoPath (+25 more)

### Community 73 - "Community 73"
Cohesion: 0.67
Nodes (3): Best Practices, DO, DON'T

### Community 74 - "Community 74"
Cohesion: 0.67
Nodes (3): Choosing the Right Curve, Motion Design Guidelines, Platform Conventions

### Community 75 - "Community 75"
Cohesion: 0.67
Nodes (3): Combining Curves, Cubic Bezier, Curve Composition

### Community 76 - "Community 76"
Cohesion: 0.67
Nodes (3): Curve Combinations, Multi-Stage Animation, Staggered with Different Curves

### Community 77 - "Community 77"
Cohesion: 0.67
Nodes (3): Curve Complexity, Optimization Tips, Performance Considerations

### Community 78 - "Community 78"
Cohesion: 0.67
Nodes (3): Debugging Curves, Print Curve Values, Visualize Curve

### Community 91 - "Community 91"
Cohesion: 0.06
Nodes (30): 10. Catatan Teknis, 11. Referensi Backend, 1. Ringkasan Eksekutif, 2. Kondisi Backend Saat Ini (API yang Sudah Siap), 3. Kondisi Backend yang BELUM Siap, 4.1 Real-Time Order Push (Supabase Realtime), 4.2 Sound & Vibration Alert, 4.3 Elapsed Timer per Order (+22 more)

### Community 92 - "Community 92"
Cohesion: 0.07
Nodes (27): build, clearDateRange, clearSearch, copyWith, error, fetch, from, hasMore (+19 more)

### Community 93 - "Community 93"
Cohesion: 0.08
Nodes (23): 10. Checklist Pre-Migration, 11. Referensi, 1. Ringkasan Eksekutif, 2. Kondisi Saat Ini vs Target, 3. Opsi Arsitektur Real-Time untuk VPS, 4. Rekomendasi: Fase Bertahap, 5. Perbandingan Opsi, 6. Flutter Code Changes (Minimal) (+15 more)

### Community 94 - "Community 94"
Cohesion: 0.12
Nodes (17): ../../core/theme.dart, Map, package:google_fonts/google_fonts.dart, package:lucide_icons/lucide_icons.dart, ../providers/printer_settings_provider.dart, build, child, createState (+9 more)

### Community 95 - "Community 95"
Cohesion: 0.11
Nodes (17): FormState, _buildLoginForm, _buildPhoneLayout, _buildTabletLayout, _connectionStatus, createState, dispose, _employeeIdController (+9 more)

### Community 96 - "Community 96"
Cohesion: 0.14
Nodes (13): ../models/receipt_template.dart, package:shared_preferences/shared_preferences.dart, clear, _key, load, ReceiptTemplateService, save, getBaseUrl (+5 more)

### Community 97 - "Community 97"
Cohesion: 0.15
Nodes (13): ConsumerWidget, core/router.dart, routerProvider, build, child, _ForceLandscape, main, setPreferredOrientations (+5 more)

### Community 98 - "Community 98"
Cohesion: 0.20
Nodes (9): refreshNotifier, GoRouter, package:go_router/go_router.dart, ../screens/history_screen.dart, ../screens/kitchen_screen.dart, ../screens/login_screen.dart, ../screens/pos_screen.dart, ../screens/printer_settings_screen.dart (+1 more)

### Community 99 - "Community 99"
Cohesion: 0.25
Nodes (7): ../core/constants.dart, package:flutter_secure_storage/flutter_secure_storage.dart, AuthService, getSavedSession, hasSession, ref, _storage

## Knowledge Gaps
- **821 isolated node(s):** `_controller`, `_animation`, `child`, `_opacityTween`, `_sizeTween` (+816 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **13 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What connects `_controller`, `_animation`, `child` to the rest of the system?**
  _853 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.0625 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.11692307692307692 - nodes in this community are weakly interconnected._
- **Should `Community 6` be split into smaller, more focused modules?**
  _Cohesion score 0.1111111111111111 - nodes in this community are weakly interconnected._
- **Should `Community 9` be split into smaller, more focused modules?**
  _Cohesion score 0.12631578947368421 - nodes in this community are weakly interconnected._
- **Should `Community 10` be split into smaller, more focused modules?**
  _Cohesion score 0.14285714285714285 - nodes in this community are weakly interconnected._
- **Should `Community 12` be split into smaller, more focused modules?**
  _Cohesion score 0.046511627906976744 - nodes in this community are weakly interconnected._