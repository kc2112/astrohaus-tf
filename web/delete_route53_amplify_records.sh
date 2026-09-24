#!/bin/bash
set -euo pipefail

ZONE_ID="$1"

if [ -z "$ZONE_ID" ]; then
  echo "ERROR: ZONE_ID is required as first argument."
  exit 1
fi

echo "Cleaning up orphaned ACM validation records in zone: $ZONE_ID"

records=$(aws route53 list-resource-record-sets \
  --hosted-zone-id "$ZONE_ID" \
  --query "ResourceRecordSets[?Type=='CNAME' && contains(Name, '_acm-validations')]" \
  --output json)

count=$(echo "$records" | jq 'length')

if [ "$count" -eq 0 ]; then
  echo "No orphaned ACM validation records found. Nothing to clean up."
  exit 0
fi

echo "Found $count record(s) to delete."

echo "$records" | jq -c '.[]' | while read -r record; do

  name=$(echo "$record" | jq -r '.Name')
  value=$(echo "$record" | jq -r '.ResourceRecords[0].Value')
  ttl=$(echo "$record" | jq -r '.TTL')

  # Skip alias records (no TTL)
  if [ "$ttl" = "null" ]; then
    echo "Skipping alias record: $name (no TTL)"
    continue
  fi

  echo "Deleting record: $name → $value"

  tmpfile=$(mktemp /tmp/delete-record-XXXXXX.json)
  trap "rm -f $tmpfile" EXIT

  cat > "$tmpfile" <<EOF
{
  "Changes": [
    {
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "$name",
        "Type": "CNAME",
        "TTL": $ttl,
        "ResourceRecords": [
          {
            "Value": "$value"
          }
        ]
      }
    }
  ]
}
EOF

  aws route53 change-resource-record-sets \
    --hosted-zone-id "$ZONE_ID" \
    --change-batch "file://$tmpfile"

done

echo "Cleanup complete."
