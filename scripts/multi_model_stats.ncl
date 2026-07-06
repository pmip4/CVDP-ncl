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
;     "coordinates" attribute)                 -> rcm2rgrid to the same 1x1 degree grid
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

undef("mmm_read_field")
function mmm_read_field(fn:string,vn:string)
; Read and classify a field from a cvdp_data master file. Returns the field with
; @valid = True and @class set to one of "map_rect", "map_curv", "levlat" or "ts"
; (standardized _FillValue, south-to-north/upward coordinates, 0:360 longitudes,
; 2D coordinates attached as @lat2d/@lon2d for the curvilinear class).
; Returns with @valid = False if the field is absent, all missing or none of the classes.
local fn,vn,ret,f,dnames,rank,arr,is_curv,coordatt,lat2d,lon2d
begin
  ret = 0
  ret@valid = False
  if (.not.isfilepresent2(fn)) then
     return(ret)
  end if
  f = addfile(fn,"r")
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

  is_curv = False
  if (isatt(arr,"coordinates")) then
     if (.not.(str_squeeze(arr@coordinates).eq."")) then   ; some data have coordinates incorrectly set to ""
        is_curv = True
     end if
  end if
  if (is_curv) then                           ; curvilinear class (sea ice, native ocean grid fields)
     coordatt = str_split(arr@coordinates," ")
     if (dimsizes(coordatt).ne.2) then
        return(ret)
     end if
     if (.not.(isfilevar(f,coordatt(0)).and.isfilevar(f,coordatt(1)))) then
        return(ret)
     end if
     lat2d = tofloat(f->$coordatt(0)$)
     lon2d = tofloat(f->$coordatt(1)$)
     lon2d = where(lon2d.lt.0,lon2d+360.,lon2d)
     arr := mmm_standardize(arr)
     arr@lat2d = lat2d
     arr@lon2d = lon2d
     arr@class = "map_curv"
     arr@valid = True
     return(arr)
  end if

  if (dnames(0).eq."lat".and.dnames(1).eq."lon") then      ; rectilinear map class
     if (.not.(iscoord(arr,"lat").and.iscoord(arr,"lon"))) then
        return(ret)
     end if
     arr := mmm_standardize(arr)
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

  if (dnames(0).eq."lev".and.dnames(1).eq."lat") then      ; lev x lat class (AMOC)
     if (.not.(iscoord(arr,"lev").and.iscoord(arr,"lat"))) then
        return(ret)
     end if
     arr := mmm_standardize(arr)
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

  return(ret)
end

undef("mmm_regrid_map")
function mmm_regrid_map(arr:numeric,LAT1[*]:numeric,LON1[*]:numeric)
; regrid a map-class field (rectilinear or curvilinear) to the common lat x lon grid
local arr,LAT1,LON1,ro
begin
  if (arr@class.eq."map_rect") then
     ro = linint2(arr&lon,arr&lat,arr,True,LON1,LAT1,0)
  else
     ro = rcm2rgrid(arr@lat2d,arr@lon2d,arr,LAT1,LON1,0)
  end if
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
  do gg = 0,dimsizes(groups)-1
     gind := ind(expgroup.eq.groups(gg))
     npair = dimsizes(gind)
     if (npair.lt.2) then
        print("multi_model_stats.ncl: Fewer than 2 model pairs in experiment group "+groups(gg)+", no multi-model statistics possible. Skipping group.")
        continue
     end if
     expfile := OUTDIR+mmm_sanitize_name(expname(gind))+".cvdp_data."+expsyear(gind)+"-"+expeyear(gind)+".nc"
     ctlfile := OUTDIR+mmm_sanitize_name(ctlname(gind))+".cvdp_data."+ctlsyear(gind)+"-"+ctleyear(gind)+".nc"
     do hh = 0,npair-1
        if (.not.isfilepresent2(expfile(hh))) then
           print("multi_model_stats.ncl: Warning: "+expfile(hh)+" not found. "+modelkey(gind(hh))+" will not contribute to the "+groups(gg)+" multi-model statistics.")
        end if
        if (.not.isfilepresent2(ctlfile(hh))) then
           print("multi_model_stats.ncl: Warning: "+ctlfile(hh)+" not found. "+modelkey(gind(hh))+" will not contribute to the "+groups(gg)+" multi-model statistics.")
        end if
     end do
     model_list = str_join(modelkey(gind),", ")

     vnames_all := new(1,string)           ; union of variable names across all master files of this group
     do hh = 0,npair-1
        if (isfilepresent2(expfile(hh))) then
           f = addfile(expfile(hh),"r")
           vnames_all := array_append_record(vnames_all,getfilevarnames(f),0)
           delete(f)
        end if
        if (isfilepresent2(ctlfile(hh))) then
           f = addfile(ctlfile(hh),"r")
           vnames_all := array_append_record(vnames_all,getfilevarnames(f),0)
           delete(f)
        end if
     end do
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

        vclass = "none"                    ; classify from the first valid experiment field
        do hh = 0,npair-1
           at := mmm_read_field(expfile(hh),vn)
           if (at@valid) then
              vclass = at@class
              break
           end if
        end do
        if (vclass.eq."none") then
           skipped(nskip) = vn
           nskip = nskip+1
           continue
        end if
        if (vclass.eq."map_rect".or.vclass.eq."map_curv") then
           vclass = "map"
        end if

;------- timeseries class: cross-model statistics of the index amplitude (temporal stddev)
        if (vclass.eq."ts") then
           sde := new(npair,"float",FILLV)
           sdc := new(npair,"float",FILLV)
           vunits = ""
           vlong = vn
           got_meta = False
           do hh = 0,npair-1
              ae := mmm_read_field(expfile(hh),vn)
              if (.not.ae@valid) then
                 continue
              end if
              if (ae@class.ne."ts") then
                 continue
              end if
              ac := mmm_read_field(ctlfile(hh),vn)
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
           ae := mmm_read_field(expfile(hh),vn)
           if (.not.ae@valid) then
              continue
           end if
           ac := mmm_read_field(ctlfile(hh),vn)
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
              re := mmm_regrid_map(ae,LAT1,LON1)
              rc := mmm_regrid_map(ac,LAT1,LON1)
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

     print("multi_model_stats.ncl: "+groups(gg)+" minus "+CTL_GROUP+": wrote multi-model statistics for "+nproc+" fields from up to "+npair+" model pairs to "+ofile)
     if (nskip.ge.1) then
        print("multi_model_stats.ncl: skipped "+nskip+" fields (spectra/Hovmollers/other unsupported shapes, or valid for fewer than 2 model pairs): "+str_join(skipped(:nskip-1),", "))
     end if
  end do
  print("Finished: multi_model_stats.ncl")
end
