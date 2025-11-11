#!/usr/bin/env bash
set -euo pipefail

# Convert dotted-quad IP to integer
ip_to_int() {
  local a b c d
  IFS=. read -r a b c d <<< "$1"
  echo "$((a << 24 | b << 16 | c << 8 | d))"
}

# Convert integer back to dotted-quad
int_to_ip() {
  local num=$1
  echo "$((num >> 24 & 255)).$((num >> 16 & 255)).$((num >> 8 & 255)).$((num & 255))"
}

# Extract IP portion from CIDR (drop /mask)
extract_ip_from_cidr() {
  echo "${1%/*}"
}

max_ip_int=0
largest_cidr=""

# Find the CIDR with the highest base IP among args
for cidr in "$@"; do
  current_ip="$(extract_ip_from_cidr "$cidr")"
  current_ip_int="$(ip_to_int "$current_ip")"
  if (( current_ip_int > max_ip_int )); then
    max_ip_int="$current_ip_int"
    largest_cidr="$cidr"
  fi
done

# If there were no prior CIDRs, default to something sensible.
# You can change the default prefix below if you want.
if [[ -z "${largest_cidr}" ]]; then
  largest_cidr="10.0.0.0/16"
fi

ip="${largest_cidr%/*}"
prefix="${largest_cidr#*/}"

# Size of block, increment by the block size, then convert back
total_ips=$((1 << (32 - prefix)))
ip_int="$(ip_to_int "$ip")"
next_ip_int=$((ip_int + total_ips))
next_ip="$(int_to_ip "$next_ip_int")"
next_cidr="${next_ip}/${prefix}"

cat <<EOF
{
  "largest": "$largest_cidr",
  "next": "$next_cidr"
}
EOF