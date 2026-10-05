#!/bin/sh
# Probe the size and alignment of every bound Clay struct with the host C compiler and pin
# them on the C3 side, per platform: MSVC compiles Clay's packed enums at int size.
#
# Usage:
#   scripts/probe-layout.sh                      print the probed layouts
#   scripts/probe-layout.sh --check              fail if this platform's layout drifted
#   scripts/probe-layout.sh --update             rewrite this platform's sizes and pins
#   scripts/probe-layout.sh --generate windows   rewrite src/layout_windows.c3 from its sizes file
#
# The compiler is cc under a Linux shell and cl under a Windows one, so each CI job checks its
# own platform: scripts/abi-sizes-posix.txt and src/layout_posix.c3 on Linux,
# scripts/abi-sizes-windows.txt and src/layout_windows.c3 on Windows.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HEADER="$ROOT/vendor/clay/clay.h"
MODE="${1:-}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) PLATFORM=windows ;;
    *)                    PLATFORM=posix ;;
esac
if [ "$MODE" = "--generate" ]; then
    PLATFORM="$2"
fi

# One line per struct: the C name and its C3 spelling.
TYPES='
Clay_String Chars
Clay_StringSlice CharsSlice
Clay_Arena Arena
Clay_Dimensions Dimensions
Clay_Vector2 Vector2
Clay_Color Color
Clay_BoundingBox BoundingBox
Clay_ElementId ElementId
Clay_ElementIdArray ElementIdArray
Clay_CornerRadius CornerRadius
Clay_ChildAlignment ChildAlignment
Clay_SizingMinMax SizingMinMax
Clay_SizingAxis SizingAxis
Clay_Sizing Sizing
Clay_Padding Padding
Clay_LayoutConfig LayoutConfig
Clay_TextElementConfig TextElementConfig
Clay_AspectRatioElementConfig AspectRatioElementConfig
Clay_ImageElementConfig ImageElementConfig
Clay_FloatingAttachPoints FloatingAttachPoints
Clay_FloatingElementConfig FloatingElementConfig
Clay_CustomElementConfig CustomElementConfig
Clay_ClipElementConfig ClipElementConfig
Clay_BorderWidth BorderWidth
Clay_BorderElementConfig BorderElementConfig
Clay_TransitionData TransitionData
Clay_TransitionCallbackArguments TransitionCallbackArguments
Clay_TransitionElementConfig TransitionElementConfig
Clay_TextRenderData TextRenderData
Clay_RectangleRenderData RectangleRenderData
Clay_ImageRenderData ImageRenderData
Clay_CustomRenderData CustomRenderData
Clay_ClipRenderData ClipRenderData
Clay_OverlayColorRenderData OverlayColorRenderData
Clay_BorderRenderData BorderRenderData
Clay_RenderData RenderData
Clay_ScrollContainerData ScrollContainerData
Clay_ElementData ElementData
Clay_RenderCommand RenderCommand
Clay_RenderCommandArray RenderCommandArray
Clay_PointerData PointerData
Clay_ElementDeclaration ElementDeclaration
Clay_ErrorData ErrorData
Clay_ErrorHandler ErrorHandler
'

# One line per pinned field of the structs c3d::ui reads and writes: the C struct, C field, C3 struct, C3 field.
OFFSETS='
Clay_LayoutConfig sizing LayoutConfig sizing
Clay_LayoutConfig padding LayoutConfig padding
Clay_LayoutConfig childGap LayoutConfig child_gap
Clay_LayoutConfig childAlignment LayoutConfig child_alignment
Clay_LayoutConfig layoutDirection LayoutConfig layout_direction
Clay_TextElementConfig userData TextElementConfig user_data
Clay_TextElementConfig textColor TextElementConfig text_color
Clay_TextElementConfig fontId TextElementConfig font_id
Clay_TextElementConfig fontSize TextElementConfig font_size
Clay_TextElementConfig letterSpacing TextElementConfig letter_spacing
Clay_TextElementConfig lineHeight TextElementConfig line_height
Clay_TextElementConfig wrapMode TextElementConfig wrap_mode
Clay_TextElementConfig textAlignment TextElementConfig text_alignment
Clay_FloatingElementConfig offset FloatingElementConfig offset
Clay_FloatingElementConfig expand FloatingElementConfig expand
Clay_FloatingElementConfig parentId FloatingElementConfig parent_id
Clay_FloatingElementConfig zIndex FloatingElementConfig z_index
Clay_FloatingElementConfig attachPoints FloatingElementConfig attach_points
Clay_FloatingElementConfig pointerCaptureMode FloatingElementConfig pointer_capture_mode
Clay_FloatingElementConfig attachTo FloatingElementConfig attach_to
Clay_FloatingElementConfig clipTo FloatingElementConfig clip_to
Clay_ClipElementConfig childOffset ClipElementConfig child_offset
Clay_TextRenderData stringContents TextRenderData string_contents
Clay_TextRenderData textColor TextRenderData text_color
Clay_TextRenderData fontId TextRenderData font_id
Clay_TextRenderData fontSize TextRenderData font_size
Clay_TextRenderData lineHeight TextRenderData line_height
Clay_CustomRenderData customData CustomRenderData custom_data
Clay_RenderCommand boundingBox RenderCommand bounding_box
Clay_RenderCommand renderData RenderCommand render_data
Clay_RenderCommand userData RenderCommand user_data
Clay_RenderCommand id RenderCommand id
Clay_RenderCommand zIndex RenderCommand z_index
Clay_RenderCommand commandType RenderCommand command_type
Clay_ElementDeclaration layout ElementDeclaration layout
Clay_ElementDeclaration backgroundColor ElementDeclaration background_color
Clay_ElementDeclaration overlayColor ElementDeclaration overlay_color
Clay_ElementDeclaration cornerRadius ElementDeclaration corner_radius
Clay_ElementDeclaration aspectRatio ElementDeclaration aspect_ratio
Clay_ElementDeclaration image ElementDeclaration image
Clay_ElementDeclaration floating ElementDeclaration floating
Clay_ElementDeclaration custom ElementDeclaration custom
Clay_ElementDeclaration clip ElementDeclaration clip
Clay_ElementDeclaration border ElementDeclaration border
Clay_ElementDeclaration transition ElementDeclaration transition
Clay_ElementDeclaration userData ElementDeclaration user_data
'

