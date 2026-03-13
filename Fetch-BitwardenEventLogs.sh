#!/usr/bin/env bash
# ==============================================================================
# Fetch-BitwardenEventLogs.sh
# ==============================================================================
#
# .SYNOPSIS
#   Exports Bitwarden organisation event logs and produces targeted security
#   and compliance audit reports as CSV files with a run log.
#
# .DESCRIPTION
#   Bitwarden records 60+ event types but provides no way to filter, aggregate,
#   or export them into actionable reports from the Admin Console. This script
#   fills that gap by pulling data from the Bitwarden Public API and producing
#   up to ten focused CSV reports alongside a timestamped log file.
#
#   Key behaviours:
#     - Credentials are consumed securely: env vars, interactive prompt (no
#       echo), or a GPG/openssl-encrypted credentials file. No plaintext
#       secrets are ever written to disk by this script.
#     - Access tokens are cached per-org and reused for up to 55 minutes,
#       avoiding unnecessary re-authentication on repeated runs.
#     - Event fetching is paginated automatically. Depth is controlled by
#       BitAPI_HISTORY_DAYS (most common), BitAPI_MAX_PAGES, or
#       BitAPI_MAX_EVENTS — whichever is set first takes priority.
#     - BitAPI_DRY_RUN=true authenticates and fetches events but writes no
#       files; it prints a preview of what each report would produce.
#     - Multi-org (MSP) mode runs all selected reports for every organisation
#       listed in a credentials file, writing to per-org subdirectories.
#     - All console output is mirrored to a timestamped log file.
#
#   Supports: Bitwarden US cloud, EU cloud, and self-hosted instances.
#
#   Reports produced:
#     01 offboarding_exposure   Which credentials did this departing user touch?
#     02 dormant_users          Who has a licence but hasn't logged in recently?
#     03 security_alerts        What high-risk events need immediate review?
#     04 brute_force_watch      Is anyone or any IP showing attack patterns?
#     05 after_hours_access     Who accessed the vault outside business hours?
#     06 item_access_history    Which credentials are accessed most, and by whom?
#     07 new_device_logins      Has anyone logged in from an unrecognised IP?
#     08 license_utilisation    How many licences are active vs idle vs unused?
#     09 privilege_changes      What admin/policy/group changes were made?
#     10 raw_events             Full enriched log for SIEM or custom analysis.
#
# .PARAMETER BitAPI_CLIENT_ID
#   Organisation API client ID from Bitwarden Admin Console → Settings →
#   Organisation info → API key. Format: organization.xxxx-xxxx-xxxx-xxxx
#   If unset, the script prompts securely (no terminal echo).
#
# .PARAMETER BitAPI_CLIENT_SECRET
#   Organisation API client secret (same location as above).
#   If unset, the script prompts securely (no terminal echo).
#
# .PARAMETER BitAPI_VAULT_REGION
#   Target deployment. Accepted values: us | eu | self-hosted. Default: us.
#
# .PARAMETER BitAPI_SELF_HOSTED_URI
#   Required when BitAPI_VAULT_REGION=self-hosted. Example: https://bw.company.com
#
# .PARAMETER BitAPI_REPORTS
#   Comma-separated list of report names to run, or "all". Default: all.
#   Valid names: offboarding_exposure, dormant_users, security_alerts,
#   brute_force_watch, after_hours_access, item_access_history,
#   new_device_logins, license_utilisation, privilege_changes, raw_events
#
# .PARAMETER BitAPI_OUTPUT_DIR
#   Directory where CSV report files and the log file are written.
#   Created if absent. Default: ./bw_reports
#
# .PARAMETER BitAPI_LOG_FILE
#   Path to the log file. All console output is mirrored here.
#   Default: <BitAPI_OUTPUT_DIR>/run_<timestamp>.log
#
# .PARAMETER BitAPI_DRY_RUN
#   When set to true, authenticates and fetches events but writes no files.
#   Prints a preview of what each report would produce. Default: false
#
# .PARAMETER BitAPI_CREDS_FILE
#   Path to a GPG- or openssl-encrypted credentials file. The decrypted
#   content must be two lines: line 1 = client_id, line 2 = client_secret.
#   Create one with: --save-creds  (see EXAMPLES).
#
# .PARAMETER BitAPI_HISTORY_DAYS
#   Auto-set START_DATE to today minus N days. Highest-priority depth control.
#   Ignored if BitAPI_START_DATE is already set. Example: BitAPI_HISTORY_DAYS=90
#
# .PARAMETER BitAPI_MAX_PAGES
#   Stop fetching after N pages (500 events/page). Useful for bounded pulls.
#   Ignored if BitAPI_HISTORY_DAYS is set.
#
# .PARAMETER BitAPI_MAX_EVENTS
#   Stop fetching after N total events. Useful for testing. Lowest priority.
#
# .PARAMETER BitAPI_START_DATE
#   Explicit range start in ISO 8601 UTC. Example: 2025-01-01T00:00:00Z
#
# .PARAMETER BitAPI_END_DATE
#   Explicit range end in ISO 8601 UTC. Example: 2025-12-31T23:59:59Z
#
# .PARAMETER BitAPI_OFFBOARD_USER_EMAIL
#   Required for the offboarding_exposure report. Email of the departing user.
#
# .PARAMETER BitAPI_DORMANT_DAYS
#   Days of inactivity before a user is flagged as dormant. Default: 30
#
# .PARAMETER BitAPI_BF_THRESHOLD
#   Failed login count that triggers an ALERT flag in brute_force_watch. Default: 10
#
# .PARAMETER BitAPI_BIZ_HOURS_START
#   Business hours start, 24h UTC integer. Default: 8
#
# .PARAMETER BitAPI_BIZ_HOURS_END
#   Business hours end, 24h UTC integer. Default: 18
#
# .PARAMETER BitAPI_BIZ_DAYS
#   Comma-separated ISO weekday numbers treated as business days. Default: 1,2,3,4,5
#
# .PARAMETER BitAPI_ORGS_FILE
#   Path to a CSV for MSP/multi-org mode. Each line: org_name,client_id,client_secret
#   Lines beginning with # are treated as comments. Each org gets its own subdirectory.
#
# .PARAMETER BitAPI_SCHEDULE
#   When set, prints a ready-to-use crontab entry and systemd timer/service
#   unit for the given cron expression, then exits without running any reports.
#   Example: BitAPI_SCHEDULE="0 7 * * 1"
#
# .EXAMPLE
#   # 0. SAVE CREDENTIALS — encrypt and store credentials to disk for unattended runs.
#   #    Run this once interactively. You will be prompted for your client_id and
#   #    client_secret (input is hidden). The file is encrypted with GPG if available,
#   #    otherwise openssl AES-256. Pass the file path to subsequent runs via
#   #    BitAPI_CREDS_FILE so credentials never need to be typed or exported again.
#
#   ./Fetch-BitwardenEventLogs.sh --save-creds
#
#   #    To save to a custom path:
#   BitAPI_CREDS_FILE=/etc/bw_reporter/org1.creds ./Fetch-BitwardenEventLogs.sh --save-creds
#
#   #    To use the saved file in a subsequent run:
#   BitAPI_CREDS_FILE=/etc/bw_reporter/org1.creds ./Fetch-BitwardenEventLogs.sh
#
# .EXAMPLE
#   # 1. DRY RUN — verify credentials and preview what reports would produce.
#   #    Authenticates, fetches all events, and prints row counts per report.
#   #    No files are written. Always run this first in a new environment.
#
#   export BitAPI_CLIENT_ID=organization.xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#   export BitAPI_CLIENT_SECRET=your_secret_here
#   BitAPI_DRY_RUN=true ./Fetch-BitwardenEventLogs.sh
#
#   #    Credentials can also be entered interactively — omit the exports above
#   #    and the script will prompt for them with no terminal echo:
#   BitAPI_DRY_RUN=true ./Fetch-BitwardenEventLogs.sh
#
# .EXAMPLE
#   # 2. FULL RECURSIVE RUN — all reports, all available history, written to disk.
#   #    No depth limit is set, so every event page is fetched (recursive).
#   #    If credentials are not set as env vars, the script prompts securely;
#   #    or point BitAPI_CREDS_FILE at a GPG/openssl-encrypted file created
#   #    with --save-creds to skip the prompt entirely in unattended runs.
#
#   BitAPI_VAULT_REGION=eu \
#   BitAPI_OUTPUT_DIR=/var/reports/bitwarden \
#   ./Fetch-BitwardenEventLogs.sh
#
# .EXAMPLE
#   # 3. FILTERED RUN — specific reports, bounded depth.
#   #    Runs only the two highest-value security reports and limits fetch
#   #    to the last 30 days. Recommended pattern for a scheduled nightly job.
#
#   BitAPI_REPORTS=security_alerts,brute_force_watch \
#   BitAPI_HISTORY_DAYS=30 \
#   ./Fetch-BitwardenEventLogs.sh
#
# .NOTES
#   File name   : Fetch-BitwardenEventLogs.sh
#   Version     : 3.2.0
#   Author      : sshadmin
#   Tested on   : macOS (bash 4+ via Homebrew)
#   Requires    : bash 4+, curl, jq
#
#   Install jq if missing:
#     macOS   : brew install jq      (also: brew install bash  for bash 4+)
#     Ubuntu  : sudo apt install jq
#     RHEL    : sudo yum install jq
#     Windows : run under WSL, or see https://jqlang.github.io/jq/download/
#
#   Credentials: Never commit secrets to version control. Prefer injecting
#     BitAPI_CLIENT_ID / BitAPI_CLIENT_SECRET at runtime via a secrets manager
#     (HashiCorp Vault, AWS Secrets Manager, GitHub Actions secrets).
#     For local use, the --save-creds flag writes a GPG-encrypted file.
#     The API key is scoped to org management only — it cannot read vault items.
#
#   Token cache: Tokens are cached in $TMPDIR/bw_token_<hash> and reused for
#     up to 55 minutes. Delete these files to force re-authentication.
#
#   Data gaps:  collectionId is absent from item-access events by Bitwarden
#     API design (tracked: community.bitwarden.com/t/94424). Cross-reference
#     itemIds with your collection inventory manually when needed.
#     Event logs rely on client-reported data and may not satisfy legal
#     forensics requirements on their own (bitwarden.com/help/event-logs/).
#     Bitwarden removed failed-login email alerts in 2025.8.1 — the
#     brute_force_watch report is now the primary detection method.
#
#   Compliance: Reports support evidence gathering for SOC 2, ISO 27001,
#     HIPAA, and GDPR access audits. They are supporting evidence, not a
#     complete audit trail.
#
# ==============================================================================

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# DEFAULTS — all overridable by environment variable
# ─────────────────────────────────────────────────────────────────────────────
BitAPI_CLIENT_ID="${BitAPI_CLIENT_ID:-}"
BitAPI_CLIENT_SECRET="${BitAPI_CLIENT_SECRET:-}"

