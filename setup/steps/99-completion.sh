# shellcheck shell=bash

show_completion() {
    clear
    show_banner

    echo -e "${GREEN}+==============================================================+${NC}"
    echo -e "${GREEN}|              INSTALLATION COMPLETE                           |${NC}"
    echo -e "${GREEN}+==============================================================+${NC}"
    echo ""

    echo -e "   ${BOLD}Next Steps:${NC}"
    echo ""
    echo -e "   ${CYAN}1.${NC} Reboot the system"

    # Check if SDDM is enabled
    if systemctl is-enabled sddm &>/dev/null; then
        echo -e "   ${CYAN}2.${NC} SDDM will start automatically after reboot"
        echo -e "   ${CYAN}3.${NC} Set wallpaper:  ${YELLOW}matugen image /path/to/wallpaper.jpg${NC}"
        echo -e "   ${CYAN}4.${NC} Input method:   ${YELLOW}fcitx5-configtool${NC}"
    else
        echo -e "   ${CYAN}2.${NC} Login at TTY (no display manager configured)"
        echo -e "   ${CYAN}3.${NC} Start desktop:  ${YELLOW}niri-session${NC}"
        echo -e "   ${CYAN}4.${NC} Set wallpaper:  ${YELLOW}matugen image /path/to/wallpaper.jpg${NC}"
        echo -e "   ${CYAN}5.${NC} Input method:   ${YELLOW}fcitx5-configtool${NC}"
        echo ""
        echo -e "   ${DIM}Note: No SDDM/GDM configured. Login via TTY then run 'niri-session'${NC}"
    fi

    echo -e "   ${DIM}Log: $LOG_FILE${NC}"
    echo ""

    # Remove state file on success
    rm -f "$STATE_FILE"

    # Reboot countdown
    echo -e "${YELLOW}>>> System requires a REBOOT.${NC}"
    echo ""

    for i in {10..1}; do
        echo -ne "\r   ${DIM}Auto-rebooting in ${i}s... (Press 'n' to cancel)${NC}"

        if read -t 1 -n 1 input; then
            if [[ "$input" == "n" || "$input" == "N" ]]; then
                echo -e "\n\n   ${BLUE}>>> Reboot cancelled.${NC}"
                exit 0
            fi
        fi
    done

    echo -e "\n\n   ${GREEN}>>> Rebooting...${NC}"
    sudo systemctl reboot
}
