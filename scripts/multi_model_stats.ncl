; Computes multi-model ensemble statistics (runstyle 3).
;
; Reads the per-simulation cvdp_data master files (created by the diagnostics scripts and
; consolidated by ncfiles.append.ncl) for each experiment/control model pair listed in
; namelist_byvar/namelist_pairing (created by namelist.ncl). Diagnostic fields are placed
; on common grids, the per-model anomaly (experiment minus control) is formed, and
; multi-model statistics are written to <experiment group>_minus_<control group>.cvdp_mmm.nc
; in OUTDIR.
;
; Field classes handled:
;   - 2D rectilinear lat x lon fields          -> bilinear (linint2) to a 1x1 degree grid
;   - 2D curvilinear fields (sea ice, native
;     ocean grid zos etc, identified by their
;     "coordinates" attribute)                 -> ESMF bilinear to the same 1x1 degree grid.
;                                                 The ESMF weights depend only on the grid pair, so
;                                                 they are generated once per (model,role,grid) and
;                                                 cached in a weight file that all of that model's
;                                                 fields on that grid reuse (rcm2rgrid, previously
;                                                 used here, re-searched the grid for every field and
;                                                 dominated the runtime: ~8 s/field vs ~0.04 s here).
;   - 2D lev x lat fields (AMOC)               -> linint2 to a 1 degree x 100 m grid
;   - 1D index/PC timeseries (dim time/TIME)   -> per-model temporal standard deviation
;                                                 (i.e. index amplitude), then cross-model
;                                                 statistics of the amplitude change
;
; Output variables, for each 2D field <var>:
;   <var>_mmm            multi-model mean of the experiment fields
;   <var>_ctl_mmm        multi-model mean of the control fields
;   <var>_anom_mmm       multi-model mean of the per-model anomalies
;   <var>_anom_stddev    cross-model standard deviation of the anomalies
;   <var>_anom_signagree fraction of models whose anomaly sign matches the multi-model mean anomaly
;   <var>_nmods          number of models contributing at each gridpoint
;   <var>_anom_indiv     (optional, mmm_write_individual="True") per-model regridded anomalies
; and for each timeseries <var> (amplitude = temporal standard deviation):
;   <var>_sd_indiv / <var>_sd_ctl_indiv   per-model amplitudes (experiment / control)
;   <var>_sd_mmm / <var>_sd_ctl_mmm       cross-model mean amplitudes
;   <var>_sd_anom_mmm                     cross-model mean amplitude change
;   <var>_sd_anom_stddev                  cross-model spread of the amplitude change
;   <var>_sd_anom_signagree               fraction of models agreeing with the sign of the mean change
;   <var>_sd_nmods                        number of contributing models
;
; Spectra and Hovmoller fields are skipped, and are listed at the end of the run.
;
load "$CVDP_SCRIPTS/functions.ncl"

undef("mmm_sanitize_name")
function mmm_sanitize_name(namein:string)
; replicate the file name sanitization used by the diagnostics scripts and ncfiles.append.ncl
local namein
begin
  return(str_sub_str(str_sub_str(str_sub_str(str_sub_str(str_sub_str(str_strip(namein)," ","_"),"/","_"),"'","_"),"(","_"),")","_"))
end

undef("mmm_standardize")
function mmm_standardize(arrIn:numeric)
; convert to float and standardize the _FillValue to 1.e20
local arrIn,arr
begin
  if (typeof(arrIn).ne."float") then
     arr = tofloat(arrIn)                     ; tofloat converts any _FillValue automatically
     copy_VarCoords(arrIn,arr)
     if (isatt(arrIn,"units")) then
        arr@units = arrIn@units
     end if
     if (isatt(arrIn,"long_name")) then
        arr@long_name = arrIn@long_name
     end if
  else
     arr = arrIn
  end if
  if (.not.isatt(arr,"_FillValue")) then
     if (isatt(arr,"missing_value")) then
        arr@_FillValue = tofloat(arr@missing_value)
     else
        arr@_FillValue = 1.e20
     end if
  end if
  arr@_FillValue = 1.e20                      ; reassigning _FillValue converts existing missing values
  return(arr)
end

