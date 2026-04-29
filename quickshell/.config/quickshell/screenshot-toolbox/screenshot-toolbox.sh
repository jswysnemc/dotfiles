#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
log_file="${XDG_RUNTIME_DIR:-/tmp}/qs-screenshot-toolbox.log"

has() {
    command -v "$1" >/dev/null 2>&1
}

log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*" >>"$log_file"
}

notify() {
    if has notify-send; then
        notify-send "截图工具" "$1"
    fi
}

extract_color() {
    grep -Eo '#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?' | head -1 || true
}

save_dir() {
    local pictures=""
    if has xdg-user-dir; then
        pictures="$(xdg-user-dir PICTURES 2>/dev/null || true)"
    fi
    pictures="${pictures:-"$HOME/Pictures"}"
    printf '%s\n' "${SCREENSHOT_DIR:-"$pictures/Screenshots"}"
}

new_path() {
    local dir
    dir="$(save_dir)"
    mkdir -p "$dir"
    printf '%s/screenshot_%s.png\n' "$dir" "$(date +%Y-%m-%d_%H-%M-%S)"
}

cleanup_freeze() {
    if [[ -n "${freeze_pid:-}" ]]; then
        kill "$freeze_pid" 2>/dev/null || true
        wait "$freeze_pid" 2>/dev/null || true
    fi
}

pick_geometry() {
    local use_freeze="${1:-off}"
    local geometry

    if [[ "$use_freeze" == "on" ]] && has wayfreeze; then
        wayfreeze &
        freeze_pid=$!
        trap cleanup_freeze EXIT
        sleep 0.1
    fi

    set +e
    geometry="$(slurp)"
    local rc=$?
    set -e

    cleanup_freeze
    trap - EXIT

    if [[ $rc -ne 0 || -z "${geometry// /}" ]]; then
        exit 130
    fi

    printf '%s\n' "$geometry"
}

capture_region_file() {
    local use_freeze="${1:-off}"
    local geometry path

    geometry="$(pick_geometry "$use_freeze")"
    path="$(new_path)"
    grim -g "$geometry" "$path"
    printf '%s\n' "$path"
}

capture_fullscreen_file() {
    local path

    path="$(new_path)"
    grim "$path"
    printf '%s\n' "$path"
}

copy_png_file() {
    local path="$1"

    if has wl-copy; then
        wl-copy --type image/png <"$path"
    fi
}

measure_pixels() {
    local geometry origin dimensions width height area result

    set +e
    geometry="$(slurp -d)"
    local rc=$?
    set -e

    if [[ $rc -ne 0 || -z "${geometry// /}" ]]; then
        exit 130
    fi

    origin="${geometry%% *}"
    dimensions="${geometry##* }"
    width="${dimensions%x*}"
    height="${dimensions#*x}"
    area=$((width * height))
    result="${dimensions}  ${area}px  @ ${origin}"

    if has wl-copy; then
        printf '%s\n' "$result" | wl-copy
    fi
    notify "像素测量: $result"
}

ocr_lang() {
    local preferred="${OCR_LANG:-auto}"
    local langs

    if [[ "$preferred" != "auto" ]]; then
        printf '%s\n' "$preferred"
        return 0
    fi

    langs="$(tesseract --list-langs 2>/dev/null | tail -n +2 || true)"
    if printf '%s\n' "$langs" | grep -qx 'chi_sim' && printf '%s\n' "$langs" | grep -qx 'eng'; then
        printf '%s\n' 'chi_sim+eng'
    elif printf '%s\n' "$langs" | grep -qx 'chi_sim'; then
        printf '%s\n' 'chi_sim'
    elif printf '%s\n' "$langs" | grep -qx 'chi_tra' && printf '%s\n' "$langs" | grep -qx 'eng'; then
        printf '%s\n' 'chi_tra+eng'
    elif printf '%s\n' "$langs" | grep -qx 'chi_tra'; then
        printf '%s\n' 'chi_tra'
    else
        printf '%s\n' 'eng'
    fi
}

preprocess_ocr_image() {
    local input="$1"
    local output="$2"
    local scale="${OCR_SCALE:-300}"
    local dpi="${OCR_DPI:-300}"
    local mean=""
    local negate=()
    local binarize=()

    if ! has magick; then
        cp "$input" "$output"
        return 0
    fi

    mean="$(magick "$input" -alpha remove -colorspace Gray -format '%[fx:mean]' info: 2>/dev/null || true)"
    if [[ -n "$mean" ]] && awk -v mean="$mean" 'BEGIN { exit !(mean < 0.45) }'; then
        negate=(-negate)
    fi

    if [[ "${OCR_BINARIZE:-0}" == "1" ]]; then
        binarize=(-threshold "${OCR_THRESHOLD:-55}%")
    fi

    magick "$input" \
        -alpha remove -background white -alpha off \
        -colorspace Gray \
        "${negate[@]}" \
        -filter Lanczos -resize "${scale}%" \
        -density "$dpi" -units PixelsPerInch \
        -auto-level -sharpen 0x0.8 \
        "${binarize[@]}" \
        "$output"
}

normalize_ocr_text() {
    if has perl; then
        perl -CSDA -Mutf8 -pe '1 while s/([\p{Han}])\s+([\p{Han}])/$1$2/g'
    else
        cat
    fi
}

