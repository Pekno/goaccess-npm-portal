#!/bin/bash
function npm_init(){
    goan_config="/goaccess-config/${2}/goaccess.conf"
    nginx_html="/var/www/html/${2}/index.html"
    html_config="/var/www/html/${2}/goaccess_conf.html"
    archive_log="/goaccess-config/${2}/archive.log"
    active_log="/goaccess-config/${2}/active.log"
    nginx_server_config="/etc/nginx/vdomains/server_${2}.conf"
    nginx_websocket_config="/etc/nginx/vdomains/websocket_${2}.conf"

    if [[ -f ${goan_config} ]]; then
        rm ${goan_config}
    else
        mkdir -p "/goaccess-config/${2}/"
        cp /goaccess-config/goaccess.conf.bak ${goan_config}
    fi
    if [[ -f ${nginx_html} ]]; then
        rm ${nginx_html}
    else
        mkdir -p "/var/www/html/${2}/"
        touch ${nginx_html}
    fi
    if [[ -f ${html_config} ]]; then
        rm ${html_config}
    fi
    if [[ -f ${nginx_server_config} ]]; then
        rm ${nginx_server_config}
    else
        mkdir -p "/etc/nginx/vdomains/"
        touch ${nginx_server_config}
    fi
        if [[ -f ${nginx_websocket_config} ]]; then
        rm ${nginx_websocket_config}
    else
        mkdir -p "/etc/nginx/vdomains/"
        touch ${nginx_websocket_config}
    fi

    echo -n "" > ${archive_log}
    echo -n "" > ${active_log}
}

function npm_goaccess_config(){
    echo -e "\n\n\n" >> ${goan_config}
    echo "######################################" >> ${goan_config}
    echo "# ${goan_version}" >> ${goan_config}
    echo "# GOAN_NPM_PROXY_CONFIG_FOR_${2}" >> ${goan_config}
    echo "######################################" >> ${goan_config}
    echo "time-format %T" >> ${goan_config}
    echo "date-format %d/%b/%Y" >> ${goan_config}
    echo "log_format [%d:%t %^] %^ %^ %s - %m %^ %v \"%U\" [Client %h] [Length %b] [Gzip %^] [Sent-to %^] \"%u\" \"%R\"" >> ${goan_config}
    echo "port ${3}" >> ${goan_config}
    echo "real-time-html true" >> ${goan_config}
    echo "output ${nginx_html}" >> ${goan_config}
    if [[ "${ENABLE_BROWSERS_LIST}" == "True" || ${ENABLE_BROWSERS_LIST} == true ]]; then
        echo -e "\n\tENABLING NPM INSTANCE GOACCESS BROWSERS LIST"
        browsers_file="/goaccess-config/browsers.list"
        echo "browsers-file ${browsers_file}" >> ${goan_config}
    fi
}

function nginx_server_config(){
    echo -e "\n\n\n" >> ${nginx_websocket_config}
    echo "######################################" >> ${nginx_websocket_config}
    echo "# nginx_server_config_FOR_${2}" >> ${nginx_websocket_config}
    echo "######################################" >> ${nginx_websocket_config}

    echo "map \$http_upgrade \$goaccess_${2} {" >> ${nginx_websocket_config}
    echo -e "\twebsocket \"socket_${2}\";" >> ${nginx_websocket_config}
    echo -e "\tdefault \"web\";" >> ${nginx_websocket_config}
    echo "}" >> ${nginx_websocket_config}

    echo -e "\n\n\n" >> ${nginx_server_config}
    echo "######################################" >> ${nginx_server_config}
    echo "# nginx_server_config_FOR_${2}" >> ${nginx_server_config}
    echo "######################################" >> ${nginx_server_config}

    echo "location /${2} {" >> ${nginx_server_config}
    echo -e "\t#goan_authbasic" >> ${nginx_server_config}
    echo -e "\ttry_files /nonexistent @\$goaccess_${2};" >> ${nginx_server_config}
    echo "}" >> ${nginx_server_config}
    echo -e "\n" >> ${nginx_server_config}

    echo "location @socket_${2} {" >> ${nginx_server_config}
    echo -e "\tproxy_pass http://localhost:${3};" >> ${nginx_server_config}
    echo -e "\tproxy_connect_timeout 1d;" >> ${nginx_server_config}
    echo -e "\tproxy_send_timeout 1d;" >> ${nginx_server_config}
    echo -e "\tproxy_read_timeout 1d;" >> ${nginx_server_config}
    echo -e "\tproxy_http_version 1.1;" >> ${nginx_server_config}
    echo -e "\tproxy_set_header Upgrade \$http_upgrade;" >> ${nginx_server_config}
    echo -e "\tproxy_set_header Connection \"Upgrade\";" >> ${nginx_server_config}
    echo "}" >> ${nginx_server_config}

}

