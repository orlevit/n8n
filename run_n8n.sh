#!/bin/bash
set -e

# --- CONFIG ---
PORT=5678
DOCKER_SERVICE="n8n"
COMPOSE_FILE="docker-compose.yml"

# --- START NGROK IN BACKGROUND ---
echo "🚀 Starting ngrok on port ${PORT}..."
ngrok http $PORT > /tmp/ngrok.log 2>&1 &

# Wait for ngrok API to be available
echo "⏳ Waiting for ngrok to initialize..."
until curl -s http://127.0.0.1:4040/api/tunnels >/dev/null 2>&1; do
  sleep 1
done

# --- GET PUBLIC URL (strict pattern: starts with https:// and ends with ") ---
NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels \
  | grep -o '"public_url":"https://[^"]*"' \
  | head -n 1 \
  | sed 's/"public_url":"\([^"]*\)"/\1/')

if [ -z "$NGROK_URL" ]; then
  echo "❌ Could not find ngrok URL — check /tmp/ngrok.log for details."
  exit 1
fi

echo "🌐 Found ngrok URL: $NGROK_URL"

# --- UPDATE docker-compose.yml (only replace WEBHOOK_URL line) ---
echo "📝 Updating WEBHOOK_URL in $COMPOSE_FILE..."
sed -i "s|WEBHOOK_URL=.*|WEBHOOK_URL=${NGROK_URL}/|" "$COMPOSE_FILE"

# --- RESTART n8n ---
echo "🔄 Restarting Docker container..."
docker compose down
docker compose up -d

echo "✅ n8n is now live at: ${NGROK_URL}"
echo "💡 To view tunnel info: http://127.0.0.1:4040"
echo "🛑 To stop ngrok, run: pkill ngrok"