BitAPI_VAULT_REGION="${BitAPI_VAULT_REGION:-us}"
BitAPI_SELF_HOSTED_URI="${BitAPI_SELF_HOSTED_URI:-}"

BitAPI_REPORTS="${BitAPI_REPORTS:-all}"
BitAPI_OUTPUT_DIR="${BitAPI_OUTPUT_DIR:-./bw_reports}"
BitAPI_LOG_FILE="${BitAPI_LOG_FILE:-}"
BitAPI_DRY_RUN="${BitAPI_DRY_RUN:-false}"

BitAPI_CREDS_FILE="${BitAPI_CREDS_FILE:-}"

BitAPI_HISTORY_DAYS="${BitAPI_HISTORY_DAYS:-}"
BitAPI_MAX_PAGES="${BitAPI_MAX_PAGES:-}"
BitAPI_MAX_EVENTS="${BitAPI_MAX_EVENTS:-}"

BitAPI_START_DATE="${BitAPI_START_DATE:-}"
BitAPI_END_DATE="${BitAPI_END_DATE:-}"

BitAPI_OFFBOARD_USER_EMAIL="${BitAPI_OFFBOARD_USER_EMAIL:-}"
BitAPI_DORMANT_DAYS="${BitAPI_DORMANT_DAYS:-30}"
BitAPI_BF_THRESHOLD="${BitAPI_BF_THRESHOLD:-10}"
BitAPI_BIZ_HOURS_START="${BitAPI_BIZ_HOURS_START:-8}"
BitAPI_BIZ_HOURS_END="${BitAPI_BIZ_HOURS_END:-18}"
BitAPI_BIZ_DAYS="${BitAPI_BIZ_DAYS:-1,2,3,4,5}"

BitAPI_ORGS_FILE="${BitAPI_ORGS_FILE:-}"
BitAPI_SCHEDULE="${BitAPI_SCHEDULE:-}"
BitAPI_DEBUG="${BitAPI_DEBUG:-false}"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TOKEN_CACHE_DIR="${TMPDIR:-/tmp}"
TOKEN_CACHE_DIR="${TOKEN_CACHE_DIR%/}"

declare -A REPORT_COUNTS=()
CRITICAL_COUNT=0
HIGH_COUNT=0