undef("mmm_coarse_class")
function mmm_coarse_class(f:file,vn:string)
; Classify a field for stack allocation from metadata only (no data read): returns "ts", "map",
; "levlat" or "none". The rectilinear/curvilinear map distinction and the all-missing check are
; left to mmm_read_field, which reads the data anyway; this just says which stack a variable needs.
local f,vn,dn,rank
begin
  if (.not.isfilevar(f,vn)) then
     return("none")
  end if
  dn = getfilevardims(f,vn)
  if (any(ismissing(dn))) then
     return("none")
  end if
  rank = dimsizes(dn)
  if (rank.eq.1) then
     if (vn.eq.dn(0)) then                     ; coordinate variables (time, TIME, lat, ..) are not diagnostics
        return("none")
     end if
     if (dn(0).ne."time".and.dn(0).ne."TIME") then
        return("none")                         ; spectra (frequency) and other 1D arrays
     end if
     return("ts")
  end if
  if (rank.ne.2) then
     return("none")
  end if
  if (dn(0).eq."lev") then                     ; lev x lat (AMOC)
     return("levlat")
  end if
  return("map")                                ; rank-2 lat/lon or curvilinear map (non-map rank-2 fields,
end                                            ; e.g. Hovmollers, are rejected later by mmm_read_field)

undef("mmm_read_field")
function mmm_read_field(f:file,vn:string)
; Read and classify a field from an already-open cvdp_data master file. Returns the field with
; @valid = True and @class set to one of "map_rect", "map_curv", "levlat" or "ts"
; (standardized _FillValue, south-to-north/upward coordinates, 0:360 longitudes,
; 2D coordinates attached as @lat2d/@lon2d for the curvilinear class).
; Returns with @valid = False if the field is absent, all missing or none of the classes.
local f,vn,ret,dnames,rank,arr,is_curv,coordatt,lat2d,lon2d
begin
  ret = 0
  ret@valid = False
  if (.not.isfilevar(f,vn)) then
     return(ret)
  end if
  dnames = getfilevardims(f,vn)
  if (any(ismissing(dnames))) then
     return(ret)
  end if
  rank = dimsizes(dnames)

  if (rank.eq.1) then                         ; timeseries class
     if (vn.eq.dnames(0)) then                ; coordinate variables (time, TIME, lat, ..) are not diagnostics
        return(ret)
     end if
     if (dnames(0).ne."time".and.dnames(0).ne."TIME") then
        return(ret)                           ; spectra (frequency) and other 1D arrays
     end if
     arr = f->$vn$
     if (all(ismissing(arr))) then
        return(ret)
     end if
     arr := mmm_standardize(arr)
     arr@class = "ts"
     arr@valid = True
     return(arr)
  end if

  if (rank.ne.2) then
     return(ret)
  end if
  arr = f->$vn$
  if (all(ismissing(arr))) then
     return(ret)
  end if

  is_rect = False                             ; rectilinear map class: (lat,lon) dims, or any dim naming whose 1D
  if (iscoord(arr,dnames(0)).and.iscoord(arr,dnames(1))) then   ; coordinates have latitude/longitude units (sea ice fields
     if (dnames(0).eq."lat".and.dnames(1).eq."lon") then        ; on rectilinear grids use j/i and j2/i2 dim names)
        is_rect = True
     else
        c0 := arr&$dnames(0)$
        c1 := arr&$dnames(1)$
        if (isatt(c0,"units").and.isatt(c1,"units")) then
           if (c0@units.eq."degrees_north".and.c1@units.eq."degrees_east") then
              is_rect = True
           end if
        end if
        delete([/c0,c1/])
     end if
  end if
  if (is_rect) then                           ; checked first: many rectilinear fields carry a stray coordinates
     arr := mmm_standardize(arr)              ; attribute (e.g. "time lat lon") that must not send them into the
     arr!0 = "lat"                            ; curvilinear class
     arr!1 = "lon"
     if (arr&lat(0).gt.arr&lat(dimsizes(arr&lat)-1)) then
        arr := arr(::-1,:)
     end if
     if (min(arr&lon).lt.0) then
        arr := lonFlip(arr)
     end if
     arr@class = "map_rect"
     arr@valid = True
     return(arr)
  end if

  if (dnames(0).eq."lev".and.iscoord(arr,"lev").and.iscoord(arr,dnames(1))) then   ; lev x lat class (AMOC; the meridional dim is named lat_amoc)
     arr := mmm_standardize(arr)
     arr!1 = "lat"                            ; standardize the meridional dimension name
     if (arr&lev(0).gt.arr&lev(dimsizes(arr&lev)-1)) then
        arr := arr(::-1,:)
     end if
     if (arr&lat(0).gt.arr&lat(dimsizes(arr&lat)-1)) then
        arr := arr(:,::-1)
     end if
     arr@class = "levlat"
     arr@valid = True
     return(arr)
  end if

  is_curv = False                             ; curvilinear class (sea ice, native ocean grid fields):
  if (isatt(arr,"coordinates")) then          ; coordinates attribute naming the lat2d_*/lon2d_* helper variables
     coordatt = str_split(str_squeeze(arr@coordinates)," ")
     if (dimsizes(coordatt).eq.2) then
        lati = ind(str_match_bool(coordatt,"lat2d"))     ; accept either ordering of the two names
        loni = ind(str_match_bool(coordatt,"lon2d"))
        if (dimsizes(lati).eq.1.and.dimsizes(loni).eq.1) then
           if (.not.(ismissing(lati).or.ismissing(loni))) then
              latname = coordatt(lati)
              lonname = coordatt(loni)
              if (isfilevar(f,latname).and.isfilevar(f,lonname)) then
                 is_curv = True
              end if
           end if
        end if
        delete([/lati,loni/])
     end if
     delete(coordatt)
  end if
  if (is_curv) then
     lat2d = tofloat(f->$latname$)
     lon2d = tofloat(f->$lonname$)
     lon2d = where(lon2d.lt.0,lon2d+360.,lon2d)
     arr := mmm_standardize(arr)
     arr@lat2d = lat2d
     arr@lon2d = lon2d
     arr@class = "map_curv"
     arr@valid = True
     return(arr)
  end if

  return(ret)
