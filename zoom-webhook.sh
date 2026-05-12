#!/bin/bash

# === Files and paths ===
SCRIPT_DIR="$(dirname "$0")"
SECRETS_FILE="$SCRIPT_DIR/.webhooks"
LOGFILE="$SCRIPT_DIR/call-status.log"
POLL_INTERVAL=3  # seconds

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
    ASSERTIONS=$(pmset -g assertions | grep -iE "zoom\.us|teams" | grep -v "CFNetwork\.StorageDB" )
    
    if echo "$ASSERTIONS" | grep -iE "NoDisplaySleepAssertion|PreventUserIdleSystemSleep" > /dev/null; then
        # INITIAL HIT: An assertion was detected! 
        # Wait 2 second to see if it's just a short notification sound...
        sleep 2
        
        # DOUBLE CHECK: Read pmset again
        ASSERTIONS_DOUBLE_CHECK=$(pmset -g assertions | grep -iE "zoom\.us|teams" | grep -v "CFNetwork\.StorageDB")
        if echo "$ASSERTIONS_DOUBLE_CHECK" | grep -iE "NoDisplaySleepAssertion|PreventUserIdleSystemSleep" > /dev/null; then
            # Still there 1 second later. It's a real meeting.
            OVERALL_STATE="Call active"
        else
            # It disappeared. It was just a notification blip.
            OVERALL_STATE="No calls"
        fi
    else
        # No assertions detected at all.
        OVERALL_STATE="No calls"
    fi

    # --- Trigger webhook only when overall state changes ---
    if [[ "$OVERALL_STATE" != "$LAST_OVERALL_STATE" ]]; then
        if [[ "$OVERALL_STATE" == "Call active" ]]; then
            curl -s -X POST "$CALL_START"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Active Assertion: $(echo "$ASSERTIONS_DOUBLE_CHECK" | grep -iE 'NoDisplaySleepAssertion|PreventUserIdleSystemSleep')" >> "$LOGFILE"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Call STARTED webhook sent." >> "$LOGFILE"
        else
            curl -s -X POST "$CALL_STOP"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Call STOPPED webhook sent." >> "$LOGFILE"
        fi
        
        # Update the memory state
        LAST_OVERALL_STATE="$OVERALL_STATE"
    fi

    # Main loop still polls every 5 seconds
    sleep $POLL_INTERVAL
done