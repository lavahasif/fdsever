# Shadcn UI Design Principles for Antigravity Agent

When designing or modifying user interfaces across this project, always adhere to Shadcn UI design principles:

## 1. Color Palette & Dark Mode Tokens
- **Canvas / Background**: `0xFF09090B` (Zinc 950 deep matte black)
- **Cards & Surfaces**: `0xFF18181B` (Zinc 900 elevated surface)
- **Borders & Dividers**: `0xFF27272A` (Zinc 800 1.0–1.2px crisp border)
- **Primary Text**: `Colors.white` or `0xFFF4F4F5` (Zinc 100)
- **Muted Text**: `0xFF71717A` (Zinc 500) / `0xFFA1A1AA` (Zinc 400)
- **Primary Brand / Action**: `0xFF2563EB` (Blue 600) / `0xFF38BDF8` (Sky 400)
- **Destructive**: `0xFFEF4444` (Red 500) / surface `0xFF450A0A`
- **WhatsApp / Success**: `0xFF22C55E` (Emerald 500)

## 2. Component Guidelines
- **Cards & Tiles**: 
  - Rounded corners `BorderRadius.circular(14)` or `16`.
  - Crisp border `Border.all(color: Color(0xFF27272A), width: 1.0)`.
  - Never use loud gradient backgrounds for regular list items; keep surfaces clean, dark, and matte.
- **Badges & Pills**:
  - Compact height, `padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2.5)`.
  - Subtle semi-transparent tint with matching 1px border.
- **Interactive States**:
  - Selected states use accent border (`Color(0xFF38BDF8)`) and subtle elevation highlight (`Color(0xFF1E293B)`).
  - Multi-select action bars float above or dock with subtle backdrop blur and compact buttons.
- **Icons**:
  - Always prefer `LucideIcons` with sizes between 15px and 20px for high density and modern look.
- **Sharing & Export**:
  - Provide distinct single-item quick actions (System Share sheet and direct WhatsApp share).
  - Provide multi-select bulk operations with clear selection counts and batch actions.

## 3. Safe Area, Notch & Navigation Bar Clearance
- **No Overlapping Buttons**:
  - Buttons, persistent action bars, and bottom sheets must **never** overlap or collide with the device notch, status bar, gesture pill/home indicator, or the application's bottom navigation bar (`NavigationBar`).
- **SafeArea & MediaQuery Bottom Inset**:
  - In `Scaffold.bottomNavigationBar`, wrap buttons in a `SafeArea` with `minimum: EdgeInsets.fromLTRB(16, 8, 16, 12)` or dynamically offset with `MediaQuery.paddingOf(context).bottom`.
  - In scrollable lists (`ListView`, `SingleChildScrollView`), always pad the bottom edge:
    `padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.paddingOf(context).bottom)`.
  - For floating bottom components (like `MiniPlayerBar` or snackbars positioned with `Positioned(bottom: ...)`), always add `+ MediaQuery.paddingOf(context).bottom`.

