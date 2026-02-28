#!/bin/bash
set -e

#######################################
# General Bots Development Environment Reset Script
# Description: Cleans and restarts the development environment
# Usage: ./reset.sh
#######################################

# Color codes for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Log function
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Trap errors and cleanup
cleanup_on_error() {
    log_warning "Script encountered an error"
    exit 1
}

trap cleanup_on_error ERR

log_info "Starting environment reset..."
echo ""

# Step 1: Clean up existing installations
log_info "Step 1/4: Cleaning up existing installation..."
rm -rf botserver-stack/ ./work/ .env
log_success "Cleanup complete"
echo ""

# Step 2: Build and restart services
log_info "Step 2/4: Building and restarting services..."
./restart.sh
log_success "Services restarted"
echo ""

# Step 3: Wait for bootstrap
log_info "Step 3/4: Waiting for BotServer to bootstrap (this may take a minute)..."

# Tail the log starting from now, so we only see the new run
tail -n 0 -f botserver.log | while read line; do
    # Show bootstrap-related messages
    if [[ "$line" == *"GENERAL BOTS - INITIAL SETUP"* ]]; then
        SHOW=1
        log_info "Bootstrap process started..."
    fi

    if [[ "$SHOW" == "1" ]]; then
        echo "$line"
    elif [[ "$line" == *"Checking if bootstrap is needed"* ]] || \
         [[ "$line" == *"No admin user found"* ]] || \
         [[ "$line" == *"Created admin user"* ]] || \
         [[ "$line" == *"Created default organization"* ]] || \
         [[ "$line" == *"Starting"* ]] || \
         [[ "$line" == *"Installing"* ]]; then
         echo "$line"
    fi

    # Stop tracking when bootstrap completes
    if [[ "$line" == *"Bootstrap complete: admin user"* ]] || \
       [[ "$line" == *"Skipping bootstrap"* ]]; then
        pkill -P $$ tail || true
        break
    fi
done

log_success "Bootstrap complete"
echo ""

# Step 4: Final confirmation
log_info "Step 4/4: Verifying services..."
sleep 2

if pgrep -f "botserver" > /dev/null; then
    log_success "BotServer is running"
else
    log_warning "BotServer may not be running properly"
fi

if pgrep -f "botui" > /dev/null; then
    log_success "BotUI is running"
else
    log_warning "BotUI may not be running properly"
fi

echo ""
echo "=========================================="
log_success "✅ Reset complete!"
echo "=========================================="
echo ""
echo "You can now access:"
echo "  - BotUI Desktop: Check the BotUI window or logs"
echo "  - Logs: tail -f botserver.log botui.log"
echo ""
