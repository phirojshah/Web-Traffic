#!/bin/bash

# Display banner and credit
echo "
██╗    ██╗███████╗██████╗     ████████╗██████╗  █████╗ ███████╗███████╗██╗ ██████╗
██║    ██║██╔════╝██╔══██╗    ╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██╔════╝██║██╔════╝
██║ █╗ ██║█████╗  ██████╔╝       ██║   ██████╔╝███████║█████╗  █████╗  ██║██║     
██║███╗██║██╔══╝  ██╔══██╗       ██║   ██╔══██╗██╔══██║██╔══╝  ██╔══╝  ██║██║     
╚███╔███╔╝███████╗██████╔╝       ██║   ██║  ██║██║  ██║██║     ██║     ██║╚██████╗
 ╚══╝╚══╝ ╚══════╝╚═════╝        ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝     ╚═╝ ╚═════╝
                                                                                    
Created by: Phiroj Shah
Version: 1.0.0
"

# Configuration
SOCKS_PORT="9050"
CONTROL_PORT="9051"
CONTROL_PASSWORD="YOUR_PASSWORD"
DELAY=5

# User Agent list
USER_AGENTS=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15"
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)

# IP Check Services - multiple services to avoid rate limiting
IP_SERVICES=(
    "http://ifconfig.me/ip"
    "http://api.ipify.org"
    "http://icanhazip.com"
    "http://ident.me"
    "http://ipecho.net/plain"
)

# Check if domain is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <domain>"
    echo "Example: $0 example.com"
    exit 1
fi

DOMAIN="$1"
TEMP_PATHS_FILE="/tmp/discovered_paths.txt"

# Function to check current IP using multiple services
get_current_ip() {
    local ip=""
    for service in "${IP_SERVICES[@]}"; do
        ip=$(curl --socks5-hostname 127.0.0.1:$SOCKS_PORT -s "$service")
        if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return 0
        fi
        sleep 1
    done
    echo "Failed to get IP"
    return 1
}

# Function to check Tor connection
check_tor() {
    if ! nc -z 127.0.0.1 $SOCKS_PORT 2>/dev/null; then
        echo "Error: Tor SOCKS proxy is not running on port $SOCKS_PORT"
        exit 1
    fi
    if ! nc -z 127.0.0.1 $CONTROL_PORT 2>/dev/null; then
        echo "Error: Tor control port is not accessible on port $CONTROL_PORT"
        exit 1
    fi
}

# Function to verify Tor authentication
verify_tor_auth() {
    echo "Verifying Tor control port authentication..."
    if ! echo -e "AUTHENTICATE \"$CONTROL_PASSWORD\"\r\nQUIT" | nc 127.0.0.1 $CONTROL_PORT 2>/dev/null | grep -q "250 OK"; then
        echo "Error: Tor authentication failed. Please check your control port password."
        echo "To fix this:"
        echo "1. Generate a new password hash: tor --hash-password \"your_password\""
        echo "2. Add to /etc/tor/torrc:"
        echo "   ControlPort 9051"
        echo "   HashedControlPassword your_generated_hash"
        echo "3. Restart Tor: sudo service tor restart"
        exit 1
    fi
    echo "Tor authentication successful!"
}

# Function to get a new IP address via Tor
renew_tor_ip() {
    local old_ip=$(get_current_ip)
    echo "Current IP: $old_ip"
    echo "Sending NEWNYM signal to Tor to get a new IP address..."
    
    if echo -e "AUTHENTICATE \"$CONTROL_PASSWORD\"\r\nSIGNAL NEWNYM\r\nQUIT" | nc 127.0.0.1 $CONTROL_PORT 2>/dev/null | grep -q "250 OK"; then
        sleep 2  # Give Tor time to establish new circuit
        local new_ip=$(get_current_ip)
        local attempts=0
        
        # Keep trying until IP actually changes or max attempts reached
        while [ "$old_ip" == "$new_ip" ] && [ $attempts -lt 5 ]; do
            sleep 1
            new_ip=$(get_current_ip)
            attempts=$((attempts + 1))
        done
        
        if [ "$old_ip" != "$new_ip" ]; then
            echo "IP Address changed successfully!"
            echo "New IP: $new_ip"
        else
            echo "Warning: IP address didn't change after several attempts"
        fi
    else
        echo "Failed to change Tor IP"
        return 1
    fi
}

get_random_user_agent() {
    echo "${USER_AGENTS[$RANDOM % ${#USER_AGENTS[@]}]}"
}

crawl_domain() {
    local domain="$1"
    echo "Crawling domain: $domain using Katana..."
    
    katana -u "https://$domain" \
           -js-crawl \
           -silent \
           -timeout 30 \
           -depth 2 \
           -o "$TEMP_PATHS_FILE"

    cat "$TEMP_PATHS_FILE" | \
    sed -E "s#https?://$domain/?##" | \
    sed -E 's#^/##' | \
    grep -v '^$' | \
    sort -u > "${TEMP_PATHS_FILE}.tmp"
    mv "${TEMP_PATHS_FILE}.tmp" "$TEMP_PATHS_FILE"

    echo "Discovered $(wc -l < "$TEMP_PATHS_FILE") unique paths"
}

send_request() {
    local path="$1"
    local user_agent=$(get_random_user_agent)
    local full_url
    
    if [ -z "$path" ]; then
        full_url="https://$DOMAIN"
    else
        full_url="https://$DOMAIN/$path"
    fi
    
    echo "Sending request to: $full_url"
    echo "Using User-Agent: $user_agent"
    
    curl --socks5-hostname 127.0.0.1:$SOCKS_PORT \
         -H "User-Agent: $user_agent" \
         -s \
         "$full_url"
}

# Initial checks
if ! command -v katana &> /dev/null; then
    echo "Error: katana is not installed. Please install it first."
    echo "You can install it using: go install github.com/projectdiscovery/katana/cmd/katana@latest"
    exit 1
fi

check_tor
verify_tor_auth

# Main execution
echo "Starting crawler for domain: $DOMAIN"
echo "Initial IP: $(get_current_ip)"

crawl_domain "$DOMAIN"

while read -r path; do
    echo "Processing path: $path"
    
    for i in {1..3}; do
        send_request "$path"
        echo "Request $i completed"
        renew_tor_ip
        sleep $DELAY
    done
    
done < "$TEMP_PATHS_FILE"

# Cleanup
rm -f "$TEMP_PATHS_FILE"

# Display completion message
echo "
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                        Traffic Generation Complete!
                        Created by: Phiroj Shah
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"