# ─────────────────────────────────────────────────────────────────────────────
# MODULE: LOGGING
# All output goes to stdout/stderr and is tee'd to the log file once
# init_log() is called after the output directory is created.
# ─────────────────────────────────────────────────────────────────────────────
_LOG_FILE=""

init_log() {
  if [[ "$BitAPI_DRY_RUN" == "true" ]]; then
    _LOG_FILE=""
    return
  fi
  _LOG_FILE="${BitAPI_LOG_FILE:-$BitAPI_OUTPUT_DIR/run_${TIMESTAMP}.log}"
  # Reopen stdout and stderr through tee so every subsequent echo/printf
  # is mirrored to the log file without any changes to call sites.
  exec > >(tee -a "$_LOG_FILE") 2>&1
  log "Log file : $_LOG_FILE"
}

log()     { echo "[INFO]  $*"; }
log_err() { echo "[INFO]  $*" >&2; }
warn()    { echo "[WARN]  $*" >&2; }
die()     { echo "[ERROR] $*" >&2; exit 1; }
debug()   { [[ "$BitAPI_DEBUG" == "true" ]] && echo "[DEBUG] $*" >&2 || true; }
section() { printf '\n'; printf '─%.0s' {1..62}; printf '\n  %s\n' "$*"; }

# ─────────────────────────────────────────────────────────────────────────────
# MODULE: LABEL MAPS
# ─────────────────────────────────────────────────────────────────────────────
JQ_TYPE_MAP=$(cat <<'EOF'
{"1000":"User_LoggedIn","1001":"User_ChangedPassword","1002":"User_Enabled2FA",
 "1003":"User_Disabled2FA","1004":"User_Recovered2FA","1005":"User_FailedLogin",
 "1006":"User_FailedLogin_2FA","1007":"User_ExportedVault","1008":"User_UpdatedTempPassword",
 "1009":"User_MigratedKeyConnector","1100":"Cipher_Created","1101":"Cipher_Updated",
 "1102":"Cipher_Deleted","1103":"Cipher_AttachmentCreated","1104":"Cipher_AttachmentDeleted",
 "1105":"Cipher_Shared","1106":"Cipher_UpdatedCollections","1107":"Cipher_Viewed",
 "1108":"Cipher_Moved","1109":"Cipher_PermanentlyDeleted","1110":"Cipher_Restored",
 "1111":"Cipher_PasswordViewed","1112":"Cipher_HiddenFieldViewed","1113":"Cipher_CardNumberViewed",
 "1300":"Collection_Created","1301":"Collection_Updated","1302":"Collection_Deleted",
 "1400":"Group_Created","1401":"Group_Updated","1402":"Group_Deleted",
 "1500":"OrgUser_Invited","1501":"OrgUser_Confirmed","1502":"OrgUser_Updated",
 "1503":"OrgUser_Removed","1504":"OrgUser_UpdatedGroups","1600":"Org_Updated",
 "1601":"Org_PurgedVault","1602":"Org_ClientExportedVault","1603":"Org_VaultAccessedByAdmin",
 "1604":"Org_EnabledSSO","1605":"Org_DisabledSSO","1606":"Org_EnabledKeyConnector",
 "1607":"Org_DisabledKeyConnector","1700":"Policy_Updated","1800":"SSO_UserAuthenticated",
 "2000":"Secret_Retrieved","1115":"Cipher_AutofillCredential","1116":"Cipher_CopiedPassword"}
EOF
)

JQ_DEVICE_MAP=$(cat <<'EOF'
{"0":"Android","1":"iOS","2":"ChromeExtension","3":"FirefoxExtension",
 "4":"OperaExtension","5":"EdgeExtension","6":"WindowsDesktop","7":"MacOSDesktop",
 "8":"LinuxDesktop","9":"WebVault_AdminConsole","10":"BraveExtension",
 "11":"SafariExtension","12":"WindowsCLI","13":"MacOSCLI","14":"LinuxCLI","15":"SDK"}
EOF
)

# ─────────────────────────────────────────────────────────────────────────────
# MODULE: JQ SHARED FRAGMENTS
# ─────────────────────────────────────────────────────────────────────────────
readonly JQ_ID_TO_EMAIL='($members | map({(.id): .email}) | add // {}) as $itoe'

readonly JQ_DATE_TO_EPOCH='if . == null then 0 else
  split("T")[0] | split("-") |
  (((.[0]|tonumber)-1970)*365*86400 +
   ((.[1]|tonumber)-1)*30*86400    +
   ((.[2]|tonumber)-1)*86400)
end'

