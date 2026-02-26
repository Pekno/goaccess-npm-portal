#!/bin/bash
source $(dirname "$0")/funcs/internal.sh
source $(dirname "$0")/funcs/environment.sh
source $(dirname "$0")/logs/npm.sh

goan_version="GOAN v1.1.31"
goan_log_path="/opt/log"

goaccess_ping_interval=15
goaccess_debug_file=/goaccess-logs/goaccess.debug
goaccess_invalid_file=/goaccess-logs/goaccess.invalid
goaccess_port_start=7890

# Define the Web UI port, defaulting to 7880 if WEBUI_PORT is not set
WEBUI_PORT_ACTUAL=${WEBUI_PORT:-7880}
NGINX_ORIGINAL_CONF="/etc/nginx/nginx.conf"
NGINX_CUSTOM_CONF="/etc/nginx/nginx_custom.conf"

echo -e "\n${goan_version}\n"

### DASHBOARD MAPPING
echo -e "\nDASHBOARD MAPPING..."
declare -A dashboard_map
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
echo -e "Web UI will listen on internal port: ${WEBUI_PORT_ACTUAL}"

if [[ ! -d "/var/www/html" ]]; then
    mkdir -p /var/www/html
fi

# Prepare custom Nginx configuration
if [[ ! -f "$NGINX_ORIGINAL_CONF" ]]; then
    echo "Error: Original Nginx config $NGINX_ORIGINAL_CONF not found!"
    exit 1
fi
cp "$NGINX_ORIGINAL_CONF" "$NGINX_CUSTOM_CONF"
# Replace the listen port directive
sed -i "s/listen [0-9]\+ default_server;/listen ${WEBUI_PORT_ACTUAL} default_server;/g" "$NGINX_CUSTOM_CONF"
echo "Nginx configuration customized at $NGINX_CUSTOM_CONF"

### NGINX

nav_links_html_content=""
# BEGIN PROXY LOGS
echo -e "\n\nNPM INSTANCES SETTING UP..."
for key in "${!dashboard_map[@]}"; do
    port=$((goaccess_port_start++))
    # Ensure dashboard_map[$key] is not empty to avoid creating broken links or empty hrefs
    if [[ -n "${dashboard_map[$key]}" ]]; then
        nav_links_html_content+="<a href=\"/${dashboard_map[$key]}/\" target=\"_blank\" class=\"dashboard-link\"><span class=\"indicator\"></span>${dashboard_map[$key]}<span class=\"arrow\">&#9656;</span></a>"
        echo -e "\n\nSETTING UP ${dashboard_map[$key]}"
        npm "$key" "${dashboard_map[$key]}" "$port"
    else
        echo -e "\n\nWARNING: Empty value for key '$key' in DASHBOARD_MAP. Skipping link generation for this entry."
    fi
done
# END PROXY LOGS

landing_page="/var/www/html/index.html"
header_file="/var/www/html/header.html"

if [[ ! -f "$header_file" ]]; then
    echo "Error: $header_file not found. Make sure it's copied into the Docker image."
    exit 1
fi

# Generate the index.html file
(
  echo "<!DOCTYPE html>"
  echo "<html lang=\"en\">"
  cat "${header_file}"
  echo "<body>"
  echo "  <div class=\"container\">"
  echo "    <div class=\"page-header\">"
  echo "      <h1>GoAccess <span>Dashboards</span></h1>"
  echo "    </div>"
  echo "    <div class=\"panel\">"
  echo "      <div class=\"panel-header\"><h3>Proxy Hosts <span>${#dashboard_map[@]} dashboards</span></h3></div>"
  echo "      <div class=\"dashboard-grid\">"
  echo -e "${nav_links_html_content}"
  echo "      </div>"
  echo "    </div>"
  echo "  </div>"
  echo "</body>"
  echo "</html>"
) > "$landing_page"

echo "Landing page (re)generated at $landing_page using header file"

# Start Nginx with the custom configuration
echo "Starting Nginx..."
tini -s -- nginx -c "${NGINX_CUSTOM_CONF}"

#Leave container running
wait -n