SIZES="$ROOT/scripts/abi-sizes-$PLATFORM.txt"
LAYOUT="$ROOT/src/layout_$PLATFORM.c3"
case "$PLATFORM" in
    windows) FEATURE='WIN32' ;;
    *)       FEATURE='!WIN32' ;;
esac

generate_layout() {
    echo "module clay @feat($FEATURE);"
    echo ''
    echo "// Generated by scripts/probe-layout.sh from scripts/abi-sizes-$PLATFORM.txt. Do not edit."
    echo ''
    printf '%s\n' "$TYPES" | while read -r cname c3name; do
        [ -z "$cname" ] && continue
        line="$(grep "^$cname " "$1")"
        size="$(printf '%s' "$line" | cut -d' ' -f2)"
        align="$(printf '%s' "$line" | cut -d' ' -f3)"
        echo "\$assert $c3name::size == $size;"
        echo "\$assert $c3name::alignment == $align;"
    done
    printf '%s\n' "$OFFSETS" | while read -r cname cfield c3name c3field; do
        [ -z "$cname" ] && continue
        offset="$(grep "^$cname.$cfield " "$1" | cut -d' ' -f2)"
        echo "\$assert \$reflect($c3name.$c3field).offset == $offset;"
    done
}

if [ "$MODE" = "--generate" ]; then
    generate_layout "$SIZES" > "$LAYOUT"
    echo "wrote $LAYOUT"
    exit 0
fi

if [ ! -f "$HEADER" ]; then
    echo "ERROR: vendor/clay is empty. Run: git submodule update --init" >&2
    exit 1
fi

case "$PLATFORM" in
    windows) INCLUDE_PATH="$(cygpath -m "$HEADER")" ;;
    *)       INCLUDE_PATH="$HEADER" ;;
esac

{
    echo '#include <stdio.h>'
    echo '#include <stddef.h>'
    echo "#include \"$INCLUDE_PATH\""
    echo 'int main(void) {'
    printf '%s\n' "$TYPES" | while read -r cname c3name; do
        [ -z "$cname" ] && continue
        printf '    printf("%s %%zu %%zu\\n", sizeof(%s), _Alignof(%s));\n' "$cname" "$cname" "$cname"
    done
    printf '%s\n' "$OFFSETS" | while read -r cname cfield c3name c3field; do
        [ -z "$cname" ] && continue
        printf '    printf("%s.%s %%zu\\n", offsetof(%s, %s));\n' "$cname" "$cfield" "$cname" "$cfield"
    done
    echo '    return 0;'
    echo '}'
} > "$WORK/probe.c"

case "$PLATFORM" in
    windows)
        (cd "$WORK" && MSYS2_ARG_CONV_EXCL="*" cl -nologo -std:c11 -Fe:probe.exe probe.c)
        PROBE="$WORK/probe.exe"
        ;;
    *)
        cc -std=c11 -o "$WORK/probe" "$WORK/probe.c"
        PROBE="$WORK/probe"
        ;;
esac

"$PROBE" | tr -d "\r" > "$WORK/sizes.txt"

case "$MODE" in
    --update)
        cp "$WORK/sizes.txt" "$SIZES"
        generate_layout "$SIZES" > "$LAYOUT"
        echo "wrote $SIZES and $LAYOUT"
        ;;
    --check)
        if ! diff -u "$SIZES" "$WORK/sizes.txt"; then
            echo "ERROR: probed layout differs from scripts/abi-sizes-$PLATFORM.txt" >&2
            exit 1
        fi
        generate_layout "$SIZES" > "$WORK/layout.c3"
        if ! diff -u "$LAYOUT" "$WORK/layout.c3"; then
            echo "ERROR: src/layout_$PLATFORM.c3 is stale; run scripts/probe-layout.sh --update" >&2
            exit 1
        fi
        echo "layout pins match"
        ;;
    *)
        cat "$WORK/sizes.txt"
        ;;
esac
