#!/usr/bin/env bash
zramctl --bytes --noheadings -o DISKSIZE,DATA,ALGORITHM 2>/dev/null | awk '
function hum(b,   j) {
  j = 1
  while (b >= 1024 && j < 5) { b /= 1024; j++ }
  return (j == 1) ? sprintf("%dB", b) : sprintf("%.1f%s", b, u[j])
}
BEGIN { split("B KiB MiB GiB TiB", u, " ") }
NR == 1 {
  size = $1; data = $2; algo = $3
  pct = (size > 0) ? data / size * 100 : 0
  w = 12
  f = int(pct * w / 100 + 0.5)
  if (f > w) f = w
  bar = "\033[36m"
  for (i = 0; i < f; i++) bar = bar "━"
  bar = bar "\033[90m"
  for (i = f; i < w; i++) bar = bar "─"
  bar = bar "\033[0m"
  printf "%s %s / %s · %s", bar, hum(data), hum(size), algo
  printf "\n"
}'
