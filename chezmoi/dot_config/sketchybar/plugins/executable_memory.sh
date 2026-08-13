#!/usr/bin/env bash

# Memory usage percentage via vm_stat + physical memory size.
PAGE_SIZE=$(vm_stat | awk '/page size of/ {print $8}')
[ -z "$PAGE_SIZE" ] && PAGE_SIZE=4096

TOTAL_BYTES=$(sysctl -n hw.memsize)

read -r ACTIVE WIRED COMPRESSED < <(vm_stat | awk '
  /Pages active/       {a=$3}
  /Pages wired down/   {w=$4}
  /Pages occupied by compressor/ {c=$5}
  END {gsub(/\./,"",a); gsub(/\./,"",w); gsub(/\./,"",c); print a, w, c}
')

USED_BYTES=$(( (ACTIVE + WIRED + COMPRESSED) * PAGE_SIZE ))
PERC=$(( USED_BYTES * 100 / TOTAL_BYTES ))

sketchybar --set "$NAME" label="${PERC}%"