function npm(){
    npm_init $1 $2 $3
    npm_goaccess_config $1 $2 $3
    nginx_server_config $1 $2 $3

    echo -e "\nLOADING NPM PROXY LOGS FOR ${2} ON PORT ${3}"
    echo "-------------------------------"

    echo $'\n' >> ${goan_config}
    echo "#GOAN_NPM_LOG_FILES_FOR_${2}" >> ${goan_config}
    echo "log-file ${archive_log}" >> ${goan_config}
    echo "log-file ${active_log}" >> ${goan_config}

    goan_log_count=0
    goan_archive_log_count=0

    echo -e "\n#GOAN_NPM_PROXY_FILES_FOR_${2}" >> ${goan_config}
    if [[ -d "${goan_log_path}" ]]; then

        echo -e "\n\tAdding proxy logs..."
        IFS=$'\n'
        for file in $(find "${goan_log_path}" -name "proxy*host-${1}_access.log" ! -name "*_error.log");
        do
            checkFile "$file"
            if [ $? -eq 0 ]; then
                echo "log-file ${file}" >> ${goan_config}
                ((goan_log_count++))
            fi
        done
        unset IFS

        echo -e "\tFound (${goan_log_count}) proxy logs for ${2}..."
        echo -e "\n\tSKIP ARCHIVED LOGS"
        echo -e "\t-------------------------------"
        if [[ "${SKIP_ARCHIVED_LOGS}" == "True" || ${SKIP_ARCHIVED_LOGS} == true ]]
        then
            echo -e "\tTRUE"
        else
            echo -e "\tFALSE"
            goan_archive_log_count=`ls -1 ${goan_log_path}/proxy-host-${1}_access.log*.gz 2> /dev/null | wc -l`
            goan_archive_detail_log_count=0

            if [ $goan_archive_log_count != 0 ]
            then
                echo -e "\n\tAdding proxy archive logs..."

                IFS=$'\n'
                for file in $(find "${goan_log_path}" -name "proxy-host-${1}_access.log*.gz" ! -name "*_error.log");
                do
                    checkFile "$file"
                    if [ $? -eq 0 ]; then
                        cleanFileName="${file//.gz/}"
                        cleanFileName="${cleanFileName//\/opt\/log/}"
                        cleanFileName="/goaccess-logs/archives${cleanFileName}"

                        zcat -f ${file} > ${cleanFileName}
                        echo "log-file ${cleanFileName}" >> ${goan_config}
                        ((goan_archive_detail_log_count++))
                    fi
                done
                unset IFS

                echo -e "\n\tAdded (${goan_archive_detail_log_count}) proxy archived logs from ${goan_log_path}..."

            else
                echo -e "\n\tNo archived logs found at ${goan_log_path}..."
            fi
        fi

    else
        echo "Problem loading directory (check directory or permissions)... ${goan_log_path}"
    fi

    #additonal config settings
    exclude_ips             ${goan_config}
    set_geoip_database      ${goan_config}
    debug                   ${goan_config} ${html_config}

    #write out loading page
    echo "<!doctype html><html><head>" > ${nginx_html}
    echo "<title>GOAN - ${goan_version}</title>" >> ${nginx_html}
    echo "<meta http-equiv=\"refresh\" content=\"1\" >" >> ${nginx_html}
    echo "<style>body {font-family: Arial, sans-serif;}</style>" >> ${nginx_html}
    echo "</head><body><p><b>${goan_version}</b><br/><br/>loading... <br/><br/>" >> ${nginx_html}
    echo "Logs processing for ${2}: $(($goan_log_count + $goan_archive_log_count)) (might take some time depending on the number of files to parse)" >> ${nginx_html}
    echo "<br/></p></body></html>" >> ${nginx_html}

    echo -e "\nRUN NPM GOACCESS"
    runGoAccess
}
