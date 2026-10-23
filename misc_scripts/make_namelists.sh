#!/bin/bash
# Build CVDP run directories (namelist + driver.ncl) from the curated ESGF replica.
#
# The replica is laid out as <replica>/<model>/<experiment>/*.nc, with the year range
# at the end of each filename (..._YYYYMM-YYYYMM.nc). This holds for CMIP5, CMIP6 and
# CMIP7 alike, so no knowledge of the ESGF directory structure is needed here.
#
# Usage: make_namelists.sh -o OUTROOT [options]
#   -o OUTROOT   where to create the run directories (required)
#   -g MODE      "experiment" (default): one run per experiment, OUTROOT/<expt>/
#                "model":                one run per model,      OUTROOT/<model>/
#   -e "LIST"    experiments to include (default: $DEFAULT_EXPTS below)
#   -m "LIST"    models to include (default: every model directory in the replica)
#   -r DIR       replica location (default: /data/oacd/curated_ESGF_replica)
#   -t FILE      driver.ncl to use as a template (default: driver.ncl in this repo)
#   -z DIR       zp, the CVDP scripts directory written into the driver
#                (default: /data/oacd/CVDP/v6.1/CVDP-ncl/scripts/)
#   -f           overwrite an existing namelist/driver.ncl (default: refuse)
#
# Year range: the overlap of the atmospheric variables (ts, tas, psl, pr) present for
# that simulation, since CVDP sets a variable to all-missing if its files do not cover
# the requested years. Ocean/ice variables that do not cover the overlap are reported
# but do not shorten it. 0-byte files are skipped with a warning; gaps between files
# are reported. The namelist is a starting point - review it (and choose analysis
# windows) before running.

set -u

REPLICA_DIR="/data/oacd/curated_ESGF_replica"
CVDP_REPO=$(cd "$(dirname "$0")/.." && pwd)
TEMPLATE="$CVDP_REPO/driver.ncl"
ZP="/data/oacd/CVDP/v6.1/CVDP-ncl/scripts/"
GROUP="experiment"
OUTROOT=""
FORCE=0
DEFAULT_EXPTS="piControl abrupt4xCO2 1pctCO2 historical lgm lgm-cal-adj midHolocene midHolocene-cal-adj lig127k lig127k-cal-adj abrupt-127k midPliocene-eoi400 past1000 rcp26 rcp85 ssp126 ssp585"
EXPTS="$DEFAULT_EXPTS"
MODELS=""

ATM_VARS="ts tas psl pr"
OTHER_VARS="tos siconc siconca sic msftmz msftmyz msftyz zos snd"

while getopts "o:g:e:m:r:t:z:f" opt; do
  case $opt in
    o) OUTROOT=$OPTARG ;;
    g) GROUP=$OPTARG ;;
    e) EXPTS=$OPTARG ;;
    m) MODELS=$OPTARG ;;
    r) REPLICA_DIR=$OPTARG ;;
    t) TEMPLATE=$OPTARG ;;
    z) ZP=$OPTARG ;;
    f) FORCE=1 ;;
    *) sed -n '2,25p' "$0"; exit 1 ;;
  esac
done
if [ -z "$OUTROOT" ]; then sed -n '2,25p' "$0"; exit 1; fi
if [ "$GROUP" != "experiment" ] && [ "$GROUP" != "model" ]; then
  echo "-g must be 'experiment' or 'model'"; exit 1
fi
[ -f "$TEMPLATE" ] || { echo "Template driver $TEMPLATE not found"; exit 1; }
[ -z "$MODELS" ] && MODELS=$(cd "$REPLICA_DIR" && ls -d */ | tr -d / | grep -vx superceded)

# CMIP5 and CMIP6/7 spell some experiments differently; treat them as one experiment.
expt_aliases() {
  case $1 in
    abrupt4xCO2|abrupt-4xCO2) echo "abrupt4xCO2 abrupt-4xCO2" ;;
    *) echo "$1" ;;
  esac
}

warn() { echo "  WARNING: $*" >&2; }

