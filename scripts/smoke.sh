#!/usr/bin/env bash
#
# Deployed-WAR smoke test.
#
# Builds ROOT.war for a profile, runs it under embedded Jetty on an ephemeral
# port, and asserts the real endpoints actually serve. This exercises the parts
# the JUnit/Mockito unit tests cannot reach:
#   - the index.jsp scriptlets (host/IP/JVM/date, header + cookie enumeration)
#     compile and run inside a real servlet container,
#   - InfoServlet's RequestDispatcher forward to index.jsp,
#   - the per-profile deploy contract (javax.servlet vs jakarta.servlet, context
#     path "/").
#
# Standalone-HTTP-service e2e shape (no k8s / compose): start the process in the
# background, poll for readiness, curl the endpoints, tear down.
#
# Usage: PROFILE=tomcat9|tomcat10|tomcat11 scripts/smoke.sh   (default: tomcat9)
set -euo pipefail

# --- tunables (env-with-default; see configuration conventions) --------------
PROFILE="${PROFILE:-tomcat9}"
SMOKE_HOST="${SMOKE_HOST:-127.0.0.1}"
READY_TIMEOUT_SECONDS="${READY_TIMEOUT_SECONDS:-120}"
POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-2}"
CURL_MAX_TIME_SECONDS="${CURL_MAX_TIME_SECONDS:-5}"

# Ephemeral host port — kernel-allocated via bind(:0), never a literal, so
# parallel runs / `make jetty-run` / side-by-side dev don't collide.
pick_port() {
  python3 -c 'import socket; s=socket.socket(); s.bind(("",0)); print(s.getsockname()[1]); s.close()'
}
SMOKE_PORT="${SMOKE_PORT:-$(pick_port)}"
BASE="http://${SMOKE_HOST}:${SMOKE_PORT}"

# All three profiles' Jetty Maven plugins declare goalPrefix `jetty` (the
# tomcat9/tomcat10 org.eclipse.jetty:jetty-maven-plugin AND the tomcat11
# Jetty 12 org.eclipse.jetty.ee10:jetty-ee10-maven-plugin — verified from its
# plugin.xml), so `jetty:run` resolves to the profile's declared plugin. This
# matches `make jetty-run`.
case "$PROFILE" in
  tomcat9 | tomcat10 | tomcat11) JETTY_GOAL="jetty:run" ;;
  *) echo "ERROR: unknown PROFILE=$PROFILE (expected tomcat9|tomcat10|tomcat11)"; exit 2 ;;
esac

LOG="$(mktemp -t smoke-jetty.XXXXXX.log)"
JETTY_PID=""
PASS=0
FAIL=0

cleanup() {
  if [ -n "$JETTY_PID" ]; then
    # JETTY_PID is a setsid group leader, so its PGID == JETTY_PID — kill the
    # whole group (the mvn wrapper AND the forked Jetty JVM).
    kill -TERM "-$JETTY_PID" 2>/dev/null || kill -TERM "$JETTY_PID" 2>/dev/null || true
    wait "$JETTY_PID" 2>/dev/null || true
  fi
  rm -f "$LOG"
}
trap cleanup EXIT

echo "==> Smoke: PROFILE=$PROFILE  goal=$JETTY_GOAL  $BASE"

# Start Jetty in its own process group so cleanup can kill the whole tree.
setsid mvn -B clean package "$JETTY_GOAL" \
  -P"$PROFILE" \
  -Djetty.http.port="$SMOKE_PORT" \
  -Djetty.http.host="$SMOKE_HOST" \
  > "$LOG" 2>&1 &
JETTY_PID=$!

# --- readiness poll -----------------------------------------------------------
echo "==> Waiting up to ${READY_TIMEOUT_SECONDS}s for $BASE/ to serve..."
ready=""
deadline=$((SECONDS + READY_TIMEOUT_SECONDS))
while [ "$SECONDS" -lt "$deadline" ]; do
  if ! kill -0 "$JETTY_PID" 2>/dev/null; then
    echo "ERROR: Jetty process exited before becoming ready. Last 40 log lines:"
    tail -40 "$LOG" | sed 's/^/    /'
    exit 1
  fi
  if curl -sf -o /dev/null --max-time "$CURL_MAX_TIME_SECONDS" "$BASE/"; then
    ready=yes
    break
  fi
  sleep "$POLL_INTERVAL_SECONDS"
done
if [ "$ready" != yes ]; then
  echo "ERROR: $BASE/ did not become ready within ${READY_TIMEOUT_SECONDS}s. Last 40 log lines:"
  tail -40 "$LOG" | sed 's/^/    /'
  exit 1
fi
echo "==> Ready."

# --- assertions ---------------------------------------------------------------
# Single curl per check captures BOTH the HTTP status and the body, so the body
# asserted-on is the body of the asserted-status response (see test-coverage
# conventions: status + body, never body-only).
check() {
  local name="$1" path="$2" want_status="$3" want_body="$4"
  local tmp status body
  tmp="$(mktemp)"
  status="$(curl -s -o "$tmp" -w '%{http_code}' --max-time "$CURL_MAX_TIME_SECONDS" "$BASE$path" 2>/dev/null || true)"
  body="$(cat "$tmp")"; rm -f "$tmp"
  if [ "$status" = "$want_status" ] && printf '%s' "$body" | grep -qF "$want_body"; then
    echo "  PASS: $name (GET $path -> HTTP $status, body contains '$want_body')"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (GET $path)"
    echo "        expected: HTTP $want_status, body contains '$want_body'"
    echo "        actual:   HTTP $status, body[:200]: $(printf '%s' "$body" | head -c 200 | tr '\n' ' ')"
    FAIL=$((FAIL + 1))
  fi
}

# Content-Type assertion (servlet sets text/html;charset=UTF-8 explicitly).
check_content_type() {
  local name="$1" path="$2" want_ct="$3" ct
  ct="$(curl -sI --max-time "$CURL_MAX_TIME_SECONDS" "$BASE$path" 2>/dev/null \
        | awk 'tolower($1)=="content-type:"{sub(/^[^:]*:[ \t]*/,""); print; exit}' | tr -d '\r')"
  if printf '%s' "$ct" | grep -qiF "$want_ct"; then
    echo "  PASS: $name (Content-Type '$ct' contains '$want_ct')"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (GET $path Content-Type = '$ct', expected ~'$want_ct')"
    FAIL=$((FAIL + 1))
  fi
}

echo "==> Asserting endpoints..."
# Welcome page at context root "/" (replaces Tomcat's default ROOT app).
check "root welcome page"        "/"            200 "Java Web Application"
check "static index.html"        "/index.html"  200 "Java Web Application"
# JSP scriptlets render (host/IP/JVM + header/cookie tables) — untested by mocks.
check "index.jsp renders"        "/index.jsp"   200 "Server Info"
check "index.jsp header table"   "/index.jsp"   200 "HTTP Request Headers Received"
# Servlet forwards to index.jsp via RequestDispatcher.
check "InfoServlet forward"      "/infoservlet" 200 "Server Info"
check_content_type "InfoServlet content-type" "/infoservlet" "text/html"

echo "==> Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
