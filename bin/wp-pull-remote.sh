#!/bin/bash
#
# Creative Commons Site Reliability Engineering WordPress Data Pull
# Remote Script
#
# This script is installed and invoked by wp-pull.sh. It should *not* be
# invoked directly.
#
# For additional information, see:
#   https://github.com/creativecommons/sre-wp-pull
set -o errexit
set -o errtrace
set -o nounset

trap '_es=${?};
    printf "${0}: line ${LINENO}: \"${BASH_COMMAND}\"";
    printf " exited with a status of ${_es}\n";
    exit ${_es}' ERR

# Colors
DKG=$(printf '\e[90m')
INV=$(printf '\e[7m')
LTG=$(printf '\e[37m')
RED=$(printf '\e[91m')
RST=$(printf '\e[0m')
WHT=$(printf '\e[97m')
YLW=$(printf '\e[93m')


#### FUNCTIONS ################################################################


create_temp_dir() {
    headerone 'DEST_HOST: Creating temporary directory (TEMP_DIR)'
    TEMP_DIR=$(mktemp -d -p"${DEST_TEMP_DIR}")
    echo "${DKG}TEMP_DIR:${RST}            ${TEMP_DIR}"
    echo
}


display_dest_host_info() {
    headerone 'DEST_HOST: Info / Connection Validation'
    echo -n "${DKG}LABEL:${RST}               "
    if [[ -f /etc/salt/minion_id ]]
    then
        cat /etc/salt/minion_id
    else
        hostname -f
    fi
    echo -n "${DKG}SSH AGENT KEYS:${RST}      "
    ssh-add -L
    echo
}


display_source_host_info() {
    headerone 'SOURCE_HOST: Info / Connection Validation'
    echo -n "${DKG}LABEL:${RST}               "
    ssh -t -q -oProxyJump=${BASTION_HOST_REMOTE} ${SOURCE_HOST_REMOTE} '
        if [[ -f /etc/salt/minion_id ]]
        then
            cat /etc/salt/minion_id
        else
            hostname -f
        fi
        '
    echo
}


donezo() {
    echo "${DKG}... done.${RST}"
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


headerone() {
    printf '%s# %-77s%s' "${WHT}${INV}" "${1}" "${RST}"
    echo
}


headertwo() {
    printf '%s## %-76s%s' "${LTG}${INV}" "${1}" "${RST}"
    echo
}


import_database() {
    headerone "DEST_HOST: Importing database from PULLED_DB_FILE"
    echo "${DKG}PULLED_DB_FILE:${RST}      ${PULLED_DB_FILE}"
    pushd ${DEST_WP_DIR} >/dev/null
    echo 'Decompressing PULLED_DB_FILE to stdout and piping to wp db import'
    zcat ${TEMP_DIR}/${SOURCE_DB_FILE##*/} | wp db import -
    popd >/dev/null
    echo
}


pull_data() {
    headerone 'DEST_HOST: Pulling data from SOURCE_HOST_REMOTE'
    scp -oProxyJump=${BASTION_HOST_REMOTE} \
        ${SOURCE_HOST_REMOTE}:${SOURCE_DB_FILE} \
        ${SOURCE_HOST_REMOTE}:${SOURCE_UPLOADS_FILE} \
        ${TEMP_DIR}/
    PULLED_DB_FILE="${TEMP_DIR}/${SOURCE_DB_FILE##*/}"
    PULLED_UPLOADS_FILE="${TEMP_DIR}/${SOURCE_UPLOADS_FILE##*/}"
    echo
}


remove_temp_dir() {
    headerone 'DEST_HOST: Removing temporary directory (TEMP_DIR)'
    rm -rf "${TEMP_DIR}"
    donezo
}


replace_uploads_dir() {
    local _msg1 _msg2
    _msg1='DEST_HOST: Replacing DEST_UPLOADS_DIR with contents of'
    _msg2=' PULLED_UPLOADS_FILE'
    headerone "${_msg1}${_msg2}"
    echo "${DKG}PULLED_UPLOADS_FILE:${RST} ${PULLED_UPLOADS_FILE}"
    headertwo 'Removing old/existing upload data from DEST_UPLOADS_DIR'
    rm -rf "${DEST_UPLOADS_DIR}/"*
    donezo
    headertwo 'Extracting new upload data'
    tar -x -f "${PULLED_UPLOADS_FILE}" \
        --no-same-owner \
        --no-same-permissions \
        --directory="${DEST_UPLOADS_DIR}" \
        --strip-components=1
    donezo
    headertwo 'Correcting group ownership and permissions on new upload data'
    chgrp -R www-data "${DEST_UPLOADS_DIR}"/*
    find "${DEST_UPLOADS_DIR}"/* \( -type d -exec chmod 2775 {} + \) -o \
        \( -type f -exec chmod 0664 {} + \)
    donezo
}


update_urls_in_database() {
    headerone 'DEST_HOST: Updating URLs in database'
    echo "${DKG}SOURCE_URL:${RST}      ${SOURCE_URL}"
    echo "${DKG}DEST_URL:${RST}        ${DEST_URL}"
    echo
    pushd ${DEST_WP_DIR} >/dev/null
    headertwo 'Updating URLs in wp_options table'
    wp db query "
        UPDATE \`wp_options\`
        SET \`option_value\` = REPLACE( \`option_value\`, '${SOURCE_URL}',
                                                          '${DEST_URL}' )
        WHERE \`option_name\` IN ('siteurl', 'home')
        ;"
    donezo
    headertwo 'Updating URLs in wp_posts table'
    wp db query "
        UPDATE \`wp_posts\`
        SET \`post_content\` = REPLACE( \`post_content\`, '${SOURCE_URL}',
                                                          '${DEST_URL}' )
        ;"
    popd >/dev/null
    donezo
}


#### MAIN #####################################################################

display_dest_host_info
display_source_host_info
create_temp_dir
pull_data
import_database
update_urls_in_database
replace_uploads_dir
remove_temp_dir

exit
#### NOTES ####################################################################
# TODO: update for multisite. note query below:
cd /var/www/chapters/wp; wp db query 'SELECT * FROM wp_domain_mapping'
+----+---------+-----------------------------+--------+
| id | blog_id | domain                      | active |
+----+---------+-----------------------------+--------+
|  2 |       2 | au-beta.creativecommons.net |      1 |
|  3 |       3 | ca-beta.creativecommons.net |      1 |
|  4 |       4 | ke-beta.creativecommons.net |      1 |
|  5 |       5 | mx-beta.creativecommons.net |      1 |
|  6 |       6 | nl-beta.creativecommons.net |      1 |
+----+---------+-----------------------------+--------+