# Echo "start end" (years) for variable $2 in directory $1, or nothing if no files.
# Files are taken in date order; a gap between consecutive files is reported.
var_span() {
  local dir=$1 var=$2 f yrs s e start="" end=""
  for f in $(ls "$dir" 2>/dev/null | grep -E "^${var}_.*_[0-9]+-[0-9]+\.nc$" | \
             awk -F_ '{print $NF" "$0}' | sort -n | cut -d' ' -f2); do
    if [ ! -s "$dir/$f" ]; then warn "skipping empty file $dir/$f"; continue; fi
    yrs=${f##*_}; yrs=${yrs%.nc}
    s=${yrs%-*}; e=${yrs#*-}
    s=$((10#${s:0:${#s}-2})); e=$((10#${e:0:${#e}-2}))   # strip MM, drop leading zeros
    if [ -z "$start" ]; then
      start=$s
    elif [ $s -gt $((end+1)) ]; then
      warn "$var in $dir has a gap: $((end+1))-$((s-1)) missing"
    fi
    end=$e
  done
  [ -n "$start" ] && echo "$start $end"
}

# Echo the namelist line for model $1 / experiment directory $2, or nothing (with a warning).
namelist_line() {
  local model=$1 dir=$2 expt=$3 var span s e start=-1 end=999999 used=""
  for var in $ATM_VARS; do
    span=$(var_span "$dir" $var) || true
    [ -z "$span" ] && continue
    read s e <<< "$span"
    [ $s -gt $start ] && start=$s
    [ $e -lt $end ] && end=$e
    used="$used $var:$s-$e"
  done
  if [ -z "$used" ]; then warn "$model $expt: no ts/tas/psl/pr files, skipped"; return; fi
  if [ $((end-start+1)) -lt 10 ]; then
    warn "$model $expt: atmospheric variables overlap for <10 years ($used ), skipped"; return
  fi
  # report variables whose span is not the overlap
  for var in $ATM_VARS $OTHER_VARS; do
    span=$(var_span "$dir" $var 2>/dev/null) || true
    [ -z "$span" ] && continue
    read s e <<< "$span"
    if [ $s -gt $start ] || [ $e -lt $end ]; then
      warn "$model $expt: $var covers only $s-$e, will be missing in CVDP for $start-$end"
    elif [ $s -lt $start ] || [ $e -gt $end ]; then
      echo "  note: $model $expt: $var covers $s-$e, trimmed to $start-$end" >&2
    fi
  done
  echo "${model}_${expt} | $dir/ | $start | $end"
}

# Copy the template driver into $1, pointing it at that directory; $2 is the title,
# $3 the experiment (used to pick a climatology), or "" for a multi-experiment run.
make_driver() {
  local out=$1 title=$2 expt=$3
  sed -e "s#^\(  outdir *= *\)\"[^\"]*\"#\1\"$out/\"#" \
      -e "s#^\(  webpage_title *= *\)\"[^\"]*\"#\1\"$title\"#" \
      -e "s#^\(  ensemble_mean_dir *= *\)\"[^\"]*\"#\1\"$out/CVDP-EM_ncl/\"#" \
      -e "s#^\(  zp *= *\)\"[^\"]*\"#\1\"$ZP\"#" \
      "$TEMPLATE" > "$out/driver.ncl"
  # Transient experiments: climatology from the final 30 years (or a fixed window for scenarios)
  local cs="" ce=""
  case $expt in
    abrupt4xCO2|1pctCO2) cs=-30; ce=0 ;;
    rcp85|rcp26|ssp585|ssp126) cs=2070; ce=2099 ;;
  esac
  if [ -n "$cs" ]; then
    sed -i -e "s#^\(  opt_climo *= *\)\"[^\"]*\"#\1\"Custom\"#" \
           -e "s#^\(  climo_syear *= *\)-*[0-9]*#\1$cs#" \
           -e "s#^\(  climo_eyear *= *\)-*[0-9]*#\1$ce#" "$out/driver.ncl"
  fi
}

# Set up run directory $1 from namelist lines on stdin
write_run() {
  local out=$1 title=$2 expt=$3 lines
  lines=$(cat)
  if [ -z "$lines" ]; then echo "  no simulations, nothing written"; return; fi
  if [ $FORCE -eq 0 ] && { [ -e "$out/namelist" ] || [ -e "$out/driver.ncl" ]; }; then
    echo "  $out already has a namelist/driver.ncl, not overwriting (use -f)"; return
  fi
  mkdir -p "$out"
  echo "$lines" > "$out/namelist"
  make_driver "$out" "$title" "$expt"
  echo "  wrote $out/namelist ($(echo "$lines" | wc -l) simulations) and driver.ncl"
}

if [ "$GROUP" = "experiment" ]; then
  for expt in $EXPTS; do
    echo "== $expt"
    for model in $MODELS; do
      for alias in $(expt_aliases $expt); do
        [ -d "$REPLICA_DIR/$model/$alias" ] && namelist_line $model "$REPLICA_DIR/$model/$alias" $expt
      done
    done | write_run "$OUTROOT/$expt" "$expt" "$expt"
  done
else
  for model in $MODELS; do
    echo "== $model"
    for expt in $EXPTS; do
      for alias in $(expt_aliases $expt); do
        [ -d "$REPLICA_DIR/$model/$alias" ] && namelist_line $model "$REPLICA_DIR/$model/$alias" $expt
      done
    done | write_run "$OUTROOT/$model" "$model" ""
  done
fi

echo
echo "Review each namelist, then run from its directory, e.g.:"
echo "  cd $OUTROOT/<run> && setsid ncl -n driver.ncl </dev/null >out.log 2>&1 &"