end

undef("mmm_wgtname")
function mmm_wgtname(dir:string,tag:string,arr:numeric)
; weight-file path for a curvilinear field, keyed on the caller's tag (group+model+role) and a
; fingerprint of the source grid, so all of a model's fields on one grid share (and reuse) one
; weight file, while different grids never collide. The fingerprint uses the dimension names plus
; the grid shape plus the mean lat/lon: a model's NH (j,i) and SH (j2,i2) ice grids commonly have
; the *same* shape (global tripolar grids) but different coordinates, and must not share weights.
; Returns "" for rectilinear fields, which are regridded with linint2 and need no weight file.
local dir,tag,arr,dm,dn,fp
begin
  if (arr@class.ne."map_curv") then
     return("")
  end if
  dm = dimsizes(arr)
  dn = getvardimnames(arr)
  fp = toint(round((avg(arr@lat2d)+avg(arr@lon2d))*1000.,3))   ; distinguishes grids of equal shape/dim-names
  return(dir+"mmm_wgt_"+tag+"_"+dn(0)+dn(1)+"_"+dm(0)+"x"+dm(1)+"_"+fp+".nc")
end

undef("mmm_regrid_map")
function mmm_regrid_map(arr:numeric,LAT1[*]:numeric,LON1[*]:numeric,wgtfile:string)
; regrid a map-class field to the common lat x lon grid. Rectilinear fields use linint2 (cheap).
; Curvilinear fields use ESMF bilinear: the first field on a given grid generates and writes wgtfile
; (masking out missing source cells), and every later field on that grid reuses the cached weights.
local arr,LAT1,LON1,wgtfile,ro,Opt
begin
  if (arr@class.eq."map_rect") then
     ro = linint2(arr&lon,arr&lat,arr,True,LON1,LAT1,0)
     return(ro)
  end if
  if (isfilepresent2(wgtfile)) then                 ; cached: reuse the weights generated for this grid
     Opt = True
     Opt@NoPETLog = True
     ro = ESMF_regrid_with_weights(arr,wgtfile,Opt)
     return(ro)
  end if
  Opt = True                                        ; first field on this grid: generate + cache the weights
  Opt@SrcGridLat    = arr@lat2d
  Opt@SrcGridLon    = arr@lon2d
  Opt@SrcMask2D     = where(ismissing(arr),0,1)     ; exclude land/missing source cells from the interpolation
  Opt@SrcRegional   = False
  Opt@DstGridType   = "rectilinear"
  Opt@DstGridLat    = LAT1
  Opt@DstGridLon    = LON1
  Opt@InterpMethod  = "bilinear"
  Opt@ForceOverwrite = True
  Opt@SrcFileName   = wgtfile+".src.nc"             ; transient SCRIP descriptions, removed after generation
  Opt@DstFileName   = wgtfile+".dst.nc"
  Opt@WgtFileName   = wgtfile                        ; kept for reuse by the rest of this grid's fields
  Opt@RemoveSrcFile = True
  Opt@RemoveDstFile = True
  Opt@NoPETLog      = True
  ro = ESMF_regrid(arr,Opt)
  return(ro)
