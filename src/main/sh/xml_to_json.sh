#!/usr/bin/env bash
# xml_to_json.sh – robust XML → JSON converter for ENTSO-E-style docs
# Usage: ./xml_to_json.sh input.xml > output.json

set -euo pipefail
IFS=$'\n\t'

if [ "${1:-}" = "" ]; then
  echo "Usage: $0 input.xml"
  exit 1
fi

INPUT="$1"

command -v xmlstarlet >/dev/null 2>&1 || { echo >&2 "xmlstarlet is required."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo >&2 "jq is required."; exit 1; }

# Namespace from your sample
NS="urn:iec62325.351:tc57wg16:451-3:publicationdocument:7:3"

# Helper: single value extraction
xget() {
  xmlstarlet sel -N ns="$NS" -t -v "$1" -n "$INPUT" | head -n1
}

# Document-level fields
doc_mRID=$(xget "/ns:Publication_MarketDocument/ns:mRID")
doc_rev=$(xget "/ns:Publication_MarketDocument/ns:revisionNumber")
doc_type=$(xget "/ns:Publication_MarketDocument/ns:type")
doc_created=$(xget "/ns:Publication_MarketDocument/ns:createdDateTime")
doc_pstart=$(xget "/ns:Publication_MarketDocument/ns:period.timeInterval/ns:start")
doc_pend=$(xget "/ns:Publication_MarketDocument/ns:period.timeInterval/ns:end")

# Normalize revision
if [[ "$doc_rev" =~ ^[0-9]+$ ]]; then
  rev_json="$doc_rev"
else
  # represent non-numeric revision as string (or null if empty)
  if [[ -z "$doc_rev" ]]; then
    rev_json="null"
  else
    rev_json=$(jq -Rn --arg v "$doc_rev" '$v')
  fi
fi

doc_json=$(jq -n \
  --arg mRID "$doc_mRID" \
  --arg type "$doc_type" \
  --arg created "$doc_created" \
  --arg pstart "$doc_pstart" \
  --arg pend "$doc_pend" \
  --argjson rev "$rev_json" \
  '{mRID:$mRID, revisionNumber:$rev, type:$type, createdDateTime:$created, periodStart:$pstart, periodEnd:$pend}')

# Collect TimeSeries ids
mapfile -t ts_ids < <(xmlstarlet sel -N ns="$NS" -t -m "//ns:TimeSeries" -v "ns:mRID" -n "$INPUT")

# Start empty array for timeseries
ts_array_json="[]"
#
# <currency_Unit.name>EUR</currency_Unit.name>
# <price_Measure_Unit.name>MWH</price_Measure_Unit.name>
# <curveType>A03</curveType>
#
for ts_id in "${ts_ids[@]}"; do

  ts_curr=$(xmlstarlet sel -N ns="$NS" -t -v "//ns:TimeSeries[ns:mRID='$ts_id']/ns:currency_Unit.name" -n "$INPUT")
  ts_price=$(xmlstarlet sel -N ns="$NS" -t -v "//ns:TimeSeries[ns:mRID='$ts_id']/ns:price_Measure_Unit.name" -n "$INPUT")

  ts_curve=$(xmlstarlet sel -N ns="$NS" -t -v "//ns:TimeSeries[ns:mRID='$ts_id']/ns:curveType" -n "$INPUT")

  ts_start=$(xmlstarlet sel -N ns="$NS" -t -v "//ns:TimeSeries[ns:mRID='$ts_id']/ns:Period/ns:timeInterval/ns:start" -n "$INPUT")
  ts_end=$(xmlstarlet sel -N ns="$NS" -t -v "//ns:TimeSeries[ns:mRID='$ts_id']/ns:Period/ns:timeInterval/ns:end" -n "$INPUT")

  # Produce lines "pos|price" (one per point) using xmlstarlet.
  # If there are no matching Point nodes this will produce zero lines.
  mapfile -t pos_price_lines < <(
    xmlstarlet sel -N ns="$NS" -t \
      -m "//ns:TimeSeries[ns:mRID='$ts_id']/ns:Period/ns:Point" \
      -v "concat(ns:position,'|',ns:price.amount)" -n "$INPUT"
  )

  # Build points_json robustly:
  if [ "${#pos_price_lines[@]}" -eq 0 ]; then
    points_json="[]"
  else
    # join lines with newline and let jq parse each line into object safely:
    points_json=$(printf "%s\n" "${pos_price_lines[@]}" | \
      jq -R -s '
        (split("\n") | map(select(length > 0))) as $lines |
        $lines
        | map(
            split("|") |
            { position: (.[0] | tonumber), price: (.[1] | tonumber) }
          )
      ')
    # points_json is now a JSON array (string) suitable for --argjson
  fi

  # Build ts object using --argjson for points
  ts_obj=$(jq -n \
    --arg id "$ts_id" \
    --arg start "$ts_start" \
    --arg end "$ts_end" \
    --arg currency "$ts_curr" \
    --arg price "$ts_price" \
    --arg curve "$ts_curve" \
    --argjson points "$points_json" \
    '{id:$id, start:$start, end:$end, currency:$currency, price:$price, curve:$curve, points:$points}')

  # Append ts_obj to ts_array_json (both are JSON)
  ts_array_json=$(jq -n --argjson arr "$ts_array_json" --argjson obj "$ts_obj" '$arr + [$obj]')
done

# Final output (pretty-printed)
jq -n --argjson doc "$doc_json" --argjson ts "$ts_array_json" '{Document:$doc, TimeSeries:$ts}' | jq -c .

