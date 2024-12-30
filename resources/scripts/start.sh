#!/bin/bash
source $(dirname "$0")/funcs/internal.sh
source $(dirname "$0")/funcs/environment.sh
source $(dirname "$0")/logs/npm.sh
source $(dirname "$0")/logs/npm_redirection.sh
source $(dirname "$0")/logs/npm_error.sh

goan_version="GOAN v1.1.31"
goan_log_path="/opt/log"

goaccess_ping_interval=15
goaccess_debug_file=/goaccess-logs/goaccess.debug
goaccess_invalid_file=/goaccess-logs/goaccess.invalid
goaccess_port_start=7890

echo -e "\n${goan_version}\n"

### DASHBOARD MAPPING
echo -e "\nDASHBOARD MAPPING..."
if [[ -n "$DASHBOARD_MAP" ]]; then
    IFS=',' read -ra pairs <<< "$DASHBOARD_MAP"
    for pair in "${pairs[@]}"; do
        key=${pair%%=*}
        value=${pair#*=}
        value=$(echo "$value" | tr '[:upper:]' '[:lower:]')
        dashboard_map["$key"]="$value" 
        echo -e "FOUND ${key} - ${value}"
    done
else
    echo "Error: DASHBOARD_MAP is not set. Exiting."
    exit 1
fi

### DASHBOARD MAPPING

### NGINX
echo -e "\nNGINX SETUP..."

if [[ ! -d "/var/www/html" ]]; then
    mkdir /var/www/html
fi

### NGINX

nav_links=""
# BEGIN PROXY LOGS
echo -e "\n\nNPM INSTANCES SETTING UP..."
for key in "${!dashboard_map[@]}"; do
    port=$((goaccess_port_start++))
    nav_links+="<a href=\"/${dashboard_map[$key]}\" target=\"_blank\" class=\"links\">${dashboard_map[$key]}</a>"
    echo -e "\n\nSETTING UP ${dashboard_map[$key]}"
    npm $key "${dashboard_map[$key]}" $port
done
# END PROXY LOGS

landing_page="/var/www/html/index.html"
sed -i "/<div id=\"dashboard-links\">/a ${nav_links}" "$landing_page"

echo "Landing page updated with dashboard links at $landing_page"

tini -s -- nginx

#Leave container running
wait -n