end

undef("mmm_write_stats")
procedure mmm_write_stats(z:file,vn:string,stack_exp[*][*][*]:float,stack_ctl[*][*][*]:float, \
                          validp[*]:logical,vunits:string,vlong:string,do_signcheck[1]:logical, \
                          cwgt[*]:numeric,expgrp:string,ctlgrp:string,write_indiv[1]:logical, \
                          model_list:string)
; compute and write cross-model statistics for stacked (model x n1 x n2) fields
local FILLV,vind,refpat,hh,pcor,pairvalid,stack_anom,mmm_exp,mmm_ctl,mmm_anom,sd_anom,nmods, \
      npos,nneg,condv,fnm,nagree,sa,d1,d2,vno
begin
  FILLV = stack_exp@_FillValue

  if (do_signcheck) then                     ; guard against arbitrary EOF sign differences between models
     vind = ind(validp)
     refpat = stack_exp(vind(0),:,:)
     do hh = 0,dimsizes(vind)-1
        pcor = pattern_cor(refpat,stack_exp(vind(hh),:,:),cwgt,0)
        if (.not.ismissing(pcor).and.pcor.lt.0) then
           stack_exp(vind(hh),:,:) = stack_exp(vind(hh),:,:)*(-1.)
        end if
        pcor = pattern_cor(refpat,stack_ctl(vind(hh),:,:),cwgt,0)
        if (.not.ismissing(pcor).and.pcor.lt.0) then
           stack_ctl(vind(hh),:,:) = stack_ctl(vind(hh),:,:)*(-1.)
        end if
     end do
     delete([/vind,refpat/])
  end if

  pairvalid = .not.(ismissing(stack_exp).or.ismissing(stack_ctl))   ; a model contributes at a gridpoint only if both its
  stack_exp = mask(stack_exp,pairvalid,True)                        ; experiment and control fields are valid there, so that
  stack_ctl = mask(stack_ctl,pairvalid,True)                        ; every statistic uses the same paired sample of models

  stack_anom = stack_exp                     ; copies coordinates/metadata
  stack_anom = (/ stack_exp - stack_ctl /)   ; anomaly computed model-by-model, then averaged below
                                             ; (the MMM anomaly is the average of the anomalies, not the anomaly of the averages)

  mmm_exp  = dim_avg_n_Wrap(stack_exp,0)
  mmm_ctl  = dim_avg_n_Wrap(stack_ctl,0)
  mmm_anom = dim_avg_n_Wrap(stack_anom,0)
  sd_anom  = dim_stddev_n_Wrap(stack_anom,0)

  d1 = stack_exp!1
  d2 = stack_exp!2
  nmods = dim_num_n(.not.ismissing(stack_anom),0)
  nmods!0 = d1
  nmods&$d1$ = stack_exp&$d1$
  nmods!1 = d2
  nmods&$d2$ = stack_exp&$d2$

  npos = dim_num_n(stack_anom.gt.0,0)
  nneg = dim_num_n(stack_anom.lt.0,0)
  condv = mmm_anom                           ; sign of the multi-model mean anomaly (0 treated as positive)
  condv = where(ismissing(condv),0.,condv)
  fnm = tofloat(nmods)
  fnm@_FillValue = FILLV
  fnm = where(fnm.lt.2,fnm@_FillValue,fnm)
  nagree = tofloat(where(condv.ge.0,npos,nneg))
  nagree@_FillValue = FILLV
  sa = mmm_anom
  sa = (/ nagree / fnm /)

  mmm_exp  = mask(mmm_exp, nmods.ge.2,True)  ; require at least 2 contributing models everywhere
  mmm_ctl  = mask(mmm_ctl, nmods.ge.2,True)
  mmm_anom = mask(mmm_anom,nmods.ge.2,True)
  sd_anom  = mask(sd_anom, nmods.ge.2,True)

  mmm_exp@units = vunits
  mmm_exp@long_name = vlong+" (multi-model mean, "+expgrp+")"
  mmm_ctl@units = vunits
  mmm_ctl@long_name = vlong+" (multi-model mean, "+ctlgrp+")"
  mmm_anom@units = vunits
  mmm_anom@long_name = vlong+" (multi-model mean anomaly, "+expgrp+" minus "+ctlgrp+")"
  mmm_anom@note = "average of the per-model anomalies (each anomaly computed model-by-model before averaging); as all statistics use the same paired sample of models at each gridpoint, this also equals "+vn+"_mmm minus "+vn+"_ctl_mmm"
  sd_anom@units = vunits
  sd_anom@long_name = vlong+" (cross-model standard deviation of anomalies)"
  sa@units = "1"
  sa@long_name = vlong+" (fraction of models whose anomaly sign matches the multi-model mean anomaly)"
  nmods@units = "1"
  nmods@long_name = vlong+" (number of models contributing)"

  vno = vn+"_mmm"
  z->$vno$ = mmm_exp
  vno = vn+"_ctl_mmm"
  z->$vno$ = mmm_ctl
  vno = vn+"_anom_mmm"
  z->$vno$ = mmm_anom
  vno = vn+"_anom_stddev"
  z->$vno$ = sd_anom
  vno = vn+"_anom_signagree"
  z->$vno$ = sa
  vno = vn+"_nmods"
  z->$vno$ = nmods
  if (write_indiv) then
     stack_anom@units = vunits
     stack_anom@long_name = vlong+" (per-model anomalies, "+expgrp+" minus "+ctlgrp+")"
     stack_anom@model_names = model_list
     stack_anom@note = "model dimension ordered as in the model_names attribute; models without valid data are all missing"
     vno = vn+"_anom_indiv"
     z->$vno$ = stack_anom
  end if
