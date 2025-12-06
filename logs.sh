#!/bin/bash

LOG_FILE="$(pwd)/modmove.log"

echo "Streaming ModMove logs (press Ctrl+C to stop)..."
echo "Logs saved to: $LOG_FILE"
echo "Try moving windows to see debug output"
echo ""

# Clear old log file
> "$LOG_FILE"

# Stream to both terminal and file
log stream --predicate 'process == "ModMove"' --level debug | tee "$LOG_FILE"
