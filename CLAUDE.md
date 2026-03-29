# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

CVDP-ncl is a palaeoclimate fork of NCAR's Climate Variability Diagnostics Package (CVDP v6.1.0). It analyzes major modes of climate variability (ENSO, PDO, AMO, NAM, NAO, etc.) from CMIP-format model output and observations, producing graphics and NetCDF output organized into HTML webpages. The primary language is NCL (NCAR Command Language); Python is used only for the parallel task runner.

## Running the Package

```bash
# Standard run (foreground)
ncl driver.ncl

# Background run with log
ncl driver.ncl >&! out.log &

# Run only specific diagnostic scripts (set modular = "True" and modular_list in driver.ncl first)
ncl driver.ncl
```

There is no build/compile step. NCL scripts are interpreted directly.

## Configuration

All user settings are at the top of `driver.ncl`:

| Setting | Purpose |
|---|---|
| `runstyle` | 1 = individual simulations, 2 = ensemble mode |
| `outdir` | Output directory (must end in `/`) |
| `zp` | Path to the NCL scripts directory (must end in `/`) |
| `opt_climo` | `"Full"` = use full simulation period; `"Custom"` = use `climo_syear`/`climo_eyear` |
| `modular` / `modular_list` | Run a subset of diagnostic scripts |
| `max_num_tasks` | Number of parallel NCL processes |
| `namelists_only` | Set `"True"` to only generate `namelist_byvar/` files for inspection |

## Namelist Format

**`namelist`** (model simulations, pipe-delimited):
- Style 1 (runstyle=1): `SimName | /path/to/files/*.nc | start_year | end_year`
- Style 2 (runstyle=2): `SimName | /path/to/files/*.nc | start_year | end_year | ensemble_group`

**`namelist_obs`** (observations, pipe-delimited):
`VARIABLE | DatasetName | /path/to/file.nc | start_year | end_year`

Valid variables: `TS`, `PSL`, `TREFHT`, `PRECT`, `aice_nh`, `aice_sh`, `MOC`, `SSH`

## Architecture and Execution Flow

1. **`driver.ncl`** sets all configuration, exports environment variables, and orchestrates execution
2. **`scripts/namelist.ncl`** reads `namelist` + `namelist_obs` and writes per-variable namelists to `namelist_byvar/`
3. **`scripts/runTasks.py`** launches diagnostic scripts in parallel (up to `max_num_tasks` at once), polling every 15 seconds
4. Each diagnostic script in `scripts/` reads its variable namelist from `namelist_byvar/`, computes indices/patterns, writes `.nc` and image files to `outdir`
5. **`scripts/metrics.ncl`** and **`scripts/ncfiles.append.ncl`** aggregate results
6. **`scripts/webpage1.ncl`** or `webpage2.ncl` generates the HTML output

All diagnostic scripts receive configuration via environment variables (`OUTDIR`, `OPT_CLIMO`, `CLIMO_SYEAR`, `CLIMO_EYEAR`, etc.) set by `driver.ncl`.

## Script Directory Structure

- **`scripts/`** — All NCL diagnostic scripts and the Python task runner. This is what `zp` should point to.
- **`ncl_scripts/`** — Modified/development versions of a subset of scripts (`amoc.ncl`, `functions.ncl`, `pr.mean_stddev.ncl`). These are custom edits not yet in `scripts/`.
- **`misc_scripts/`** — Bash/shell utilities for ESGF data management and auto-generating namelists from curated data replicas.

## Diagnostic Scripts in `scripts/`

**Mode scripts** (compute EOF/regression patterns and timeseries):
`amm`, `amv`, `atl3`, `iod`, `ipv`, `monsoon`, `nam`, `nao`, `pdv`, `pna_npo`, `sam_psa`, `soi`

**Variable scripts** (mean/stddev, trends, timeseries by variable):
`{var}.mean_stddev.ncl`, `{var}.trends_timeseries.ncl`, `{var}.indices.ncl`
where `{var}` ∈ `sst`, `tas`, `pr`, `psl`, `siconc`, `zos`

**Support scripts**: `functions.ncl` (shared utility functions), `namelist.ncl`, `data_check_regrid.ncl`, `ensemble_mean.calc.ncl`, `metrics.ncl`, `ncfiles.append.ncl`, `webpage1.ncl`, `webpage2.ncl`

## Key Functions in `functions.ncl`

- `data_read_in(path, varname, yearS, yearE)` — Reads CMIP-style files, handles multiple variable name aliases (e.g., `TS`/`ts`/`sst`/`tos`), combines `PRECC+PRECL` for precip
- `check_custom_climo(...)` — Validates and applies custom climatological period
- `create_empty_array(...)` — Creates a missing-value placeholder array when data is absent

## Palaeoclimate-Specific Additions (vs. upstream NCAR CVDP)

- `opt_climo = "Custom"` with negative year offsets (e.g., `climo_syear = -30` means 30 years before simulation end)
- `scripts/amm.ncl` — Atlantic Meridional Mode
- `scripts/atl3.ncl` — Atlantic Niño (ATL3)
- `scripts/monsoon.ncl` — Global Monsoon Domain
- `scripts/extract_all_AR6_regions.ncl` — IPCC AR6 regional averages (uses `AR6_masks_1x1.nc`)
- Extended IOD diagnostics with additional regression patterns
- `misc_scripts/` — Scripts to curate ESGF replicas and generate namelists for palaeoclimate experiments
