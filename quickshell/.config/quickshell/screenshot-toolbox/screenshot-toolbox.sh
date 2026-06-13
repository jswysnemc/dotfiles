#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
log_file="${XDG_RUNTIME_DIR:-/tmp}/qs-screenshot-toolbox.log"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$script_dir/../scripts/lib/i18n.sh"

# 读取截图工具功能语言包中的字面量
i18n() {
    qs_i18n_literal "screenshot-toolbox" "$1"
}

has() {
    command -v "$1" >/dev/null 2>&1
}

log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*" >>"$log_file"
}

notify() {
    if has notify-send; then
        notify-send "$(i18n "截图工具")" "$1"
    fi
}

require_cmd() {
    if ! has "$1"; then
        notify "$(i18n "未找到") $1"
        exit 1
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

preview_dir() {
    local dir="${XDG_RUNTIME_DIR:-/tmp}/qs-screenshot-previews"
    mkdir -p "$dir"
    printf '%s\n' "$dir"
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

    # 1. 等待选区叠层退出当前帧，避免把 slurp 边框截进图片
    sleep 0.08

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
    local output="${1:-}"
    local path

    path="$(new_path)"
    if [[ -n "$output" ]]; then
        grim -o "$output" "$path"
    else
        grim "$path"
    fi
    printf '%s\n' "$path"
}

make_preview() {
    local output="${1:-}"
    local target="$2"
    local raw="${target%.png}.raw.png"

    if [[ -n "$output" ]]; then
        grim -o "$output" "$raw"
    else
        grim "$raw"
    fi

    if has magick; then
        magick "$raw" -thumbnail 220x110^ -gravity center -extent 220x110 "$target"
        rm -f "$raw"
    else
        mv "$raw" "$target"
    fi
}

make_preview_from_raw() {
    local raw="$1"
    local geometry="$2"
    local target="$3"

    if [[ -n "$geometry" ]]; then
        magick "$raw" -crop "$geometry" +repage -thumbnail 220x110^ -gravity center -extent 220x110 "$target"
    else
        magick "$raw" -thumbnail 220x110^ -gravity center -extent 220x110 "$target"
    fi
}

json_string() {
    jq -Rn --arg v "$1" '$v'
}

preview_json() {
    require_cmd grim
    require_cmd jq

    local dir raw all_path outputs_json scale
    dir="$(preview_dir)"
    rm -f "$dir"/*.png 2>/dev/null || true

    outputs_json="$(niri msg --json outputs)"
    all_path="$dir/all.png"
    scale="${QS_SCREEN_PREVIEW_SCALE:-0.2}"

    if has magick; then
        raw="$dir/raw.png"
        grim -s "$scale" "$raw"
        make_preview_from_raw "$raw" "" "$all_path"

        while IFS=$'\t' read -r name x y width height; do
            [[ -z "$name" ]] && continue
            local safe path geometry
            safe="$(printf '%s' "$name" | tr -c 'A-Za-z0-9_.-' '_')"
            path="$dir/$safe.png"
            geometry="$(awk -v s="$scale" -v x="$x" -v y="$y" -v w="$width" -v h="$height" 'BEGIN { printf "%dx%d+%d+%d", int(w*s + 0.5), int(h*s + 0.5), int(x*s + 0.5), int(y*s + 0.5) }')"
            make_preview_from_raw "$raw" "$geometry" "$path"
        done < <(printf '%s\n' "$outputs_json" | jq -r '.[] | [.name, .logical.x, .logical.y, .logical.width, .logical.height] | @tsv')

        rm -f "$raw"
    else
        make_preview "" "$all_path"
        while IFS= read -r name; do
            [[ -z "$name" ]] && continue
            local safe path
            safe="$(printf '%s' "$name" | tr -c 'A-Za-z0-9_.-' '_')"
            path="$dir/$safe.png"
            make_preview "$name" "$path"
        done < <(printf '%s\n' "$outputs_json" | jq -r '.[].name')
    fi

    printf '['
    printf '{"mode":"fullscreen","output":"","title":%s,"desc":%s,"preview":%s}' \
        "$(json_string "$(i18n "全部屏幕")")" \
        "$(json_string "$(i18n "按逻辑布局拼接")")" \
        "$(json_string "$all_path")"

    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        local safe path
        safe="$(printf '%s' "$name" | tr -c 'A-Za-z0-9_.-' '_')"
        path="$dir/$safe.png"
        printf ',{"mode":"fullscreen-output","output":%s,"title":%s,"desc":%s,"preview":%s}' \
            "$(json_string "$name")" \
            "$(json_string "$name")" \
            "$(json_string "$(i18n "只截取这个显示器")")" \
            "$(json_string "$path")"
    done < <(printf '%s\n' "$outputs_json" | jq -r '.[].name')

    printf ']\n'
}

pick_window_id() {
    local picked id rc

    require_cmd jq

    set +e
    picked="$(niri msg -j pick-window)"
    rc=$?
    set -e

    if [[ $rc -ne 0 || -z "${picked// /}" ]]; then
        exit 130
    fi

    id="$(printf '%s\n' "$picked" | jq -r '.id // empty')"
    if [[ -z "$id" ]]; then
        notify "$(i18n "未选择窗口")"
        exit 1
    fi

    printf '%s\n' "$id"
}

capture_picked_window() {
    local id

    id="$(pick_window_id)"
    niri msg action screenshot-window --id "$id"
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
    notify "$(i18n "像素测量: ")$result"
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
        notify "$(i18n "未找到") tesseract"
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
        notify "$(i18n "OCR 识别失败")"
        exit 1
    fi

    text="$(printf '%s\n' "$text" | normalize_ocr_text | sed '/^[[:space:]]*$/d')"
    if [[ -z "$text" ]]; then
        notify "$(i18n "OCR 未识别到文本")"
        exit 1
    fi

    if has wl-copy; then
        printf '%s\n' "$text" | wl-copy
    fi
    notify "$(i18n "OCR 文本已复制")"
}

pick_color() {
    local output color rc

    if ! has hyprpicker; then
        log "pick_color: hyprpicker not found"
        notify "$(i18n "未找到") hyprpicker"
        exit 1
    fi

    set +e
    output="$(hyprpicker -a -f hex -q 2>&1)"
    rc=$?
    set -e
    color="$(printf '%s\n' "$output" | extract_color)"
    if [[ $rc -eq 0 && -n "$color" ]]; then
        notify "$(i18n "颜色已复制: ")$color"
        return 0
    fi
    log "pick_color: hyprpicker failed rc=$rc output=${output//$'\n'/ }"
    exit 1
}

pick_color_raw() {
    local output color rc

    if ! has hyprpicker; then
        log "pick_color_raw: hyprpicker not found"
        notify "$(i18n "未找到") hyprpicker"
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

preprocess_qr_image() {
    local input="$1"
    local output="$2"

    if ! has magick; then
        cp "$input" "$output"
        return 0
    fi

    magick "$input" \
        -alpha remove -background white -alpha off \
        -colorspace Gray \
        -filter Point -resize "${QR_SCALE:-300}%" \
        -auto-level \
        "$output"
}

decode_qr_image() {
    local path="$1"
    local processed_path output rc

    if ! has zbarimg; then
        notify "$(i18n "未找到") zbarimg"
        exit 1
    fi

    set +e
    output="$(zbarimg --quiet --raw "$path" 2>>"$log_file")"
    rc=$?
    set -e

    if [[ $rc -eq 0 && -n "${output//[[:space:]]/}" ]]; then
        printf '%s\n' "$output"
        return 0
    fi

    processed_path="${XDG_RUNTIME_DIR:-/tmp}/qs-qr-processed-$(date +%s%N).png"
    preprocess_qr_image "$path" "$processed_path"

    set +e
    output="$(zbarimg --quiet --raw "$processed_path" 2>>"$log_file")"
    rc=$?
    set -e
    rm -f "$processed_path"

    if [[ $rc -eq 0 && -n "${output//[[:space:]]/}" ]]; then
        printf '%s\n' "$output"
        return 0
    fi

    log "decode_qr_image: failed rc=$rc path=$path"
    notify "$(i18n "未识别到二维码")"
    exit 1
}

open_qr_page() {
    local geometry path text shell_path

    log "open_qr_page: start"
    geometry="$(pick_geometry on)"
    path="${XDG_RUNTIME_DIR:-/tmp}/qs-qr-raw-$(date +%s%N).png"
    grim -g "$geometry" "$path"
    text="$(decode_qr_image "$path")"
    shell_path="$HOME/.config/quickshell/qr-viewer/shell.qml"
    log "open_qr_page: decoded ${#text} bytes"

    if [[ "${QR_KEEP_IMAGE:-0}" != "1" ]]; then
        rm -f "$path"
    else
        log "open_qr_page: kept image $path"
    fi

    QS_QR_TEXT="$text" quickshell -p "$shell_path" >>"$log_file" 2>&1 &
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
        notify "$(i18n "选区截图已复制到剪贴板")"
        ;;
    fullscreen)
        path="$(capture_fullscreen_file)"
        copy_png_file "$path"
        notify "$(i18n "全屏截图已保存并复制: ")$path"
        ;;
    fullscreen-output)
        output="${2:-}"
        if [[ -z "$output" ]]; then
            notify "$(i18n "未指定显示器")"
            exit 1
        fi
        path="$(capture_fullscreen_file "$output")"
        copy_png_file "$path"
        notify "$(i18n "显示器截图已保存并复制: ")$output -> $path"
        ;;
    preview-json)
        preview_json
        ;;
    region-save)
        path="$(capture_region_file off)"
        if has wl-copy; then
            echo "file://$path" | wl-copy --type text/uri-list
        fi
        notify "$(i18n "截图已保存: ")$path"
        ;;
    region-edit)
        path="$(capture_region_file on)"
        markpix "$path"
        ;;
    region-annotate)
        require_cmd mark-shot
        mark-shot
        ;;
    fullscreen-annotate)
        require_cmd mark-shot
        mark-shot --fullscreen
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
    qr-page)
        open_qr_page
        ;;
    pin-latest)
        path="$(latest_image)"
        if [[ -z "$path" ]]; then
            notify "$(i18n "没有找到可贴图的图片")"
            exit 1
        fi
        qt-img-viewer -f "$path"
        ;;
    window)
        capture_picked_window
        ;;
    scroll)
        wayscrollshot
        ;;
    open-dir)
        xdg-open "$(save_dir)"
        ;;
    *)
        printf 'Usage: %s {region-copy|fullscreen|fullscreen-output OUTPUT|preview-json|region-save|region-edit|region-annotate|fullscreen-annotate|region-pin|measure|ocr|color|color-raw|color-page|qr-page|pin-latest|window|scroll|open-dir}\n' "$0" >&2
        exit 2
        ;;
esac