end

begin
  print("Starting: multi_model_stats.ncl")
  OUTDIR       = getenv("OUTDIR")
  VERSION      = getenv("VERSION")
  CTL_GROUP    = getenv("CONTROL_GROUP")
  WRITE_INDIV  = False
  if (.not.ismissing(getenv("MMM_WRITE_INDIV"))) then
     WRITE_INDIV = getenv("MMM_WRITE_INDIV").eq."True"
  end if

  if (.not.isfilepresent2("namelist_byvar/namelist_pairing")) then
     print("multi_model_stats.ncl: namelist_byvar/namelist_pairing not found. Exiting.")
     exit
  end if
  npair_all = numAsciiRow("namelist_byvar/namelist_pairing")
  na = asciiread("namelist_byvar/namelist_pairing",(/npair_all/),"string")
  delim = "|"
  modelkey = str_strip(str_get_field(na,1,delim))
  expgroup = str_strip(str_get_field(na,2,delim))
  expname  = str_strip(str_get_field(na,3,delim))
  expsyear = toint(str_strip(str_get_field(na,4,delim)))
  expeyear = toint(str_strip(str_get_field(na,5,delim)))
  ctlname  = str_strip(str_get_field(na,6,delim))
  ctlsyear = toint(str_strip(str_get_field(na,7,delim)))
  ctleyear = toint(str_strip(str_get_field(na,8,delim)))
  delete(na)

  FILLV = 1.e20
  nlat = 180                               ; common 1x1 degree analysis grid
  nlon = 360
  LAT1 = fspan(-89.5,89.5,nlat)
  LAT1!0 = "lat"
  LAT1&lat = LAT1
  LAT1@units = "degrees_north"
  LAT1@long_name = "latitude"
  LON1 = fspan(0.5,359.5,nlon)
  LON1!0 = "lon"
  LON1&lon = LON1
  LON1@units = "degrees_east"
  LON1@long_name = "longitude"
  nlev = 51                                ; common lev x lat grid for AMOC-type fields (100 m x 1 degree)
  LEV1 = fspan(0.,5000.,nlev)
  LEV1!0 = "lev"
  LEV1&lev = LEV1
  LEV1@units = "m"
  LEV1@positive = "down"
  LEV1@long_name = "depth"

  rad = 0.01745329
  cwgt = cos(rad*LAT1)                     ; latitude weights for pattern correlations

  eof_prefixes = (/"nao_pattern","nam_pattern","sam_pattern","psa1_pattern","psa2_pattern", \
                   "pna_pattern","npo_pattern","pdv_pattern","ipo_pattern"/)   ; EOF-based patterns whose sign is arbitrary

  groups = get_unique_values(expgroup)
  mmm_group = getenv("MMM_GROUP")                    ; optional: restrict to one experiment group so groups
  if (.not.ismissing(mmm_group)) then                ; can be processed in parallel (one process per group,
     if (mmm_group.ne."") then                       ; launched by driver.ncl). Each group writes its own
        if (ismissing(ind(groups.eq.mmm_group))) then ; output and weight files, so parallel runs do not collide.
           print("multi_model_stats.ncl: MMM_GROUP="+mmm_group+" is not an experiment group in namelist_pairing. Exiting.")
           exit
        end if
        groups := (/mmm_group/)
     end if
  end if
  do gg = 0,dimsizes(groups)-1
     gind := ind(expgroup.eq.groups(gg))
     npair = dimsizes(gind)
     if (npair.lt.2) then
        print("multi_model_stats.ncl: Fewer than 2 model pairs in experiment group "+groups(gg)+", no multi-model statistics possible. Skipping group.")
        continue
     end if
     expfile := OUTDIR+mmm_sanitize_name(expname(gind))+".cvdp_data."+expsyear(gind)+"-"+expeyear(gind)+".nc"
     ctlfile := OUTDIR+mmm_sanitize_name(ctlname(gind))+".cvdp_data."+ctlsyear(gind)+"-"+ctleyear(gind)+".nc"
     exp_present := new(npair,logical)
     ctl_present := new(npair,logical)
     do hh = 0,npair-1
        exp_present(hh) = isfilepresent2(expfile(hh))
        ctl_present(hh) = isfilepresent2(ctlfile(hh))
        if (.not.exp_present(hh)) then
           print("multi_model_stats.ncl: Warning: "+expfile(hh)+" not found. "+modelkey(gind(hh))+" will not contribute to the "+groups(gg)+" multi-model statistics.")
        end if
        if (.not.ctl_present(hh)) then
           print("multi_model_stats.ncl: Warning: "+ctlfile(hh)+" not found. "+modelkey(gind(hh))+" will not contribute to the "+groups(gg)+" multi-model statistics.")
        end if
     end do
     model_list = str_join(modelkey(gind),", ")

     if (isvar("fexp")) then                    ; open each present master file exactly once for this group
        delete(fexp)                            ; (mmm_read_field is called ~2*npair times per variable, so
     end if                                     ; reopening per call would be thousands of opens per group)
     if (isvar("fctl")) then
        delete(fctl)
     end if
     exp_slot := new(npair,integer)             ; exp_slot(hh) = index of pair hh's file within fexp, or -1 if absent
     exp_slot = -1                              ; (assign -1 rather than using it as _FillValue, so the value is
     ctl_slot := new(npair,integer)             ;  a real -1 and the .lt.0 tests below never see a missing value)
     ctl_slot = -1
     pe := ind(exp_present)
     pc := ind(ctl_present)
     if (.not.all(ismissing(pe))) then
        fexp = addfiles(expfile(pe),"r")
        do kk = 0,dimsizes(pe)-1
           exp_slot(pe(kk)) = kk
        end do
     end if
     if (.not.all(ismissing(pc))) then
        fctl = addfiles(ctlfile(pc),"r")
        do kk = 0,dimsizes(pc)-1
           ctl_slot(pc(kk)) = kk
        end do
     end if

     vnames_all := new(1,string)           ; union of variable names across all master files of this group
     if (.not.all(ismissing(pe))) then
        do kk = 0,dimsizes(pe)-1
           vnames_all := array_append_record(vnames_all,getfilevarnames(fexp[kk]),0)
        end do
     end if
     if (.not.all(ismissing(pc))) then
        do kk = 0,dimsizes(pc)-1
           vnames_all := array_append_record(vnames_all,getfilevarnames(fctl[kk]),0)
        end do
     end if
     if (all(ismissing(vnames_all))) then
        print("multi_model_stats.ncl: No cvdp_data master files found for experiment group "+groups(gg)+". Skipping group.")
        continue
     end if
     vnames := get_unique_values(vnames_all(ind(.not.ismissing(vnames_all))))

     ofile = OUTDIR+mmm_sanitize_name(groups(gg))+"_minus_"+mmm_sanitize_name(CTL_GROUP)+".cvdp_mmm.nc"
     if (isfilepresent2(ofile)) then
        system("rm "+ofile)
     end if
     z = addfile(ofile,"c")
     z@source = "NCAR Climate Analysis Section's Climate Variability Diagnostics Package v"+VERSION
     z@notes = "Multi-model statistics for experiment group "+groups(gg)+" minus control group "+CTL_GROUP+", computed from per-simulation CVDP output regridded to common grids"
     z@experiment_group = groups(gg)
     z@control_group = CTL_GROUP
     z@models_used = model_list
     z@model_pairs = str_join(modelkey(gind)+": "+expname(gind)+" ("+expsyear(gind)+"-"+expeyear(gind)+") minus "+ctlname(gind)+" ("+ctlsyear(gind)+"-"+ctleyear(gind)+")","; ")
     z@Conventions = "CF-1.6"

     nproc = 0
     skipped := new(dimsizes(vnames),string)
     nskip = 0
     do vv = 0,dimsizes(vnames)-1
        vn = vnames(vv)
        if (str_match_bool(vn,"lat2d_").or.str_match_bool(vn,"lon2d_")) then
           continue                        ; 2D coordinate helper variables, not diagnostics
        end if

        vclass = "none"                    ; classify (metadata only) from the first experiment file that has it
        do hh = 0,npair-1
           if (exp_slot(hh).lt.0) then
              continue
           end if
           vclass = mmm_coarse_class(fexp[exp_slot(hh)],vn)
           if (vclass.ne."none") then
              break
           end if
        end do
        if (vclass.eq."none") then
           skipped(nskip) = vn
           nskip = nskip+1
           continue
        end if

