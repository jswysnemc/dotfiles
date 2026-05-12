#!/usr/bin/env bash
awk '
function hum(b,   j) {
  j = 1
  while (b >= 1024 && j < 5) { b /= 1024; j++ }
  return (j == 1) ? sprintf("%dB", b) : sprintf("%.1f%s", b, u[j])
}
BEGIN { split("B KiB MiB GiB TiB", u, " ") }
/^Filename/ { next }
$1 !~ /zram/ {
  name = $1; sub("/dev/", "", name)
  size = $3 * 1024; used = $4 * 1024; prio = $5
  pct = (size > 0) ? used / size * 100 : 0
  w = 12
  f = int(pct * w / 100 + 0.5)
  if (f > w) f = w
  bar = "\033[36m"
  for (i = 0; i < f; i++) bar = bar "━"
  bar = bar "\033[90m"
  for (i = f; i < w; i++) bar = bar "─"
  bar = bar "\033[0m"
  printf "%s %s / %s · %s · prio=%s\n", bar, hum(used), hum(size), name, prio
  exit
}' /proc/swaps
