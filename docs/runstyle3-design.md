# Runstyle 3 — Multi-Model Ensemble Mode: design notes

Added July 2026 (UCL). Implements a third run style for PMIP-style multi-model science
(as in the Climate of the Past NAO paper, https://cp.copernicus.org/articles/22/689/2026/):
many different models run the same experiment; each model's experiment is paired with its
own piControl; diagnostics are regridded to a common 1°×1° grid; per-model anomalies
(experiment − piControl) are averaged into a multi-model mean (MMM), with cross-model
standard deviation and sign-agreement (two-thirds stippling threshold) alongside.

## Context

CVDP v6.1.0 supports runstyle 1 (individual simulations) and runstyle 2 (single-model
initial-condition ensembles). Runstyle 2's ensemble mean/spread machinery sums arrays
directly across members (e.g. `arr_store(hh,:,:) = (/arr/)` in `scripts/sst.mean_stddev.ncl`),
which assumes all members share one grid — false for multi-model input, so those code paths
must be bypassed, not reused.

Design decisions:
- Anomaly computation happens **inside** CVDP (paired control per model, via the namelist).
- Fixed 1°×1° target grid (`fspan(-89.5,89.5,180)` × `fspan(0.5,359.5,360)`).
- Priority outputs are **netCDF files** (MMM, spread, sign-agreement); graphics/webpages
  are inherited from the individual-simulation mode.
- `rmEM`/`rmGMST_EM` detrending is forbidden in runstyle 3 (`ensemble_mean.calc.ncl`
  sums members across grids; supporting it would need a full regridding branch).

## Architecture

Run the 34 diagnostic scripts **unchanged, in individual-simulation mode**, and do all
multi-model work in one post-processing script that reads the per-simulation `cvdp_data`
master files.

Zero-touch trick: for runstyle 3, `scripts/namelist.ncl` writes the `namelist_byvar/*`
files with runstyle-1 style tags (`-N-Individual Simulation`, decrementing; obs keep
`0-Observations`). All diagnostic scripts then see `nEM = max(EM_num) = 0` and take their
well-tested individual-mode path. Pairing metadata goes in a separate file
`namelist_byvar/namelist_pairing`, consumed only by `scripts/multi_model_stats.ncl`:

```
modelkey | exp_group | exp_simname | exp_syear | exp_eyear | ctl_simname | ctl_syear | ctl_eyear
```

Only `scripts/namelist.ncl` and `scripts/metrics.ncl` branch on the `RUNSTYLE` env var;
every other script keys off the namelist tags, which is why this works without touching
the diagnostics.

## Namelist convention

5-column format kept; 5th column = `<group number>-<GroupName>` where **group = experiment**
(group numbers sequential from 1, shared by all rows of a group). New **6th column: pairing
key (model name)**. Diagnostic scripts and `ncfiles.append.ncl` only read fields 1–5, so the
6th column is invisible to them.

```
CESM2_midHolocene        | /data/CESM2/midHolocene/        |    1 |  700 | 1-midHolocene | CESM2
IPSL-CM6A-LR_midHolocene | /data/IPSL-CM6A-LR/midHolocene/ | 1850 | 2399 | 1-midHolocene | IPSL-CM6A-LR
MRI-ESM2-0_midHolocene   | /data/MRI-ESM2-0/midHolocene/   | 1851 | 2050 | 1-midHolocene | MRI-ESM2-0
CESM2_piControl          | /data/CESM2/piControl/          |    1 | 1200 | 2-piControl   | CESM2
IPSL-CM6A-LR_piControl   | /data/IPSL-CM6A-LR/piControl/   | 1850 | 3049 | 2-piControl   | IPSL-CM6A-LR
MRI-ESM2-0_piControl     | /data/MRI-ESM2-0/piControl/     | 1850 | 2550 | 2-piControl   | MRI-ESM2-0
```

Rules: pairing key unique within a group; every non-control row needs a partner in the
control group (**warn-and-drop**, so one missing piControl doesn't kill a 30-model run);
multiple experiment groups vs one control group allowed (one output file per experiment
group); year spans may differ freely across rows (the runstyle-2 equal-span truncation is
disabled for runstyle 3 — paleo simulations have arbitrary calendars and lengths).

## What was changed

- `driver.ncl` — accepts `runstyle = 3`; new options `control_group_name`,
  `mmm_write_individual`; exports `CONTROL_GROUP`/`MMM_WRITE_INDIV`; forbids rmEM/rmGMST_EM
  for runstyle 3; calls `multi_model_stats.ncl` after `ncfiles.append.ncl`; uses
  `webpage1.ncl` for runstyle 3. A later addition, `mmm_webpages_only = "True"`, reruns
  only the multi-model statistics/figures and the webpages from a previously completed
  run's output (the diagnostics, metrics and consolidation stages are skipped, and
  `image_finalize` is restricted to the regenerated `mmm.*` figures).
- `scripts/namelist.ncl` — 6th-column parsing; span-check relaxation; validation
  (exactly one group matches `CONTROL_GROUP`, pairing keys unique per group, warn-and-drop
  unpaired models); writes `namelist_byvar/namelist_pairing`; relabels model rows with
  individual-simulation tags.
- `scripts/metrics.ncl` — line-648 guard changed from `RUNSTYLE.ne."1"` to
  `RUNSTYLE.eq."2"` (no ensemble-mean metrics table in runstyle 3).
- `scripts/multi_model_stats.ncl` (new) — the multi-model statistics engine (see header
  comment in the script for the output variable list).
- `scripts/multi_model_graphics.ncl` (new, phase 2) — 4-panel MMM figures + a simple
  HTML index page; called from driver.ncl when `create_graphics = "True"`, before
  `image_finalize` so the images get trimmed/watermarked like all others.
- `scripts/ncfiles.append.ncl` — no change needed (reads fields 1–5 only; its `_EM`
  consolidation block finds no `_EM` files and skips harmlessly).
- `README.md` — user-facing documentation.

## multi_model_stats.ncl behaviour

- Variable list = union of `getfilevarnames()` across all master files of a group,
  matched by name; a variable is processed if valid for ≥ 2 model pairs. Each field is
  classified by shape into one of four classes (spectra, Hovmöllers and other shapes are
  skipped with a summary printed; `lat2d_*`/`lon2d_*` helper variables are ignored):
  - **map, rectilinear** (2-D, 1-D `lat`/`lon` coords, no `coordinates` attribute):
    bilinear `linint2` (cyclic) to the 1°×1° grid.
  - **map, curvilinear** (2-D with a `coordinates` attribute naming `lat2d_*`/`lon2d_*`
    helpers in the same file — sea ice, native-ocean-grid zos etc.): `rcm2rgrid` to the
    same 1°×1° grid. `rcm2rgrid` was chosen over ESMF regridding because it is built into
    NCL (no external install, no weight files) and mirrors how CVDP itself carries 2-D
    coordinates around; longitudes are normalized to 0–360 first.
  - **lev×lat** (AMOC): `linint2` (non-cyclic, x=lat, y=lev) to a common 1° × 100 m grid
    (`lev = fspan(0,5000,51)` m). Assumes depths in metres, as CVDP standardizes.
  - **timeseries** (1-D, dim `time`/`TIME` — index and PC series such as `nino34`,
    `nao_timeseries_djf`): the per-model *amplitude* (temporal standard deviation — the
    paper's NAO amplitude metric) is computed for experiment and control, and cross-model
    statistics of the amplitude change are written as scalars plus per-model `(model)`
    arrays. Coordinate variables themselves (`time`, `TIME`, …) are excluded.
- Per model pair: standardize `_FillValue` (1e20), force south-to-north latitudes /
  upward-increasing depths and 0–360 longitudes, regrid, difference, stack. A pair
  contributes only if the field is valid on both sides and of the same class.
- **The MMM anomaly is the average of the per-model anomalies, not the anomaly of the
  averages** (matching the paper's method). Additionally, a model contributes at a
  gridpoint only if both its experiment and control fields are valid there, so `_mmm`,
  `_ctl_mmm` and `_anom_mmm` all use the same paired sample — which makes
  `_anom_mmm = _mmm − _ctl_mmm` hold exactly, and the two definitions coincide. The same
  applies to the timeseries amplitude changes (per-model change first, then averaged).
  Recorded in a `note` attribute on the output variables.
- EOF sign guard: `*_pattern_*` fields of NAO/NAM/SAM/PSA/PNA/NPO/PDV/IPO are sign-checked
  (cos-lat-weighted `pattern_cor` vs the first valid model) and flipped if anticorrelated,
  so arbitrary EOF signs cannot cancel in the MMM. (The diagnostics apply per-simulation
  sign conventions, e.g. nao.ncl forces the Iceland node negative, so this rarely fires.)
- Statistics masked where fewer than 2 models contribute; `<var>_nmods` documents
  per-gridpoint coverage (models whose grid stops short of ±90° contribute missing at the
  pole rows — no extrapolation; `rcm2rgrid` can leave small gaps on target points not
  enclosed by source cells, likewise documented by `_nmods`).
- Output: `<ExpGroup>_minus_<CtlGroup>.cvdp_mmm.nc` in OUTDIR containing, per gridded
  variable: `_mmm`, `_ctl_mmm`, `_anom_mmm`, `_anom_stddev`, `_anom_signagree` (fraction
  agreeing with the MMM anomaly sign; stipple at ≥ 2/3), `_nmods`, and optionally
  `_anom_indiv` (per-model stacks, `mmm_write_individual = "True"`); per timeseries
  variable: `_sd_indiv`, `_sd_ctl_indiv`, `_sd_mmm`, `_sd_ctl_mmm`, `_sd_anom_mmm`,
  `_sd_anom_stddev`, `_sd_anom_signagree`, `_sd_nmods`.

## multi_model_graphics.ncl behaviour (phase 2)

For each `.cvdp_mmm.nc` file and each lat×lon `<var>_anom_mmm`, a 2×2 panel figure
`mmm.<ExpGroup>_minus_<CtlGroup>.<var>.png`: experiment MMM and control MMM (shared
levels), MMM anomaly with pattern-17 stippling where `_anom_signagree ≥ 2/3`
(via `gsn_contour_shade` on a single 0.667 contour), and the cross-model standard
deviation. A plain HTML table `<ExpGroup>_minus_<CtlGroup>.mmm.html` links all figures
and the netCDF file. lev×lat fields and scalar index statistics are not plotted.

## Verification (run on the cluster; NCL is not installed on the Windows machine)

1. **Namelist stage**: 3-model namelist (midHolocene + piControl), `runstyle=3`,
   `namelists_only="True"`. Check: `namelist_byvar/namelist_ts` model rows end in
   `-1-Individual Simulation` (decrementing), obs rows `0-Observations`;
   `namelist_byvar/namelist_pairing` has 3 correct rows; removing one piControl row
   produces the warn-and-drop message; unequal year spans produce no truncation message.
2. **Diagnostics stage**: `modular="True"`, `modular_list="sst.mean_stddev,nao,psl.mean_stddev"`.
   Expect 6 per-sim `*.cvdp_data.*.nc` master files, `metrics.txt` but no `metrics_EM.txt`,
   no crash.
3. **MMM stage**: `ncdump -h midHolocene_minus_piControl.cvdp_mmm.nc` — dims lat=180/lon=360
   (and lev=51 if AMOC data present); variables
   `sst_spatialmean_ann_{mmm,anom_mmm,anom_stddev,anom_signagree,nmods}`,
   `nao_pattern_djf_*`; `nmods` in {0..3} (=3 over open ocean); `signagree` within [0,1];
   spot-check one gridpoint's `anom_mmm` against a manual recompute from two per-sim files.
4. **Phase 2 outputs** (same file): `amoc_mean_ann_anom_mmm` on (lev,lat);
   `aice_nh_spatialmean_ann_anom_mmm` on the 1×1 grid (curvilinear source, values only
   poleward of ~30°N); scalar `nino34_sd_anom_mmm` / `nao_timeseries_djf_sd_anom_mmm` and
   per-model `nino34_sd_indiv(model)` — cross-check one model's value against
   `stddev(nino34)` computed directly from its cvdp_data file; no `time`/`TIME` variables
   were treated as diagnostics; spectra/Hovmöller names appear in the skipped list.
5. **Graphics stage** (`create_graphics="True"`): `mmm.midHolocene_minus_piControl.<var>.png`
   4-panel figures exist and are watermarked/trimmed like other CVDP images; stippling in
   panel (c) appears only where `_anom_signagree ≥ 2/3`;
   `midHolocene_minus_piControl.mmm.html` opens and links every figure.
6. **Degenerate cases**: 2-model run (stddev still defined); one model missing a variable
   (still produced, `nmods=2`); a variable rectilinear in one model and curvilinear in
   another (e.g. zos) still combines; rerun idempotency (output file is deleted and
   recreated).

## Phase 2 (implemented)

Added in the same development cycle: cross-model amplitude statistics for index/PC
timeseries, AMOC lev×lat fields via 2-D interpolation, curvilinear sea-ice/zos fields via
`rcm2rgrid` (chosen over ESMF — see above), and MMM graphics + HTML index page
(`scripts/multi_model_graphics.ncl`).

Remaining ideas (phase 3): cross-model statistics for power spectra and Hovmöllers,
lev×lat (AMOC) figures, integrating the MMM page into the main CVDP webpages, and a
significance test (e.g. t-test of the anomaly against the cross-model spread) alongside
the sign-agreement field.
