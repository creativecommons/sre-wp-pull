#!/bin/bash
set -o errexit
set -o errtrace
set -o nounset

trap '_es=${?};
    printf "${0}: line ${LINENO}: \"${BASH_COMMAND}\"";
    printf " exited with a status of ${_es}\n";
    exit ${_es}' ERR

USAGE="\
Creative Commons WordPress Data Pull (Destroys and replaces destination data)

Arguments:
    CONFIG_FILE

Configuration File Variables:
    DEST_HOST               Host on which to install WordPress data
    DEST_URL                Site URL of the desintation WordPress
    DEST_UPLOADS_DIR        Absolute path of WordPress uploads directory on
                            destination host (will be destroyed and replaced)
    DEST_WP_DIR             Absolute path of WordPress directory (where to run
                            WP-CLI from)
    BASTION_HOST_REMOTE     Bastion or Jump Host used to connect to
                            SOURCE_HOST_REMOTE
    SOURCE_HOST_REMOTE      Host to pull WordPress data from
    SOURCE_URL              Site URL of the source WordPress
    SOURCE_DB_FILE          Absolute path of the database file (.sql.gz)
    SOURCE_UPLOADS_FILE     Absolute path of the uploads file (.tgz)
"
# Colors
DKG=$(printf '\e[90m')
INV=$(printf '\e[7m')
LTG=$(printf '\e[37m')
RED=$(printf '\e[91m')
RST=$(printf '\e[0m')
WHT=$(printf '\e[97m')
YLW=$(printf '\e[93m')


#### FUNCTIONS ################################################################


confirm_with_random_number() {
    # Loop until user enters random number
    _rand=${RANDOM}${RANDOM}${RANDOM}
    _rand=${_rand:0:4}
    _msg="Type the number, ${_rand}, to continue: "
    _i=0
    while read -p "${_msg}" _confirm
    do
        [[ "${_confirm}" == "${_rand}" ]] && return 0
        (( _i > 1 )) && error_exit 'invalid confirmation number'
        _i=$(( ++_i ))
    done
}


create_dest_bin_dir () {
    headerone 'DEST_HOST: Ensuring ~/bin/ directory exists'
    ssh -q -t -F"${CONFIG_FILE}" wp-pull 'mkdir -p bin'
    donezo
}


display_summary_and_confirm(){
    local _confirm _msg _rand
    local -i _i
    headerone 'WordPress Data Pull Information'
    echo "${DKG}DEST_HOST:${RST}           ${DEST_HOST}"
    echo "${DKG}DEST_URL:${RST}            ${DEST_URL}"
    echo "${DKG}DEST_UPLOADS_DIR:${RST}    ${DEST_UPLOADS_DIR}"
    echo "${DKG}DEST_WP_DIR:${RST}         ${DEST_WP_DIR}"
    echo
    echo "${DKG}BASTION_HOST_REMOTE:${RST} ${BASTION_HOST_REMOTE}"
    echo
    echo "${DKG}SOURCE_HOST_REMOTE:${RST}  ${SOURCE_HOST_REMOTE}"
    echo "${DKG}SOURCE_URL:${RST}          ${SOURCE_URL}"
    echo "${DKG}SOURCE_DB_FILE:${RST}      ${SOURCE_DB_FILE}"
    echo "${DKG}SOURCE_UPLOADS_FILE:${RST} ${SOURCE_UPLOADS_FILE}"
    echo
    echo
    echo -n "${YLW}${INV}[!]${RST} ${YLW}Continuing will irrevocably destroy"
    echo ' the WordPress data on the source host!'
    echo -n '    Please review the information above to ensure it is correct.'
    echo "${RST}"
    echo
    #confirm_with_random_number
}


donezo() {
    echo "${DKG}...done.${RST}"
    echo
}


error_exit() {
    # Display error message and exit
    local _msg
    local -i _es
    _msg="${1}"
    _es="${2:-1}"
    echo -e "${RED}ERROR: ${_msg}${RST}" 1>&2
    exit "${_es}"
}


execute_remote_script() {
    headerone 'DEST_HOST: Executing remote script'
    echo
    ssh -q -t -F"${CONFIG_FILE}" wp-pull "
        export DEST_URL=\"${DEST_URL}\"
        export DEST_UPLOADS_DIR=\"${DEST_UPLOADS_DIR}\"
        export DEST_TEMP_DIR=\"${DEST_TEMP_DIR}\"
        export DEST_WP_DIR=\"${DEST_WP_DIR}\"
        export BASTION_HOST_REMOTE=\"${BASTION_HOST_REMOTE}\"
        export SOURCE_HOST_REMOTE=\"${SOURCE_HOST_REMOTE}\"
        export SOURCE_URL=\"${SOURCE_URL}\"
        export SOURCE_DB_FILE=\"${SOURCE_DB_FILE}\"
        export SOURCE_UPLOADS_FILE=\"${SOURCE_UPLOADS_FILE}\"
        bin/wp-pull-remote.sh
        "
}


extract_variables_from_config() {
    local _f="${CONFIG_FILE}"
    DEST_HOST="$(awk '/^# DEST_HOST:/ {print $3}' "${_f}")"
    DEST_URL="$(awk '/^# DEST_URL:/ {print $3}' "${_f}")"
    DEST_UPLOADS_DIR="$(awk '/^# DEST_UPLOADS_DIR:/ {print $3}' "${_f}")"
    DEST_UPLOADS_DIR="${DEST_UPLOADS_DIR%/}"
    DEST_TEMP_DIR="$(awk '/^# DEST_TEMP_DIR:/ {print $3}' "${_f}")"
    DEST_TEMP_DIR="${DEST_TEMP_DIR%/}"
    DEST_WP_DIR="$(awk '/^# DEST_WP_DIR:/ {print $3}' "${_f}")"
    DEST_WP_DIR="${DEST_WP_DIR%/}"
    BASTION_HOST_REMOTE="$(awk '/^# BASTION_HOST_REMOTE:/ {print $3}' "${_f}")"
    SOURCE_HOST_REMOTE="$(awk '/^# SOURCE_HOST_REMOTE:/ {print $3}' "${_f}")"
    SOURCE_URL="$(awk '/^# SOURCE_URL:/ {print $3}' "${_f}")"
    SOURCE_DB_FILE="$(awk '/^# SOURCE_DB_FILE:/ {print $3}' "${_f}")"
    SOURCE_UPLOADS_FILE="$(awk '/^# SOURCE_UPLOADS_FILE:/ {print $3}' "${_f}")"
}


headerone() {
    printf '%s# %-77s%s' "${WHT}${INV}" "${1}" "${RST}"
    echo
}


headertwo() {
    printf '%s## %-76s%s' "${LTG}${INV}" "${1}" "${RST}"
    echo
}


help_print() {
    # Print help/usage, then exit (incorrect usage should exit 2)
    local -i _es
    _es="${1:-0}"
    echo "${USAGE}"
    exit "${_es}"
}


upload_remote_script() {
    headerone 'DEST_HOST: Uploading remote script'
    scp -F"${CONFIG_FILE}" bin/wp-pull-remote.sh wp-pull:bin/
    echo
}


#### MAIN #####################################################################


#### Parse options
(( ${#} == 0 )) && help_print 2
CONFIG_FILE="${1}"
extract_variables_from_config
display_summary_and_confirm
create_dest_bin_dir
upload_remote_script
execute_remote_script
