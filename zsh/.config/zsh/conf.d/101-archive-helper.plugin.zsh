
# ark - Zsh Archive Helper
# A simple helper function to show compression/decompression commands without executing them.

function arkh() {
    # --- Color Definitions ---
    local c_reset="\e[0m"
    local c_bold="\e[1m"
    local c_cmd="\e[36m" # Cyan for commands
    local c_file="\e[33m" # Yellow for filenames
    local c_info="\e[32m" # Green for info
    local c_error="\e[31m" # Red for errors

    # --- Help Message ---
    if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        echo -e "${c_bold}Ark - Zsh Archive Helper${c_reset}"
        echo -e "Shows you the command to compress or decompress files."
        echo
        echo -e "${c_bold}USAGE:${c_reset}"
        echo -e "  arkh ${c_info}<action>${c_reset} ${c_file}<archive_name>${c_reset} [files_to_add...]"
        echo
        echo -e "${c_bold}ACTIONS:${c_reset}"
        echo -e "  ${c_info}c, create${c_reset}    Show command to CREATE an archive."
        echo -e "  ${c_info}x, extract${c_reset}   Show command to EXTRACT an archive."
        echo
        echo -e "${c_bold}EXAMPLES:${c_reset}"
        echo -e "  arkh c my_stuff.tar.gz file1.txt documents/"
        echo -e "  arkh x my_stuff.tar.gz"
        echo -e "  arkh x old_photos.zip"
        return 0
    fi

    local action=$1
    shift
    local archive_name=$1
    local cmd_string=""

    case "$action" in
        c|create)
            if [[ $# -lt 2 ]]; then
                echo -e "${c_error}Error: 'create' action requires an archive name and at least one file to add.${c_reset}"
                return 1
            fi
            
            shift
            local files_to_add=("${@}")

            echo -e "To ${c_bold}CREATE${c_reset} archive ${c_file}${archive_name}${c_reset} with your files:"
            
            case "$archive_name" in
                *.tar.gz|*.tgz)      cmd_string="tar -czvf ${c_file}${archive_name}${c_reset} ${files_to_add[@]}" ;;
                *.tar.bz2|*.tbz2)   cmd_string="tar -cjvf ${c_file}${archive_name}${c_reset} ${files_to_add[@]}" ;;
                *.tar.xz|*.txz)     cmd_string="tar -cJvf ${c_file}${archive_name}${c_reset} ${files_to_add[@]}" ;;
                *.zip)              cmd_string="zip -r ${c_file}${archive_name}${c_reset} ${files_to_add[@]}" ;;
                *.rar)              cmd_string="rar a ${c_file}${archive_name}${c_reset} ${files_to_add[@]}" ;;
                *.7z)               cmd_string="7z a ${c_file}${archive_name}${c_reset} ${files_to_add[@]}" ;;
                *.tar)              cmd_string="tar -cvf ${c_file}${archive_name}${c_reset} ${files_to_add[@]}" ;;
                *)
                    echo -e "${c_error}Unsupported archive format for creation: '$archive_name'${c_reset}"
                    return 1
                    ;;
            esac
            ;;

        x|extract)
            if [[ $# -ne 1 ]]; then
                echo -e "${c_error}Error: 'extract' action requires exactly one archive name.${c_reset}"
                return 1
            fi

            echo -e "To ${c_bold}EXTRACT${c_reset} archive ${c_file}${archive_name}${c_reset}:"

            case "$archive_name" in
                *.tar.gz|*.tgz)      cmd_string="tar -xzvf ${c_file}${archive_name}${c_reset}" ;;
                *.tar.bz2|*.tbz2)   cmd_string="tar -xjvf ${c_file}${archive_name}${c_reset}" ;;
                *.tar.xz|*.txz)     cmd_string="tar -xJvf ${c_file}${archive_name}${c_reset}" ;;
                *.zip)              cmd_string="unzip ${c_file}${archive_name}${c_reset}" ;;
                *.rar)              cmd_string="unrar x ${c_file}${archive_name}${c_reset}" ;;
                *.7z)               cmd_string="7z x ${c_file}${archive_name}${c_reset}" ;;
                *.tar)              cmd_string="tar -xvf ${c_file}${archive_name}${c_reset}" ;;
                *.gz)               cmd_string="gunzip ${c_file}${archive_name}${c_reset}" ;;
                *.bz2)              cmd_string="bunzip2 ${c_file}${archive_name}${c_reset}" ;;
                *.xz)               cmd_string="unxz ${c_file}${archive_name}${c_reset}" ;;
                *)
                    echo -e "${c_error}Unsupported archive format for extraction: '$archive_name'${c_reset}"
                    return 1
                    ;;
            esac
            ;;

        *)
            echo -e "${c_error}Error: Unknown action '$action'. Use 'c' (create) or 'x' (extract).${c_reset}"
            return 1
            ;;
    esac

    # Print the final command
    echo
    echo -e "  ${c_cmd}${cmd_string}${c_reset}"
    echo
}
