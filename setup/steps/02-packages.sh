# shellcheck shell=bash

install_packages() {
    section "Phase 4" "Install Packages"

    local total=${#PKG_GROUP_NAMES[@]}
    local current=0
    local failed=0

    echo -e "   Installing ${WHITE}$total${NC} package groups..."
    echo ""

    for group_info in "${PKG_GROUP_NAMES[@]}"; do
        IFS=':' read -r key name <<< "$group_info"
        current=$((current + 1))
        local packages="${PKG_GROUPS[$key]}"

        if [[ -z "$packages" ]]; then
            continue
        fi

        # Check if already done
        if is_done "pkg_$key"; then
            echo -e "   ${GREEN}[${current}/${total}]${NC} $name ${DIM}(done)${NC}"
            continue
        fi

        echo -e "   ${CYAN}[${current}/${total}]${NC} $name"
        echo -e "         ${DIM}$packages${NC}"

        # Spinner
        local spin_pid
        (
            local i=0
            local chars='|/-\'
            while true; do
                printf "\r         \033[0;33m[%c]\033[0m Installing..." "${chars:$i:1}"
                i=$(( (i + 1) % 4 ))
                sleep 0.12
            done
        ) &
        spin_pid=$!

        local result=0
        if $AUR_HELPER -S --needed --noconfirm $packages >> "$LOG_FILE" 2>&1; then
            result=0
        else
            result=1
        fi

        kill "$spin_pid" 2>/dev/null
        wait "$spin_pid" 2>/dev/null || true

        if [[ $result -eq 0 ]]; then
            printf "\r         ${GREEN}[OK]${NC} Done            \n"
            mark_done "pkg_$key"
        else
            printf "\r         ${RED}[FAIL]${NC} Error          \n"
            failed=$((failed + 1))
        fi
    done

    echo ""
    if [[ $failed -gt 0 ]]; then
        print_warn "$failed group(s) had errors (check log)"
    else
        print_ok "All core packages installed"
    fi

    # AUR packages
    section "Phase 4b" "AUR Packages"

    if is_done "aur_packages"; then
        print_skip "AUR packages (already done)"
    else
        echo -e "   ${DIM}${AUR_PACKAGES[*]}${NC}"
        echo ""
        print_info "AUR packages may prompt for provider selection"

        # Install AUR packages interactively (without --noconfirm)
        if $AUR_HELPER -S --needed --skipreview ${AUR_PACKAGES[*]} < /dev/tty; then
            mark_done "aur_packages"
        else
            print_warn "Some AUR packages failed"
        fi
    fi

    # Optional packages
    if ! $INSTALL_MINIMAL; then
        section "Phase 4c" "Optional Packages"

        for opt_info in "${OPTIONAL_GROUPS[@]}"; do
            IFS=':' read -r key name packages <<< "$opt_info"

            if is_done "opt_$key"; then
                echo -e "   ${GREEN}[OK]${NC} $name ${DIM}(done)${NC}"
                continue
            fi

            echo ""
            if confirm "Install $name?"; then
                echo -e "      ${DIM}$packages${NC}"

                local spin_pid
                (
                    local i=0
                    local chars='|/-\'
                    while true; do
                        printf "\r      \033[0;33m[%c]\033[0m Installing..." "${chars:$i:1}"
                        i=$(( (i + 1) % 4 ))
                        sleep 0.12
                    done
                ) &
                spin_pid=$!

                local result=0
                if $AUR_HELPER -S --needed --noconfirm $packages >> "$LOG_FILE" 2>&1; then
                    result=0
                else
                    result=1
                fi

                kill "$spin_pid" 2>/dev/null
                wait "$spin_pid" 2>/dev/null || true

                if [[ $result -eq 0 ]]; then
                    printf "\r      ${GREEN}[OK]${NC} Installed       \n"
                    mark_done "opt_$key"
                else
                    printf "\r      ${RED}[FAIL]${NC} Error          \n"
                fi
            fi
        done
    fi

    log "Packages installed"
}
