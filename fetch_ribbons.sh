#!/usr/bin/env bash
# Copy the DZVP-relaxed dry ribbons (relaxed.xyz + sp.out) from a finished cp2k_v2 checkout into ribbons_relaxed/.
#   bash fetch_ribbons.sh [path/to/cp2k_v2]      (default: ../cp2k_v2)
src="${1:-../cp2k_v2}"
cd "$(dirname "${BASH_SOURCE[0]}")"
ok=0
for rib in rib_y_o00_si rib_y_o00_al rib_x_o00_si; do
  d="$src/runs/$rib"
  if [[ -f "$d/relaxed.xyz" && -f "$d/sp.out" ]]; then
    mkdir -p "ribbons_relaxed/$rib"; cp "$d/relaxed.xyz" "$d/sp.out" "ribbons_relaxed/$rib/"; echo "copied $rib"; ok=$((ok + 1))
  else
    echo "MISSING $rib in $src/runs (relaxed.xyz and sp.out are written when its job has finished)" >&2
  fi
done
echo "$ok of 3 ribbons ready"
