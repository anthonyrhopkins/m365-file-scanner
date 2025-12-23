#!/bin/bash
# Microsoft 365 File Scanner - Local Server Launcher
# Works on Mac and Linux

PORT="${1:-3000}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HTML_FILE="loop-file-scanner.html"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  Microsoft 365 File Scanner${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warn() { echo -e "${YELLOW}! $1${NC}"; }
print_info() { echo -e "${BLUE}→ $1${NC}"; }

# Check if HTML file exists
check_html_file() {
    if [[ ! -f "$SCRIPT_DIR/$HTML_FILE" ]]; then
        print_error "Cannot find $HTML_FILE in $SCRIPT_DIR"
        echo ""
        echo "Please ensure you're running this script from the correct directory."
        exit 1
    fi
    print_success "Found $HTML_FILE"
}

# Find available Python
find_python() {
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
        print_success "Found Python 3: $(python3 --version 2>&1)"
    elif command -v python &> /dev/null; then
        if python --version 2>&1 | grep -q "Python 3"; then
            PYTHON_CMD="python"
            print_success "Found Python: $(python --version 2>&1)"
        else
            print_warn "Found Python 2, but Python 3 is recommended"
            PYTHON_CMD="python"
        fi
    else
        return 1
    fi
    return 0
}

# Check if port is available
is_port_available() {
    local port=$1
    if [[ "$OSTYPE" == "darwin"* ]]; then
        ! lsof -i:$port >/dev/null 2>&1
    else
        ! (echo >/dev/tcp/localhost/$port) 2>/dev/null
    fi
}

# Find an available port starting from the given port
find_available_port() {
    local start_port=$1
    local max_attempts=10
    local port=$start_port

    for ((i=0; i<max_attempts; i++)); do
        if is_port_available $port; then
            echo $port
            return 0
        fi
        ((port++))
    done

    # If no port found, return -1
    echo -1
    return 1
}

# Open browser
open_browser() {
    local url=$1
    sleep 2

    if [[ "$OSTYPE" == "darwin"* ]]; then
        open "$url" 2>/dev/null
    elif command -v xdg-open &> /dev/null; then
        xdg-open "$url" 2>/dev/null
    elif command -v sensible-browser &> /dev/null; then
        sensible-browser "$url" 2>/dev/null
    else
        print_warn "Could not open browser automatically"
        echo "Please open: $url"
    fi
}

# Main execution
main() {
    print_header

    # Step 1: Check HTML file
    check_html_file

    # Step 2: Find Python
    if ! find_python; then
        print_error "Python is not installed!"
        echo ""
        echo "Please install Python 3:"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "  brew install python3"
            echo "  or download from https://www.python.org/downloads/"
        else
            echo "  sudo apt install python3  (Debian/Ubuntu)"
            echo "  sudo yum install python3  (RHEL/CentOS)"
        fi
        exit 1
    fi

    # Step 3: Find available port
    print_info "Checking port availability..."

    ACTUAL_PORT=$(find_available_port $PORT)

    if [[ "$ACTUAL_PORT" == "-1" ]]; then
        print_error "Could not find an available port (tried $PORT to $((PORT+9)))"
        echo ""
        echo "Please close other applications or specify a different port:"
        echo "  ./start.sh 8080"
        exit 1
    fi

    if [[ "$ACTUAL_PORT" != "$PORT" ]]; then
        print_warn "Port $PORT is in use, using port $ACTUAL_PORT instead"
    else
        print_success "Port $PORT is available"
    fi

    # Step 4: Build URL
    SERVER_URL="http://localhost:$ACTUAL_PORT/$HTML_FILE"

    # Step 5: OAuth reminder
    echo ""
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}  ${GREEN}URL: $SERVER_URL${NC}"
    echo -e "${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}OAuth Redirect URI (register in Azure AD if needed):${NC}"
    echo -e "${CYAN}│${NC}  $SERVER_URL"
    echo -e "${CYAN}└─────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo "  Press Ctrl+C to stop the server"
    echo ""
    echo "─────────────────────────────────────────────────"

    cd "$SCRIPT_DIR"

    # Open browser in background
    open_browser "$SERVER_URL" &

    # Start Python HTTP server
    $PYTHON_CMD -m http.server $ACTUAL_PORT
}

# Handle Ctrl+C gracefully
trap 'echo ""; print_info "Server stopped."; exit 0' INT TERM

# Run main function
main
