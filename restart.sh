#!/bin/bash
set -e

echo "Stopping..."
pkill -f botserver || true
pkill -f botui || true
pkill -f rustc || true

echo "Cleaning..."
rm -f botserver.log botui.log

echo "Building..."
cargo build -p botserver
cargo build -p botui

echo "Starting botserver..."
RUST_LOG=debug ./target/debug/botserver --noconsole > botserver.log 2>&1 &
echo "  PID: $!"

echo "Starting botui..."
BOTSERVER_URL="http://localhost:8080" ./target/debug/botui > botui.log 2>&1 &
echo "  PID: $!"

echo "Done. Logs: tail -f botserver.log botui.log"