readonly JQ_ENRICH_EVENT='
  (.type | tostring) as $t |
  (.deviceType // -1 | tostring) as $d |
  (.type_label   = ($tmap[$t] // "Unknown_\($t)")) |
  (.device_label = ($dmap[$d] // "Device_\($d)")) |
  (.device       = $d) |
  (.event_type   = $t)
'

# ─────────────────────────────────────────────────────────────────────────────
# MODULE: UTILITIES
# ─────────────────────────────────────────────────────────────────────────────
report_enabled() {
  [[ "$BitAPI_REPORTS" == "all" ]] || echo "$BitAPI_REPORTS" | tr ',' '\n' | grep -qx "$1"
}

out_file()  { echo "$BitAPI_OUTPUT_DIR/$1_$TIMESTAMP.csv"; }
urlencode() { printf '%s' "$1" | jq -sRr @uri; }

run_jq() {
  local filter="$1"; shift
  jq -c \
    --argjson members "$MEMBERS" \
    --argjson tmap    "$JQ_TYPE_MAP" \
    --argjson dmap    "$JQ_DEVICE_MAP" \
    "$filter" \
    "$@" <<< "$EVENTS"
}

# ─────────────────────────────────────────────────────────────────────────────
# MODULE: OUTPUT EMISSION
# ─────────────────────────────────────────────────────────────────────────────

# emit_rows FILE CSV_HEADER
# Reads NDJSON objects from stdin and writes them as CSV rows to FILE.
# In dry-run mode, counts and returns the row count instead of writing.
emit_rows() {
  local file="$1" csv_header="${2:-}"

  if [[ "$BitAPI_DRY_RUN" == "true" ]]; then
    local count=0
    while IFS= read -r _line; do (( count++ )) || true; done
    echo "$count"
    return
  fi

  [[ -n "$csv_header" ]] && echo "$csv_header" > "$file"
  while IFS= read -r obj; do
    echo "$obj" | jq -r '[to_entries[].value | tostring] | @csv'
  done >> "$file"
}

# register_report NAME FILE [DRY_RUN_COUNT]
# Records row counts into the global tracking map.
# Also tallies CRITICAL/HIGH counts for the security_alerts report.
register_report() {
  local name="$1" file="$2" rows=0

  if [[ "$BitAPI_DRY_RUN" == "true" ]]; then
    rows="${3:-0}"
  else
    rows=$(tail -n +2 "$file" 2>/dev/null | wc -l | tr -d ' ')
  fi

  REPORT_COUNTS["$name"]=$rows

  if [[ "$name" == "security_alerts" && "$BitAPI_DRY_RUN" != "true" ]]; then
    CRITICAL_COUNT=$(grep -c ",CRITICAL," "$file" 2>/dev/null || echo 0)
    HIGH_COUNT=$(grep    -c ",HIGH,"     "$file" 2>/dev/null || echo 0)
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# MODULE: DEPENDENCY CHECK
# ─────────────────────────────────────────────────────────────────────────────
check_deps() {
  local missing=()
  for cmd in curl jq; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done

  if (( ${#missing[@]} > 0 )); then
    echo ""
    echo "  Missing required tools: ${missing[*]}"
    echo ""
    if [[ "$OSTYPE" == "darwin"* ]]; then
      echo "  macOS  : brew install ${missing[*]}"
      echo "  Note   : macOS ships with bash 3.2 — upgrade with: brew install bash"
      echo "           Then run: /opt/homebrew/bin/bash ./Fetch-BitwardenEventLogs.sh"
    elif command -v apt &>/dev/null; then
      echo "  Ubuntu : sudo apt install ${missing[*]}"
    elif command -v yum &>/dev/null; then
      echo "  RHEL   : sudo yum install ${missing[*]}"
    else
      echo "  See    : https://jqlang.github.io/jq/download/"
    fi
    echo ""
    exit 1
  fi

  (( BASH_VERSINFO[0] >= 4 )) \
    || die "bash 4+ required (running $BASH_VERSION). macOS: brew install bash"
}

# ─────────────────────────────────────────────────────────────────────────────
# MODULE: CREDENTIALS
# Priority: env vars → encrypted file → interactive prompt
# ─────────────────────────────────────────────────────────────────────────────
save_creds() {
  local target="${BitAPI_CREDS_FILE:-$HOME/.bw_reporter_creds}"
  echo ""
  echo "  Saving encrypted credentials to: $target"
  read -rp  "  Organisation client_id     : " input_id
  read -rsp "  Organisation client_secret : " input_secret; echo ""

  if command -v gpg &>/dev/null; then
    printf '%s\n%s\n' "$input_id" "$input_secret" \
      | gpg --symmetric --cipher-algo AES256 -o "$target" \
      && chmod 600 "$target" \
      && log "Saved (GPG-encrypted): $target"
  elif command -v openssl &>/dev/null; then
    printf '%s\n%s\n' "$input_id" "$input_secret" \
      | openssl enc -aes-256-cbc -pbkdf2 -out "$target" \
      && chmod 600 "$target" \
      && log "Saved (openssl AES-256): $target"
  else
    die "Neither gpg nor openssl found. Install one to use encrypted credentials."
  fi
  exit 0
}

load_creds_file() {
  local src="$1"
  [[ -f "$src" ]] || die "BitAPI_CREDS_FILE not found: $src"

  local decrypted
  if command -v gpg &>/dev/null && gpg --list-packets "$src" &>/dev/null 2>&1; then
    decrypted=$(gpg --quiet --decrypt "$src" 2>/dev/null) \
      || die "GPG decryption failed for $src"
  elif command -v openssl &>/dev/null; then
    decrypted=$(openssl enc -d -aes-256-cbc -pbkdf2 -in "$src" 2>/dev/null) \
      || die "openssl decryption failed for $src. Wrong passphrase?"
  else
    die "Cannot decrypt $src — neither gpg nor openssl is available."
  fi

  BitAPI_CLIENT_ID=$(echo     "$decrypted" | sed -n '1p')
  BitAPI_CLIENT_SECRET=$(echo "$decrypted" | sed -n '2p')
  [[ -n "$BitAPI_CLIENT_ID" && -n "$BitAPI_CLIENT_SECRET" ]] \
    || die "Decrypted file did not yield client_id and client_secret on lines 1-2."
  log "Credentials loaded from encrypted file."
}

prompt_creds() {
  echo ""
  warn "BitAPI_CLIENT_ID and/or BitAPI_CLIENT_SECRET are not set."
  echo "  Input is hidden — nothing is written to disk or shell history."
  echo ""
  [[ -z "$BitAPI_CLIENT_ID" ]]     && read -rp  "  client_id     : " BitAPI_CLIENT_ID
  [[ -z "$BitAPI_CLIENT_SECRET" ]] && read -rsp "  client_secret : " BitAPI_CLIENT_SECRET; echo ""
  echo ""
}

resolve_credentials() {
  [[ -n "$BitAPI_CLIENT_ID" && -n "$BitAPI_CLIENT_SECRET" ]] && return
  if [[ -n "$BitAPI_CREDS_FILE" ]]; then
    load_creds_file "$BitAPI_CREDS_FILE"
    return
  fi
  prompt_creds
  [[ -n "$BitAPI_CLIENT_ID" && -n "$BitAPI_CLIENT_SECRET" ]] \
    || die "Credentials required. Set BitAPI_CLIENT_ID and BitAPI_CLIENT_SECRET, or use --save-creds."
}

# ─────────────────────────────────────────────────────────────────────────────
# MODULE: TOKEN CACHE
# ─────────────────────────────────────────────────────────────────────────────
token_cache_path() {
  local hash
  hash=$(printf '%s' "$BitAPI_CLIENT_ID" | jq -sRr @base64 | tr -d '=' | head -c 16)
  echo "$TOKEN_CACHE_DIR/.bw_token_${hash}"
}

get_cached_token() {
  local cache; cache=$(token_cache_path)
  debug "get_cached_token: cache path=$cache"
  [[ -f "$cache" ]] || { debug "get_cached_token: no cache file found"; return 1; }
  local age=$(( $(date +%s) - $(date -r "$cache" +%s 2>/dev/null || stat -c %Y "$cache" 2>/dev/null || echo 0) ))
  debug "get_cached_token: age=${age}s"
  (( age < 3300 )) || { debug "get_cached_token: token stale, skipping"; return 1; }
  debug "get_cached_token: returning cached token"
  cat "$cache"
}

save_token_cache() {
  local token="$1" cache; cache=$(token_cache_path)
  printf '%s' "$token" > "$cache"
  chmod 600 "$cache"
}

# ─────────────────────────────────────────────────────────────────────────────
# MODULE: API — AUTH, VAULT URI, DATA FETCH
# ─────────────────────────────────────────────────────────────────────────────
resolve_vault_uri() {
  case "$BitAPI_VAULT_REGION" in
    us)          echo "https://vault.bitwarden.com" ;;
    eu)          echo "https://vault.bitwarden.eu" ;;
    self-hosted)
      [[ -n "$BitAPI_SELF_HOSTED_URI" ]] \
        || die "BitAPI_SELF_HOSTED_URI required when BitAPI_VAULT_REGION=self-hosted"
      echo "${BitAPI_SELF_HOSTED_URI%/}"
      ;;
    *) die "Invalid BitAPI_VAULT_REGION '$BitAPI_VAULT_REGION'. Choose: us | eu | self-hosted" ;;
  esac
}

get_access_token() {
  local vault_uri="$1"
  debug "get_access_token: vault_uri=$vault_uri"

  local cached
  if cached=$(get_cached_token); then
    debug "get_access_token: using cached token"
    log_err "Reusing cached access token (< 55 min old)."
    echo "$cached"
    return
  fi

  log_err "Authenticating with $vault_uri ..."
  local resp
  resp=$(curl -sf -X POST "$vault_uri/identity/connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "grant_type=client_credentials" \
    --data-urlencode "scope=api.organization" \
    --data-urlencode "client_id=$BitAPI_CLIENT_ID" \
    --data-urlencode "client_secret=$BitAPI_CLIENT_SECRET") \
    || die "Authentication failed. Verify credentials and BitAPI_VAULT_REGION."

  local token
  token=$(echo "$resp" | jq -r '.access_token // empty')
  [[ -n "$token" ]] || die "No access_token in response: $resp"

  save_token_cache "$token"
  echo "$token"
}

resolve_depth() {
  if [[ -n "$BitAPI_HISTORY_DAYS" && -z "$BitAPI_START_DATE" ]]; then
    BitAPI_START_DATE=$(date -u -d "-${BitAPI_HISTORY_DAYS} days" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
                     || date -u -v "-${BitAPI_HISTORY_DAYS}d"   '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null) \
      || warn "Could not compute BitAPI_HISTORY_DAYS offset. Fetching all history."
    log "BitAPI_HISTORY_DAYS=$BitAPI_HISTORY_DAYS → BitAPI_START_DATE=$BitAPI_START_DATE"
  fi
}

fetch_all_events() {
  local vault_uri="$1" token="$2"
  local cont_token="" page=1 total=0 date_params=""
  local all_file; all_file=$(mktemp)
  echo '[]' > "$all_file"

  [[ -n "$BitAPI_START_DATE" ]] && date_params+="&start=$(urlencode "$BitAPI_START_DATE")"
  [[ -n "$BitAPI_END_DATE"   ]] && date_params+="&end=$(urlencode "$BitAPI_END_DATE")"

  log_err "Fetching events ..."

  while true; do
    if [[ -n "$BitAPI_MAX_PAGES" ]] && (( page > BitAPI_MAX_PAGES )); then
      log_err "BitAPI_MAX_PAGES=$BitAPI_MAX_PAGES reached — stopping."
      break
    fi

    local url="$vault_uri/api/public/events?pageSize=500${date_params}"
    [[ -n "$cont_token" ]] && url+="&continuationToken=$(urlencode "$cont_token")"

    local resp
    resp=$(curl -sf -X GET "$url" -H "Authorization: Bearer $token") || {
      rm -f "$all_file"
      die "Failed fetching events (page $page)."
    }

    local page_data page_cnt
    page_data=$(echo "$resp" | jq '.data // []')
    page_cnt=$(echo  "$page_data" | jq 'length')
    log_err "Page $page: $page_cnt events"

    jq -s '.[0] + .[1]' "$all_file" - <<< "$page_data" > "${all_file}.tmp" \
      && mv "${all_file}.tmp" "$all_file"

    total=$(( total + page_cnt ))

    if [[ -n "$BitAPI_MAX_EVENTS" ]] && (( total >= BitAPI_MAX_EVENTS )); then
      log_err "BitAPI_MAX_EVENTS=$BitAPI_MAX_EVENTS reached — stopping."
      jq --argjson n "$BitAPI_MAX_EVENTS" '.[:$n]' "$all_file" > "${all_file}.tmp" \
        && mv "${all_file}.tmp" "$all_file"
      break
    fi

    cont_token=$(echo "$resp" | jq -r '.continuationToken // empty')
    [[ -z "$cont_token" ]] && break
    (( page++ ))
  done

  log_err "Total events fetched: $(jq 'length' "$all_file")"
  cat "$all_file"
  rm -f "$all_file"
}

fetch_members() {
  local vault_uri="$1" token="$2"
  log_err "Fetching members ..."
  curl -sf -X GET "$vault_uri/api/public/members" \
    -H "Authorization: Bearer $token" \
    | jq '.data // []' \
    || { warn "Could not fetch members — emails will not be resolved."; echo "[]"; }
}

# ─────────────────────────────────────────────────────────────────────────────
# MODULE: REPORTS
# ─────────────────────────────────────────────────────────────────────────────

report_offboarding_exposure() {
  [[ -z "$BitAPI_OFFBOARD_USER_EMAIL" ]] && {
    warn "Skipping offboarding_exposure — set BitAPI_OFFBOARD_USER_EMAIL=user@company.com"
    return
  }

  local f; f=$(out_file "01_offboarding_exposure_${BitAPI_OFFBOARD_USER_EMAIL%%@*}")
  local header="date,event_type,type_label,itemId,collectionId,ipAddress,device,device_label,risk_note"

  local rows
  rows=$(run_jq --arg email "$BitAPI_OFFBOARD_USER_EMAIL" '
    '"$JQ_ID_TO_EMAIL"' |
    ($itoe | to_entries | map(select(.value == $email)) | .[0].key // "") as $uid |
    if $uid == "" then [] else
      [.[] | select(.actingUserId == $uid) |
       select(.type | tostring | test("^(1007|1100|1101|1102|1105|1107|1109|1111|1112|1113)$")) |
       '"$JQ_ENRICH_EVENT"' |
       { date, event_type, type_label, itemId:(.itemId//""),
         collectionId:(.collectionId//""), ipAddress:(.ipAddress//""),
         device, device_label,
         risk_note:(
           if .type==1111 then "ROTATE-password revealed"
           elif .type==1112 then "ROTATE-hidden field revealed"
           elif .type==1113 then "ROTATE-card number revealed"
           elif .type==1007 then "CRITICAL-vault exported"
           elif .type==1102 or .type==1109 then "REVIEW-item deleted"
           else "" end) }]
    end | .[]' \
    | emit_rows "$f" "$header")

  register_report "offboarding_exposure" "$f" "${rows:-0}"
  log "  → ${REPORT_COUNTS[offboarding_exposure]} events for $BitAPI_OFFBOARD_USER_EMAIL"
}

report_dormant_users() {
  local f; f=$(out_file "02_dormant_users")
  local header="email,userId,status,last_login,days_since_login,total_logins,total_events,flag"
  local now_epoch; now_epoch=$(date +%s)
  local cutoff=$(( now_epoch - BitAPI_DORMANT_DAYS * 86400 ))

  local rows
  rows=$(run_jq \
    --argjson cutoff       "$cutoff" \
    --argjson dormant_days "$BitAPI_DORMANT_DAYS" \
    --argjson now          "$now_epoch" '
    (group_by(.actingUserId) | map({
      uid:        .[0].actingUserId,
      last_login: (map(select(.type==1000)) | map(.date) | sort | last // null),
      logins:     (map(select(.type==1000)) | length),
      total:      length
    }) | map({(.uid): .}) | add // {}) as $stats |
    $members[] |
    ($stats[.id] // {last_login:null, logins:0, total:0}) as $s |
    ($s.last_login | '"$JQ_DATE_TO_EPOCH"') as $epoch |
    { email:.email, userId:.id, status:.status,
      last_login:       ($s.last_login // "Never"),
      days_since_login: (if $epoch==0 then "N/A"
                         else (($now - $epoch) / 86400 | floor | tostring) end),
      total_logins:  ($s.logins | tostring),
      total_events:  ($s.total  | tostring),
      flag: (if   $s.logins==0  then "NEVER_LOGGED_IN"
             elif $epoch<$cutoff then "DORMANT_>\($dormant_days)d"
             else "" end) }' \
    | emit_rows "$f" "$header")

  register_report "dormant_users" "$f" "${rows:-0}"
  log "  → ${REPORT_COUNTS[dormant_users]} members assessed"
}

report_security_alerts() {
  local f; f=$(out_file "03_security_alerts")
  local header="date,severity,event_type,type_label,userEmail,actingUserId,ipAddress,device,device_label,itemId"

  local rows
  rows=$(run_jq '
    '"$JQ_ID_TO_EMAIL"' |
    .[] | select(.type | tostring | test("^(1003|1005|1006|1007|1503|1601|1602|1603)$")) |
    '"$JQ_ENRICH_EVENT"' |
    { date,
      severity: (if   .type==1601 then "CRITICAL"
                 elif .type==1007 or .type==1602 then "HIGH"
                 elif .type==1003 or .type==1603 then "MEDIUM"
                 else "LOW" end),
      event_type, type_label,
      userEmail:    ($itoe[.actingUserId // ""] // ""),
      actingUserId: (.actingUserId // ""),
      ipAddress:    (.ipAddress    // ""),
      device, device_label,
      itemId:       (.itemId       // "") }' \
    | emit_rows "$f" "$header")

  register_report "security_alerts" "$f" "${rows:-0}"
  log "  → ${REPORT_COUNTS[security_alerts]} alerts | $CRITICAL_COUNT CRITICAL | $HIGH_COUNT HIGH"
}

report_brute_force_watch() {
  local f; f=$(out_file "04_brute_force_watch")
  local header="scope,identifier,fail_count,plain_fails,2fa_fails,unique_ips_or_users,first_seen,last_seen,ips_or_accounts,flag"

  local rows
  rows=$(run_jq --argjson threshold "$BitAPI_BF_THRESHOLD" '
    '"$JQ_ID_TO_EMAIL"' |
    [.[] | select(.type==1005 or .type==1006)] as $fails |
    (
      ($fails | group_by(.actingUserId)[] |
       { scope: "user",
         identifier:          ($itoe[.[0].actingUserId // ""] // (.[0].actingUserId // "unknown")),
         fail_count:          length,
         plain_fails:         (map(select(.type==1005)) | length),
         "2fa_fails":         (map(select(.type==1006)) | length),
         unique_ips_or_users: ([.[].ipAddress]       | unique | length),
         first_seen:          (map(.date) | sort | first),
         last_seen:           (map(.date) | sort | last),
         ips_or_accounts:     ([.[].ipAddress // "-"] | unique | join("; ")),
         flag: (if length >= $threshold then "ALERT" else "watch" end) }),
      ($fails | group_by(.ipAddress)[] |
       select(([.[].actingUserId] | unique | length) > 1) |
       { scope: "ip",
         identifier:          (.[0].ipAddress // "unknown"),
         fail_count:          length,
         plain_fails:         (map(select(.type==1005)) | length),
         "2fa_fails":         (map(select(.type==1006)) | length),
         unique_ips_or_users: ([.[].actingUserId] | unique | length),
         first_seen:          (map(.date) | sort | first),
         last_seen:           (map(.date) | sort | last),
         ips_or_accounts:     ([.[].actingUserId] | unique | map($itoe[.] // .) | join("; ")),
         flag: "STUFFING_SUSPECT" })
    )' \
    | emit_rows "$f" "$header")

  register_report "brute_force_watch" "$f" "${rows:-0}"
  log "  → ${REPORT_COUNTS[brute_force_watch]} entries"
}

report_after_hours() {
  local f; f=$(out_file "05_after_hours_access")
  local header="date,date_only,hour_utc,event_type,type_label,userEmail,ipAddress,device,device_label,itemId"

  local rows
  rows=$(run_jq \
    --argjson biz_start "$BitAPI_BIZ_HOURS_START" \
    --argjson biz_end   "$BitAPI_BIZ_HOURS_END" '
    '"$JQ_ID_TO_EMAIL"' |
    .[] |
    select(.type==1000 or .type==1107 or .type==1111 or .type==1112 or .type==1113) |
    (.date | split("T")[1] | split(":")[0] | tonumber) as $h |
    select($h < $biz_start or $h >= $biz_end) |
    '"$JQ_ENRICH_EVENT"' |
    { date, date_only: (.date | split("T")[0]), hour_utc: ($h | tostring),
      event_type, type_label,
      userEmail: ($itoe[.actingUserId // ""] // ""),
      ipAddress: (.ipAddress // ""),
      device, device_label,
      itemId:    (.itemId    // "") }' \
    | emit_rows "$f" "$header")

  register_report "after_hours_access" "$f" "${rows:-0}"
  log "  → ${REPORT_COUNTS[after_hours_access]} after-hours events"
}

report_item_access_history() {
  local f; f=$(out_file "06_item_access_history")
  local header="itemId,total_accesses,password_views,hidden_views,card_views,plain_views,unique_users,first_access,last_access,users"

  local rows
  rows=$(run_jq '
    '"$JQ_ID_TO_EMAIL"' |
    [.[] | select(.itemId != null and .itemId != "") |
     select(.type==1107 or .type==1111 or .type==1112 or .type==1113)] |
    group_by(.itemId)[] |
    { itemId:         .[0].itemId,
      total_accesses: length,
      password_views: (map(select(.type==1111)) | length),
      hidden_views:   (map(select(.type==1112)) | length),
      card_views:     (map(select(.type==1113)) | length),
      plain_views:    (map(select(.type==1107)) | length),
      unique_users:   ([.[].actingUserId] | unique | length),
      first_access:   (map(.date) | sort | first),
      last_access:    (map(.date) | sort | last),
      users:          ([.[].actingUserId] | unique | map($itoe[.] // ("uid:"+.)) | join("; ")) }' \
    | emit_rows "$f" "$header")

  register_report "item_access_history" "$f" "${rows:-0}"
  log "  → ${REPORT_COUNTS[item_access_history]} distinct items with access history"
}

report_new_device_logins() {
  local f; f=$(out_file "07_new_device_logins")
  local header="date,userEmail,userId,new_ip,device,device_label,known_ips,flag"

  local rows
  rows=$(run_jq '
    '"$JQ_ID_TO_EMAIL"' |
    [.[] | select(.type==1000)] |
    group_by(.actingUserId)[] | (sort_by(.date)) as $sorted |
    (($sorted | length) / 2 | ceil) as $split |
    ($sorted[:$split] | [.[].ipAddress] | unique) as $known |
    $sorted[$split:][] |
    select(.ipAddress != null) |
    select(.ipAddress | IN($known[]) | not) |
    '"$JQ_ENRICH_EVENT"' |
    { date,
      userEmail: ($itoe[.actingUserId // ""] // ""),
      userId:    (.actingUserId // ""),
      new_ip:    (.ipAddress   // ""),
      device, device_label,
      known_ips: ($known | join("; ")),
      flag:      "NEW_IP" }' \
    | emit_rows "$f" "$header")

  register_report "new_device_logins" "$f" "${rows:-0}"
  log "  → ${REPORT_COUNTS[new_device_logins]} logins from unrecognised IPs"
}

report_license_utilisation() {
  local f; f=$(out_file "08_license_utilisation")
  local header="email,status,total_logins,last_login,category"
  local now_epoch; now_epoch=$(date +%s)
  local cutoff=$(( now_epoch - BitAPI_DORMANT_DAYS * 86400 ))

  local rows
  rows=$(run_jq \
    --argjson cutoff "$cutoff" \
    --argjson now    "$now_epoch" '
    (group_by(.actingUserId) | map({
      uid:        .[0].actingUserId,
      last_login: (map(select(.type==1000)) | map(.date) | sort | last // null),
      logins:     (map(select(.type==1000)) | length)
    }) | map({(.uid): .}) | add // {}) as $stats |
    $members[] |
    ($stats[.id] // {last_login:null, logins:0}) as $s |
    ($s.last_login | '"$JQ_DATE_TO_EPOCH"') as $epoch |
    { email:.email, status:.status,
      total_logins: ($s.logins    | tostring),
      last_login:   ($s.last_login // "Never"),
      category: (if   $s.logins==0  then "NEVER_LOGGED_IN"
                 elif $epoch<$cutoff then "DORMANT"
                 else "ACTIVE" end) }' \
    | emit_rows "$f" "$header")

  register_report "license_utilisation" "$f" "${rows:-0}"
  if [[ "$BitAPI_DRY_RUN" != "true" ]]; then
    local active dormant never
    active=$(grep  -c ",ACTIVE$"          "$f" 2>/dev/null || echo 0)
    dormant=$(grep -c ",DORMANT$"         "$f" 2>/dev/null || echo 0)
    never=$(grep   -c ",NEVER_LOGGED_IN$" "$f" 2>/dev/null || echo 0)
    log "  → active: $active | dormant: $dormant | never logged in: $never"
  fi
}

report_privilege_changes() {
  local f; f=$(out_file "09_privilege_changes")
  local header="date,event_type,type_label,acting_user,acting_user_id,target_user,target_user_id,ipAddress,collectionId,groupId,policyId"

  local rows
  rows=$(run_jq '
    '"$JQ_ID_TO_EMAIL"' |
    .[] |
    select((.type>=1300 and .type<=1302) or (.type>=1400 and .type<=1402) or
           (.type>=1500 and .type<=1504) or (.type>=1600 and .type<=1609) or .type==1700) |
    '"$JQ_ENRICH_EVENT"' |
    { date, event_type, type_label,
      acting_user:    ($itoe[.actingUserId // ""] // ""),
      acting_user_id: (.actingUserId // ""),
      target_user:    ($itoe[.memberId    // ""] // ""),
      target_user_id: (.memberId    // ""),
      ipAddress:      (.ipAddress   // ""),
      collectionId:   (.collectionId // ""),
      groupId:        (.groupId     // ""),
      policyId:       (.policyId    // "") }' \
    | emit_rows "$f" "$header")

  register_report "privilege_changes" "$f" "${rows:-0}"
  log "  → ${REPORT_COUNTS[privilege_changes]} privilege/policy change events"
}

report_raw_events() {
  local f; f=$(out_file "10_raw_events")
  local header="date,type,type_label,actingUserId,userEmail,ipAddress,device,device_label,itemId,collectionId,groupId,policyId,memberId"

  local rows
  rows=$(run_jq '
    '"$JQ_ID_TO_EMAIL"' |
    .[] |
    '"$JQ_ENRICH_EVENT"' |
    { date,
      type:         .event_type,
      type_label,
      actingUserId: (.actingUserId  // ""),
      userEmail:    ($itoe[.actingUserId // ""] // ""),
      ipAddress:    (.ipAddress     // ""),
      device, device_label,
      itemId:       (.itemId        // ""),
      collectionId: (.collectionId  // ""),
      groupId:      (.groupId       // ""),
      policyId:     (.policyId      // ""),
      memberId:     (.memberId      // "") }' \
    | emit_rows "$f" "$header")

  register_report "raw_events" "$f" "${rows:-0}"
  log "  → ${REPORT_COUNTS[raw_events]} total events"
}

# ─────────────────────────────────────────────────────────────────────────────
# MODULE: SCHEDULE HELPER
# ─────────────────────────────────────────────────────────────────────────────
handle_schedule() {
  [[ -z "$BitAPI_SCHEDULE" ]] && return
  local script; script=$(realpath "$0")

  section "Schedule Helper — $BitAPI_SCHEDULE"
  echo ""
  echo "  ── crontab (paste into: crontab -e) ─────────────────────────────"
  echo "  $BitAPI_SCHEDULE BitAPI_CLIENT_ID=\"...\" BitAPI_CLIENT_SECRET=\"...\" $script >> /var/log/bw_reporter.log 2>&1"
  echo ""
  echo "  ── systemd timer: /etc/systemd/system/bw-reporter.timer ─────────"
  printf '[Unit]\nDescription=Bitwarden Event Log Reporter\n\n'
  printf '[Timer]\nOnCalendar=%s\nPersistent=true\n\n' "$BitAPI_SCHEDULE"
  printf '[Install]\nWantedBy=timers.target\n'
  echo ""
  echo "  ── systemd service: /etc/systemd/system/bw-reporter.service ─────"
  printf '[Unit]\nDescription=Bitwarden Event Log Reporter\n\n'
  printf '[Service]\nType=oneshot\n'
  printf 'Environment="BitAPI_CLIENT_ID=..."\nEnvironment="BitAPI_CLIENT_SECRET=..."\n'
  printf 'ExecStart=%s\nStandardOutput=append:/var/log/bw_reporter.log\n' "$script"
  echo ""
  echo "  After saving both files:"
  echo "    sudo systemctl daemon-reload"
  echo "    sudo systemctl enable --now bw-reporter.timer"
  echo "    sudo systemctl list-timers bw-reporter.timer"
  exit 0
}

# ─────────────────────────────────────────────────────────────────────────────
# MODULE: CORE RUN
# ─────────────────────────────────────────────────────────────────────────────
EVENTS=""
MEMBERS=""

run_reports() {
  local vault_uri="$1" org_label="${2:-$(hostname)}"
  debug "run_reports: vault_uri=$vault_uri org_label=$org_label"

  local token; token=$(get_access_token "$vault_uri")
  EVENTS=$(fetch_all_events "$vault_uri" "$token")
  MEMBERS=$(fetch_members    "$vault_uri" "$token")

  [[ "$BitAPI_DRY_RUN" == "true" ]] \
    && section "DRY RUN — preview only, no files written" \
    || section "Generating reports"

  report_enabled "offboarding_exposure" && report_offboarding_exposure
  report_enabled "dormant_users"        && report_dormant_users
  report_enabled "security_alerts"      && report_security_alerts
  report_enabled "brute_force_watch"    && report_brute_force_watch
  report_enabled "after_hours_access"   && report_after_hours
  report_enabled "item_access_history"  && report_item_access_history
  report_enabled "new_device_logins"    && report_new_device_logins
  report_enabled "license_utilisation"  && report_license_utilisation
  report_enabled "privilege_changes"    && report_privilege_changes
  report_enabled "raw_events"           && report_raw_events
}

# ─────────────────────────────────────────────────────────────────────────────
# MODULE: SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
print_summary() {
  local mode_label="Done"
  [[ "$BitAPI_DRY_RUN" == "true" ]] && mode_label="Dry Run — no files written"

  echo ""
  echo "┌──────────────────────────────────────────────────────────────────┐"
  printf "│  %-64s│\n" "Fetch-BitwardenEventLogs — $mode_label"
  echo "├──────────────────────────────────────────────────────────────────┤"
  printf "│  %-42s  %20s  │\n" "Report" "Rows"
  echo "├──────────────────────────────────────────────────────────────────┤"
  for name in "${!REPORT_COUNTS[@]}"; do
    printf "│  %-42s  %20s  │\n" "$name" "${REPORT_COUNTS[$name]}"
  done
  echo "├──────────────────────────────────────────────────────────────────┤"
  printf "│  %-42s  %20s  │\n" "CRITICAL alerts" "$CRITICAL_COUNT"
  printf "│  %-42s  %20s  │\n" "HIGH alerts"     "$HIGH_COUNT"
  echo "├──────────────────────────────────────────────────────────────────┤"
  printf "│  Output : %-55s│\n" "$BitAPI_OUTPUT_DIR"
  [[ -n "$_LOG_FILE" ]] && printf "│  Log    : %-55s│\n" "$_LOG_FILE"
  echo "└──────────────────────────────────────────────────────────────────┘"
}

# ─────────────────────────────────────────────────────────────────────────────
# ENTRYPOINT
# ─────────────────────────────────────────────────────────────────────────────
main() {
  [[ "${1:-}" == "--save-creds" ]] && save_creds

  check_deps
  handle_schedule

  section "Fetch-BitwardenEventLogs.sh v3.2.0"
  log "Region  : $BitAPI_VAULT_REGION"
  log "Reports : $BitAPI_REPORTS"
  log "Dry run : $BitAPI_DRY_RUN"
  [[ -n "$BitAPI_HISTORY_DAYS" ]] && log "Depth   : last $BitAPI_HISTORY_DAYS days"
  [[ -n "$BitAPI_MAX_PAGES"    ]] && log "Depth   : max $BitAPI_MAX_PAGES pages"
  [[ -n "$BitAPI_MAX_EVENTS"   ]] && log "Depth   : max $BitAPI_MAX_EVENTS events"

  resolve_depth

  if [[ -n "$BitAPI_ORGS_FILE" ]]; then
    [[ -f "$BitAPI_ORGS_FILE" ]] || die "BitAPI_ORGS_FILE not found: $BitAPI_ORGS_FILE"
    log "MSP mode — reading $BitAPI_ORGS_FILE"

    while IFS=, read -r org_name org_id org_secret || [[ -n "$org_name" ]]; do
      [[ -z "$org_name" || "$org_name" == \#* ]] && continue

      section "Organisation: $org_name"
      BitAPI_CLIENT_ID="$org_id"
      BitAPI_CLIENT_SECRET="$org_secret"
      local org_dir="${BitAPI_OUTPUT_DIR}/${org_name// /_}"
      mkdir -p "$org_dir"
      BitAPI_OUTPUT_DIR="$org_dir"
      init_log

      local vault_uri; vault_uri=$(resolve_vault_uri)
      run_reports "$vault_uri" "$org_name"
      BitAPI_OUTPUT_DIR=$(dirname "$org_dir")
    done < "$BitAPI_ORGS_FILE"

  else
    resolve_credentials
    mkdir -p "$BitAPI_OUTPUT_DIR"
    init_log

    local vault_uri; vault_uri=$(resolve_vault_uri)
    run_reports "$vault_uri"
  fi

  print_summary
}

main "$@"