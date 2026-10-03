import 'package:flutter/material.dart';

/// Single source of truth for the app's look. Pages should use these tokens,
/// text styles and decorations instead of writing colours, sizes or styles
/// inline. Most widgets (fields, buttons, cards, chips, dialogs) pick up their
/// style automatically from [AppTheme.lightTheme].

// ---------------------------------------------------------------------------
// Colours
// ---------------------------------------------------------------------------

class AppColors {
  static const black = Color(0xFF000000);
  static const darkNavy = Color(0xFF07131F);
  static const deepBlue = Color(0xFF10263A);
  static const steelBlue = Color(0xFF49677E);
  static const iceBlue = Color(0xFFDCEAF2);
  static const snowWhite = Color(0xFFF7FAFC);
  static const mutedGrey = Color(0xFF8FA1AE);
  static const errorRed = Color(0xFFE53935);
  static const cardWhite = Color(0xFFFFFFFF);

  // Semantic tokens (steelBlue / black at fixed opacities, kept const).
  /// Hairline border for cards and panels (steelBlue 18%).
  static const borderSubtle = Color(0x2E49677E);

  /// Default border for fields and sections (steelBlue 28%).
  static const border = Color(0x4749677E);

  /// Emphasised border for outlined controls (steelBlue 35%).
  static const borderStrong = Color(0x5949677E);

  /// Soft drop shadow under cards (black 6%).
  static const shadow = Color(0x0F000000);

  /// Page background for in-app screens.
  static const pageBackground = iceBlue;
}

// ---------------------------------------------------------------------------
// Sizes and spacing
// ---------------------------------------------------------------------------

class AppSizes {
  static const pagePadding = 24.0;
  static const cardRadius = 22.0;
  static const inputRadius = 14.0;
  static const buttonHeight = 54.0;

  /// Radius for panels, sections, list tiles and step chips.
  static const panelRadius = 8.0;

  /// Inner padding of panels and cards.
  static const panelPadding = 16.0;

  /// Padding around the scrolling content of in-app pages.
  static const pageInsets = EdgeInsets.fromLTRB(20, 20, 20, 32);
}

// ---------------------------------------------------------------------------
// Text styles
// ---------------------------------------------------------------------------

class AppTextStyles {
  /// Page heading next to the back arrow ("Create session", "Profile"...).
  static const pageTitle = TextStyle(
    color: AppColors.darkNavy,
    fontSize: 24,
    fontWeight: FontWeight.w700,
  );

  /// Heading inside a panel ("Prepare sortie", "Flight 2").
  static const sectionTitle = TextStyle(
    color: AppColors.darkNavy,
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  /// Smaller heading inside a card ("Final decision").
  static const cardTitle = TextStyle(
    color: AppColors.darkNavy,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  /// Header row of a form section ("Vehicles taken", "Team members").
  static const sectionHeader = TextStyle(
    color: AppColors.darkNavy,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  /// Value shown inside a read-only field (e.g. the session date).
  static const fieldValue = TextStyle(
    color: AppColors.darkNavy,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  /// Bold body text.
  static const bodyStrong = TextStyle(fontWeight: FontWeight.w700);

  /// Secondary text (timestamps, group names).
  static const secondary = TextStyle(color: AppColors.steelBlue);

  /// Secondary label above a value (checklist section names).
  static const label = TextStyle(
    color: AppColors.steelBlue,
    fontWeight: FontWeight.w600,
  );

  /// Small secondary caption (carousel counter).
  static const caption = TextStyle(
    color: AppColors.steelBlue,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  /// Validation / load-failure messages.
  static const error = TextStyle(color: AppColors.errorRed);

  /// App bar title.
  static const navTitle = TextStyle(
    color: AppColors.snowWhite,
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  /// Label inside a step chip.
  static const chipLabel = TextStyle(
    color: AppColors.darkNavy,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );

  /// Vehicle name under its image in the carousel.
  static const vehicleName = TextStyle(
    color: AppColors.darkNavy,
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );

  /// "Multirotor · TAP TO SELECT" line under the vehicle name.
  static const vehicleMeta = TextStyle(
    color: AppColors.steelBlue,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );
}

// ---------------------------------------------------------------------------
// Decorations
// ---------------------------------------------------------------------------

class AppDecorations {
  /// Raised white panel that holds a page's main content.
  static const panel = BoxDecoration(
    color: AppColors.cardWhite,
    borderRadius: BorderRadius.all(Radius.circular(AppSizes.panelRadius)),
    border: Border.fromBorderSide(BorderSide(color: AppColors.borderSubtle)),
    boxShadow: [
      BoxShadow(color: AppColors.shadow, blurRadius: 18, offset: Offset(0, 8)),
    ],
  );

  /// Flat section inside a panel ("Vehicles taken", "Team members").
  static const section = BoxDecoration(
    color: AppColors.snowWhite,
    borderRadius: BorderRadius.all(Radius.circular(AppSizes.panelRadius)),
    border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
  );

  /// Step chip in the session stepper.
  static BoxDecoration stepChip({required bool active}) => BoxDecoration(
    color: active ? AppColors.deepBlue : AppColors.cardWhite,
    borderRadius: const BorderRadius.all(Radius.circular(AppSizes.panelRadius)),
    border: const Border.fromBorderSide(
      BorderSide(color: AppColors.borderSubtle),
    ),
  );

  /// Form field decoration with a leading icon. Fill, borders and radius come
  /// from [AppTheme.lightTheme]'s inputDecorationTheme.
  static InputDecoration field({required String label, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
    );
  }
}

// ---------------------------------------------------------------------------
// Vehicle carousel tile (dark blue hexagon)
// ---------------------------------------------------------------------------

class AppVehicleTile {
  static const fill = AppColors.deepBlue;
  static const selectedFill = AppColors.darkNavy;
  static const glyph = Color(0xD9F7FAFC); // snowWhite 85%
  static const selectedGlyph = AppColors.snowWhite;
  static const border = AppColors.steelBlue;
  static const selectedBorder = AppColors.iceBlue;
  static const selectedShadow = Color(0x5907131F); // darkNavy 35%

  /// Pale blue glow around a selected hexagon and behind its drawing.
  static const glow = Color(0xB3DCEAF2); // iceBlue 70%
  static const glyphGlow = Color(0xE6DCEAF2); // iceBlue 90%
}

// ---------------------------------------------------------------------------
// Create-session step indicator (1 — 2 — 3 — 4)
// ---------------------------------------------------------------------------

class AppStepper {
  static const active = AppColors.deepBlue;
  static const glow = Color(0x5910263A); // deepBlue 35%
  static const todoFill = AppColors.cardWhite;
  static const todoBorder = AppColors.borderStrong;
  static const lineDone = AppColors.deepBlue;
  static const lineTodo = AppColors.border;

  static const activeNumber = TextStyle(
    color: AppColors.snowWhite,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );
  static const todoNumber = TextStyle(
    color: AppColors.steelBlue,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );
}

// ---------------------------------------------------------------------------
// Login (dark glass card on the gradient)
// ---------------------------------------------------------------------------

class AppAuthTheme {
  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.iceBlue, AppColors.deepBlue, AppColors.darkNavy],
  );

  static const cardFill = Color(0xEB07131F); // darkNavy 92%
  static const cardBorder = Color(0x5949677E); // steelBlue 35%
  static const cardShadow = BoxShadow(
    color: Color(0x73000000), // black 45%
    blurRadius: 40,
    offset: Offset(0, 16),
  );

  static const _fieldFill = Color(0x2E49677E); // steelBlue 18%
  static const _fieldBorder = Color(0x7349677E); // steelBlue 45%
  static const _fieldFocusBorder = Color(0xCCDCEAF2); // iceBlue 80%

  static TextStyle title(double fontSize) => TextStyle(
    fontSize: fontSize,
    fontWeight: FontWeight.w700,
    letterSpacing: 4,
    color: AppColors.snowWhite,
    shadows: const [Shadow(color: Color(0x73F7FAFC), blurRadius: 18)],
  );

  static const fieldLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.mutedGrey,
  );

  static const fieldText = TextStyle(color: AppColors.snowWhite);
  static const cursorColor = AppColors.iceBlue;
  static const error = TextStyle(color: AppColors.errorRed, fontSize: 13);

  static InputDecoration field(String hint) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: const BorderRadius.all(
        Radius.circular(AppSizes.inputRadius),
      ),
      borderSide: BorderSide(color: color, width: width),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.mutedGrey),
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: border(_fieldBorder, 1),
      focusedBorder: border(_fieldFocusBorder, 1.4),
      border: border(_fieldBorder, 1),
    );
  }