;------- timeseries class: cross-model statistics of the index amplitude (temporal stddev)
        if (vclass.eq."ts") then
           sde := new(npair,"float",FILLV)
           sdc := new(npair,"float",FILLV)
           vunits = ""
           vlong = vn
           got_meta = False
           do hh = 0,npair-1
              if (exp_slot(hh).lt.0.or.ctl_slot(hh).lt.0) then
                 continue
              end if
              ae := mmm_read_field(fexp[exp_slot(hh)],vn)
              if (.not.ae@valid) then
                 continue
              end if
              if (ae@class.ne."ts") then
                 continue
              end if
              ac := mmm_read_field(fctl[ctl_slot(hh)],vn)
              if (.not.ac@valid) then
                 continue
              end if
              if (ac@class.ne."ts") then
                 continue
              end if
              sde(hh) = tofloat(stddev(ae))
              sdc(hh) = tofloat(stddev(ac))
              if (.not.got_meta) then
                 if (isatt(ae,"units")) then
                    vunits = ae@units
                 end if
                 if (isatt(ae,"long_name")) then
                    vlong = ae@long_name
                 end if
                 got_meta = True
              end if
           end do
           dan := sde - sdc
           nm = num(.not.ismissing(dan))
           if (nm.lt.2) then
              skipped(nskip) = vn
              nskip = nskip+1
              continue
           end if
           anom_mmm = avg(dan)
           npos = num(dan.gt.0)
           nneg = num(dan.lt.0)
           if (anom_mmm.ge.0) then
              saval = tofloat(npos)/tofloat(nm)
           else
              saval = tofloat(nneg)/tofloat(nm)
           end if

           sde!0 = "model"
           sde@units = vunits
           sde@long_name = vlong+" (per-model amplitude = temporal standard deviation, "+groups(gg)+")"
           sde@model_names = model_list
           sdc!0 = "model"
           sdc@units = vunits
           sdc@long_name = vlong+" (per-model amplitude = temporal standard deviation, "+CTL_GROUP+")"
           sdc@model_names = model_list
           vno = vn+"_sd_indiv"
           z->$vno$ = sde
           vno = vn+"_sd_ctl_indiv"
           z->$vno$ = sdc

           out = avg(sde)
           out@units = vunits
           out@long_name = vlong+" (cross-model mean amplitude, "+groups(gg)+")"
           vno = vn+"_sd_mmm"
           z->$vno$ = out
           out = avg(sdc)
           out@long_name = vlong+" (cross-model mean amplitude, "+CTL_GROUP+")"
           vno = vn+"_sd_ctl_mmm"
           z->$vno$ = out
           out = anom_mmm
           out@long_name = vlong+" (cross-model mean amplitude change, "+groups(gg)+" minus "+CTL_GROUP+")"
           out@note = "average of the per-model amplitude changes (each change computed model-by-model before averaging)"
           vno = vn+"_sd_anom_mmm"
           z->$vno$ = out
           delete(out@note)
           out = tofloat(stddev(dan))
           out@long_name = vlong+" (cross-model spread of the amplitude change)"
           vno = vn+"_sd_anom_stddev"
           z->$vno$ = out
           out = saval
           out@units = "1"
           out@long_name = vlong+" (fraction of models whose amplitude change sign matches the cross-model mean change)"
           vno = vn+"_sd_anom_signagree"
           z->$vno$ = out
           outi = nm
           outi@units = "1"
           outi@long_name = vlong+" (number of models contributing)"
           vno = vn+"_sd_nmods"
           z->$vno$ = outi
           delete([/out,outi/])
           nproc = nproc+1
           continue
        end if

