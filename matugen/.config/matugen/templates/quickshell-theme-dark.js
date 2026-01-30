// Theme.js - Dark theme (Matugen Generated)
// All components import this file for consistent styling

// Colors - Material You Dynamic (Dark)
var background = "{{colors.surface.dark.hex}}"
var surface = "{{colors.surface_container.dark.hex}}"
var surfaceVariant = "{{colors.surface_variant.dark.hex}}"
var primary = "{{colors.primary.dark.hex}}"
var secondary = "{{colors.secondary.dark.hex}}"
var tertiary = "{{colors.tertiary.dark.hex}}"
var success = "{{colors.secondary.dark.hex}}"
var warning = "{{colors.tertiary.dark.hex}}"
var error = "{{colors.error.dark.hex}}"
var textPrimary = "{{colors.on_surface.dark.hex}}"
var textSecondary = "{{colors.on_surface_variant.dark.hex}}"
var textMuted = "{{colors.outline.dark.hex}}"
var outline = "{{colors.outline_variant.dark.hex}}"

// Font sizes
var fontSizeXS = 10
var fontSizeS = 11
var fontSizeM = 12
var fontSizeL = 14
var fontSizeXL = 16
var fontSizeHuge = 28

// Spacing
var spacingXS = 4
var spacingS = 6
var spacingM = 10
var spacingL = 14
var spacingXL = 20

// Border radius
var radiusS = 6
var radiusM = 10
var radiusL = 14
var radiusXL = 20
var radiusPill = 100

// Icon sizes
var iconSizeS = 14
var iconSizeM = 18
var iconSizeL = 22

// Animation durations
var animFast = 120
var animNormal = 200
var animSlow = 300

// Helper function for alpha colors
function alpha(c, a) {
    // Parse hex color and return rgba string
    if (typeof c === "string" && c.startsWith("#")) {
        var hex = c.slice(1)
        var r, g, b
        if (hex.length === 3) {
            r = parseInt(hex[0] + hex[0], 16) / 255
            g = parseInt(hex[1] + hex[1], 16) / 255
            b = parseInt(hex[2] + hex[2], 16) / 255
        } else {
            r = parseInt(hex.slice(0, 2), 16) / 255
            g = parseInt(hex.slice(2, 4), 16) / 255
            b = parseInt(hex.slice(4, 6), 16) / 255
        }
        return Qt.rgba(r, g, b, a)
    }
    // If already a color object
    return Qt.rgba(c.r, c.g, c.b, a)
}