ocr_region() {
    local geometry raw_path processed_path text lang psm dpi rc

    if ! has tesseract; then
        notify "未找到 tesseract"
        exit 1
    fi

    geometry="$(pick_geometry on)"
    raw_path="${XDG_RUNTIME_DIR:-/tmp}/qs-ocr-raw-$(date +%s%N).png"
    processed_path="${XDG_RUNTIME_DIR:-/tmp}/qs-ocr-processed-$(date +%s%N).png"
    grim -g "$geometry" "$raw_path"
    preprocess_ocr_image "$raw_path" "$processed_path"
    lang="$(ocr_lang)"
    psm="${OCR_PSM:-6}"
    dpi="${OCR_DPI:-300}"
    log "ocr_region: geometry=$geometry lang=$lang psm=$psm dpi=$dpi raw=$raw_path processed=$processed_path"

    set +e
    text="$(tesseract "$processed_path" stdout -l "$lang" --oem 1 --psm "$psm" \
        -c preserve_interword_spaces=1 \
        -c user_defined_dpi="$dpi" \
        2>>"$log_file")"
    rc=$?
    set -e
    if [[ "${OCR_KEEP_IMAGE:-0}" != "1" ]]; then
        rm -f "$raw_path" "$processed_path"
    else
        log "ocr_region: kept images raw=$raw_path processed=$processed_path"
    fi

    if [[ $rc -ne 0 ]]; then
        log "ocr_region: tesseract failed rc=$rc lang=$lang"
        notify "OCR 识别失败"
        exit 1
    fi

    text="$(printf '%s\n' "$text" | normalize_ocr_text | sed '/^[[:space:]]*$/d')"
    if [[ -z "$text" ]]; then
        notify "OCR 未识别到文本"
        exit 1
    fi

    if has wl-copy; then
        printf '%s\n' "$text" | wl-copy
    fi
    notify "OCR 文本已复制"
}

pick_color() {
    local output color rc

    if ! has hyprpicker; then
        log "pick_color: hyprpicker not found"
        notify "未找到 hyprpicker"
        exit 1
    fi

    set +e
    output="$(hyprpicker -a -f hex -q 2>&1)"
    rc=$?
    set -e
    color="$(printf '%s\n' "$output" | extract_color)"
    if [[ $rc -eq 0 && -n "$color" ]]; then
        notify "颜色已复制: $color"
        return 0
    fi
    log "pick_color: hyprpicker failed rc=$rc output=${output//$'\n'/ }"
    exit 1
}

pick_color_raw() {
    local output color rc

    if ! has hyprpicker; then
        log "pick_color_raw: hyprpicker not found"
        notify "未找到 hyprpicker"
        exit 1
    fi

    log "pick_color_raw: using hyprpicker"
    set +e
    output="$(hyprpicker -f hex 2>&1)"
    rc=$?
    set -e

    log "pick_color_raw hyprpicker rc=$rc output: ${output//$'\n'/ }"
    color="$(printf '%s\n' "$output" | extract_color)"
    if [[ $rc -eq 0 && -n "$color" ]]; then
        log "pick_color_raw parsed: $color"
        printf '%s\n' "$color"
        return 0
    fi

    log "pick_color_raw: no color parsed"
    exit 1
}

open_color_page() {
    local color shell_path

    log "open_color_page: start"
    sleep "${QS_COLOR_PICK_DELAY:-0.45}"
    color="$(pick_color_raw)"
    shell_path="$HOME/.config/quickshell/color-viewer/shell.qml"
    log "open_color_page: launching detail for $color"

    sleep 0.1
    QS_PICKED_COLOR="$color" quickshell -p "$shell_path" >>"$log_file" 2>&1 &
    disown
}

latest_image() {
    local dir
    dir="$(save_dir)"
    find "$dir" /tmp -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) \
        -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-
}

sleep 0.15

case "$mode" in
    region-copy)
        geometry="$(pick_geometry off)"
        grim -g "$geometry" - | wl-copy
        notify "选区截图已复制到剪贴板"
        ;;
    fullscreen)
        path="$(capture_fullscreen_file)"
        copy_png_file "$path"
        notify "全屏截图已保存并复制: $path"
        ;;
    region-save)
        path="$(capture_region_file off)"
        if has wl-copy; then
            echo "file://$path" | wl-copy --type text/uri-list
        fi
        notify "截图已保存: $path"
        ;;
    region-edit)
        path="$(capture_region_file on)"
        markpix "$path"
        ;;
    region-pin)
        path="$(capture_region_file on)"
        qt-img-viewer -f "$path"
        ;;
    measure)
        measure_pixels
        ;;
    ocr)
        ocr_region
        ;;
    color)
        pick_color
        ;;
    color-raw)
        pick_color_raw
        ;;
    color-page)
        open_color_page
        ;;
    pin-latest)
        path="$(latest_image)"
        if [[ -z "$path" ]]; then
            notify "没有找到可贴图的图片"
            exit 1
        fi
        qt-img-viewer -f "$path"
        ;;
    window)
        niri msg action screenshot-window
        ;;
    scroll)
        wayscrollshot
        ;;
    open-dir)
        xdg-open "$(save_dir)"
        ;;
    *)
        printf 'Usage: %s {region-copy|fullscreen|region-save|region-edit|region-pin|measure|ocr|color|color-raw|color-page|pin-latest|window|scroll|open-dir}\n' "$0" >&2
        exit 2
        ;;
esac