;------- gridded classes: stack on the common grid, then shared cross-model statistics
        if (vclass.eq."map") then
           stack_exp := new((/npair,nlat,nlon/),"float",FILLV)
           stack_exp!1 = "lat"
           stack_exp&lat = LAT1
           stack_exp!2 = "lon"
           stack_exp&lon = LON1
        else                                ; levlat
           stack_exp := new((/npair,nlev,nlat/),"float",FILLV)
           stack_exp!1 = "lev"
           stack_exp&lev = LEV1
           stack_exp!2 = "lat"
           stack_exp&lat = LAT1
        end if
        stack_exp!0 = "model"
        stack_ctl := stack_exp
        validp := new(npair,logical)
        validp = False
        vunits = ""
        vlong = vn
        got_meta = False
        do hh = 0,npair-1
           if (exp_slot(hh).lt.0.or.ctl_slot(hh).lt.0) then
              continue
           end if
           ae := mmm_read_field(fexp[exp_slot(hh)],vn)
           if (.not.ae@valid) then
              continue
           end if
           ac := mmm_read_field(fctl[ctl_slot(hh)],vn)
           if (.not.ac@valid) then
              continue
           end if
           if (vclass.eq."map") then
              if (.not.(ae@class.eq."map_rect".or.ae@class.eq."map_curv")) then
                 continue
              end if
              if (.not.(ac@class.eq."map_rect".or.ac@class.eq."map_curv")) then
                 continue
              end if
              wtag := mmm_sanitize_name(groups(gg))+"_"+hh   ; weight files are keyed per group+model+role+grid
              re := mmm_regrid_map(ae,LAT1,LON1,mmm_wgtname(OUTDIR,wtag+"_exp",ae))
              rc := mmm_regrid_map(ac,LAT1,LON1,mmm_wgtname(OUTDIR,wtag+"_ctl",ac))
           else
              if (ae@class.ne."levlat".or.ac@class.ne."levlat") then
                 continue
              end if
              re := linint2(ae&lat,ae&lev,ae,False,LAT1,LEV1,0)
              rc := linint2(ac&lat,ac&lev,ac,False,LAT1,LEV1,0)
           end if
           stack_exp(hh,:,:) = (/ re /)
           stack_ctl(hh,:,:) = (/ rc /)
           validp(hh) = True
           if (.not.got_meta) then
              if (isatt(ae,"units")) then
                 vunits = ae@units
              end if
              if (isatt(ae,"long_name")) then
                 vlong = ae@long_name
              end if
              got_meta = True
           end if
        end do
        if (num(validp).lt.2) then
           skipped(nskip) = vn
           nskip = nskip+1
           continue
        end if

        is_eofpat = False
        if (vclass.eq."map") then
           do pp = 0,dimsizes(eof_prefixes)-1
              if (str_match_bool_ic(vn,eof_prefixes(pp))) then
                 is_eofpat = True
              end if
           end do
        end if

        mmm_write_stats(z,vn,stack_exp,stack_ctl,validp,vunits,vlong,is_eofpat,cwgt, \
                        groups(gg),CTL_GROUP,WRITE_INDIV,model_list)
        nproc = nproc+1
     end do
     delete(z)
     system("rm -f "+OUTDIR+"mmm_wgt_"+mmm_sanitize_name(groups(gg))+"_*")   ; discard this group's cached regrid weights

     print("multi_model_stats.ncl: "+groups(gg)+" minus "+CTL_GROUP+": wrote multi-model statistics for "+nproc+" fields from up to "+npair+" model pairs to "+ofile)
     if (nskip.ge.1) then
        print("multi_model_stats.ncl: skipped "+nskip+" fields (spectra/Hovmollers/other unsupported shapes, or valid for fewer than 2 model pairs): "+str_join(skipped(:nskip-1),", "))
     end if
  end do
  print("Finished: multi_model_stats.ncl")
end