  static final loginButton = ElevatedButton.styleFrom(
    elevation: 0,
    backgroundColor: const Color(0xD910263A), // deepBlue 85%
    foregroundColor: AppColors.snowWhite,
    disabledBackgroundColor: const Color(0x8210263A), // deepBlue 51%
    disabledForegroundColor: const Color(0x99F7FAFC), // snowWhite 60%
    side: const BorderSide(color: Color(0x8049677E)), // steelBlue 50%
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppSizes.inputRadius)),
    ),
  );

  static final forgotPasswordButton = TextButton.styleFrom(
    foregroundColor: AppColors.mutedGrey,
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  );
}

// ---------------------------------------------------------------------------
// ThemeData
// ---------------------------------------------------------------------------

class AppTheme {
  static ThemeData get lightTheme {
    const fieldRadius = BorderRadius.all(Radius.circular(AppSizes.inputRadius));
    const panelShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppSizes.panelRadius)),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: AppColors.pageBackground,
      primaryColor: AppColors.deepBlue,

      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: AppColors.deepBlue,
        onPrimary: AppColors.snowWhite,
        secondary: AppColors.steelBlue,
        onSecondary: AppColors.snowWhite,
        error: AppColors.errorRed,
        onError: AppColors.snowWhite,
        surface: AppColors.snowWhite,
        onSurface: AppColors.darkNavy,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.deepBlue,
        foregroundColor: AppColors.snowWhite,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.navTitle,
        iconTheme: IconThemeData(color: AppColors.snowWhite),
      ),

      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.snowWhite,
        border: OutlineInputBorder(borderRadius: fieldRadius),
        enabledBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: AppColors.deepBlue, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: AppColors.errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: AppColors.errorRed, width: 1.4),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.deepBlue,
          foregroundColor: AppColors.snowWhite,
          minimumSize: const Size(64, 48),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.deepBlue,
          foregroundColor: AppColors.snowWhite,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepBlue,
          side: const BorderSide(color: AppColors.borderStrong),
          shape: const RoundedRectangleBorder(borderRadius: fieldRadius),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.deepBlue),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.darkNavy),
      ),

      cardTheme: const CardThemeData(
        color: AppColors.cardWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppSizes.panelRadius)),
          side: BorderSide(color: AppColors.borderSubtle),
        ),
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.deepBlue,
        shape: panelShape,
      ),

      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.snowWhite,
        side: BorderSide(color: AppColors.borderSubtle),
      ),

      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.snowWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppSizes.cardRadius)),
        ),
      ),

      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.deepBlue,
        contentTextStyle: TextStyle(color: AppColors.snowWhite),
        behavior: SnackBarBehavior.floating,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.deepBlue,
      ),
    );
  }
}
