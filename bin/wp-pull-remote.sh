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


db_update_domain_wp_blogs() {
    headerone 'DEST_HOST: Updating domain in wp_blogs table'
    pushd ${DEST_WP_DIR} >/dev/null
    if ! wp db query "SHOW CREATE TABLE wp_blogs" &>/dev/null
    then
        echo 'Table wp_blogs does not exist. Skipping.'
        echo
        popd >/dev/null
        return
    fi
    wp db query "
        SELECT domain AS 'domain__contains__DEST_DOMAIN'
        FROM wp_blogs
        WHERE domain LIKE '%${SOURCE_DOMAIN}%';" \
        | column -t
    echo
    wp db query "
        UPDATE wp_blogs
        SET domain = REPLACE(domain, '${SOURCE_DOMAIN}', '${DEST_DOMAIN}');"
    wp db query "
        SELECT domain AS 'domain__contains__DEST_DOMAIN'
        FROM wp_blogs
        WHERE domain LIKE '%${DEST_DOMAIN}%';" \
        | column -t
    echo
    popd >/dev/null
}


db_update_domain_wp_domain_mapping() {
    headerone 'DEST_HOST: Updating domain in wp_domain_mapping table'
    pushd ${DEST_WP_DIR} >/dev/null
    if ! wp db query "SHOW CREATE TABLE wp_domain_mapping" &>/dev/null
    then
        echo 'Table wp_domain_mapping does not exist. Skipping.'
        echo
        popd >/dev/null
        return
    fi
    wp db query "
        SELECT domain AS 'domain__contains__SOURCE_DOMAIN'
        FROM wp_domain_mapping
        WHERE domain LIKE '%${SOURCE_DOMAIN}%';" \
        | column -t
    echo
    wp db query "
        UPDATE wp_domain_mapping
        SET domain = REPLACE(domain, '${SOURCE_DOMAIN}', '${DEST_DOMAIN}');"
    wp db query "
        SELECT domain AS 'domain__contains__DEST_DOMAIN'
        FROM wp_domain_mapping
        WHERE domain LIKE '%${DEST_DOMAIN}%';" \
        | column -t
    echo
    popd >/dev/null
}


db_update_domain_wp_options() {
    headerone 'DEST_HOST: Updating DOMAIN in wp_options table'
    pushd ${DEST_WP_DIR} >/dev/null
    wp db query "
        SELECT option_name, option_value
        FROM wp_options
        WHERE option_name IN ('siteurl', 'home');" \
        | column -t
    echo
    # legacy_ccorgwp__stage
    # Strip 'blog.' from beginning of domain as that subdomain is now a
    # redirect
    local _source_domain="blog.${SOURCE_DOMAIN}"
    wp db query "
        UPDATE wp_options
        SET option_value = REPLACE(option_value, '${_source_domain}',
                                                 '${DEST_DOMAIN}')
        WHERE option_name IN ('siteurl', 'home');"
    wp db query "
        SELECT option_name, option_value
        FROM wp_options
        WHERE option_name IN ('siteurl', 'home');" \
        | column -t
    echo
    popd >/dev/null
}


db_update_domain_wp_posts() {
    headerone 'DEST_HOST: Updating DOMAIN in wp_posts table'
    pushd ${DEST_WP_DIR} >/dev/null
    wp db query "
        SELECT COUNT(*) AS 'post_content___containing__SOURCE_DOMAIN__count'
        FROM wp_posts
        WHERE post_content LIKE '%${SOURCE_DOMAIN}%';" \
        | column -t
    echo
    wp db query "
        UPDATE wp_posts
        SET post_content = REPLACE(post_content, '${SOURCE_DOMAIN}',
                                                 '${DEST_DOMAIN}');"
    wp db query "
        SELECT COUNT(*) AS 'post_content___containing__DEST_DOMAIN__count'
        FROM wp_posts
        WHERE post_content LIKE '%${DEST_DOMAIN}%';" \
        | column -t
    echo
    popd >/dev/null
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
    ssh -t -q ${SOURCE_HOST_REMOTE} '
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
    scp ${SOURCE_HOST_REMOTE}:${SOURCE_DB_FILE} \
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
    echo
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


#### MAIN #####################################################################

display_dest_host_info
display_source_host_info

# legacy_ccorgwp__stage
# Using named directories for legacy_ccorgwp__stage migration/sync
#create_temp_dir
TEMP_DIR=/var/www/creativecommons/backup/second-sync

# legacy_ccorgwp__stage
# To debug or update import process, comment out the next line and uncomment
pull_data
#PULLED_DB_FILE="${TEMP_DIR}/${SOURCE_DB_FILE##*/}"
#PULLED_UPLOADS_FILE="${TEMP_DIR}/${SOURCE_UPLOADS_FILE##*/}"

import_database
db_update_domain_wp_options

# legacy_ccorgwp__stage
# The source data does not include a wp_blogs or wp_domain_mapping table
#db_update_domain_wp_blogs
#db_update_domain_wp_domain_mapping

db_update_domain_wp_posts
replace_uploads_dir

# Preserve data
#remove_temp_dir
