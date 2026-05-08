#!/bin/bash

# === Webhook URLs (Consider moving these to a .env file!) ===

# === Files and paths ===
SCRIPT_DIR="$(dirname "$0")"
SECRETS_FILE="$SCRIPT_DIR/.webhooks"
LOGFILE="$SCRIPT_DIR/call-status.log"
POLL_INTERVAL=5  # seconds

# === Load Webhook URLs securely ===
if [ -f "$SECRETS_FILE" ]; then
    source "$SECRETS_FILE"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Secrets file not found at $SECRETS_FILE" > "$LOGFILE"
    exit 1
fi

# --- Overwrite log file at startup ---
echo "$(date '+%Y-%m-%d %H:%M:%S') - Power assertion detection script started" > "$LOGFILE"

# --- Initialize memory state ---
LAST_OVERALL_STATE="No calls"

while true; do
    # -------- POWER ASSERTION DETECTION --------
    # Check pmset for active assertions held by Zoom or Teams.
    # New Teams typically shows up as "Microsoft Teams" or "ms-teams".
    
    # We grep for "zoom.us" or "teams" holding a sleep prevention assertion.
    ASSERTIONS=$(pmset -g assertions | grep -iE "zoom\.us|teams")
    
    if echo "$ASSERTIONS" | grep -iE "NoDisplaySleepAssertion|PreventUserIdleSystemSleep" > /dev/null; then
        OVERALL_STATE="Call active"
    else
        OVERALL_STATE="No calls"
    fi

    # --- Trigger webhook only when overall state changes ---
    if [[ "$OVERALL_STATE" != "$LAST_OVERALL_STATE" ]]; then
        if [[ "$OVERALL_STATE" == "Call active" ]]; then
            curl -s -X POST "$CALL_START"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Call STARTED webhook sent." >> "$LOGFILE"
        else
            curl -s -X POST "$CALL_STOP"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Call STOPPED webhook sent." >> "$LOGFILE"
        fi
        
        # Update the memory state
        LAST_OVERALL_STATE="$OVERALL_STATE"
    fi

    sleep $POLL_INTERVAL
done