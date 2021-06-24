;This file contains a function that will extract and compute an area statistic for an AR5 region (either mean or stddev)
; It uses predetermined 1x1o regions and landsea masks
; I've found that using the shapefiles is pretty slow
;   and NCL's sophistication of using great circles means you actually cut out the wrong areas.
; This script actually computes all the of regions, but only returns one of them. 

;This script is run with as part of the CVDP via the pr.indices.ncl and tas.indices.ncl routines
;  It can potentially be run elsewhere using the commands below, 
;  but only if AR5_masks_1x1.nc is in the NCL directory
;
;  load "extract_single_AR5_region.ncl"
;  f=addfile("your_filename.nc","r")
;  variable=f->tas ;if your variable name is called "tas" in the netcdf file
;  name="EAS"
;  opt=True
;    opt@VERBOSE=True ;this means it'll print out some progress reports and info for debugging
;    opt@stddev=False ;this means you will have the *average* of the area rather than the standard deviation
;  region_mean=extract_single_AR5_region(variable,name,opt)
;  printVarSummary(region_mean)  

undef("extract_single_AR5_region")
function extract_single_AR5_region(variable:float,name:string,options:logical)
; the variable is expected to have its rightmost dimensions named as lat and lon
; the region_names must follow AR5 terminology, or have the special name of "ALL"
; if options=True, then it can have certain attributes attached to it:
;    options@stddev [if True, returns area-weighted standard deviations rather than averages]
;    options@VERBOSE [if True, provides more information about how progress is going] 
local ds,a,lsdata,ls_mask,land_var,sea_var,AR5_masks,AR5_names,AR5_numbers,region_mask,defn_BOTH,defn_LAND,defn_SEA,MULTIPLY_DEF,coswgt,num_regions,overLAND,overSEA,overALL,reg_id,i,reg_i,missed
begin
  ;start with some error checking
  ds=dimsizes(variable)
  if (dimsizes(ds).ne.3).and..not.(all(iscoord(variable,(/"lat","lon"/)))) then
    print("Your input variable must have 3 dimensions. I need (time?,lat,lon) variables")
    exit
  end if
  possible_regions=(/"GLOBAL_all","GLOBAL_lnd","GLOBAL_ocn","ARC_lnd","ARC_ocn","ANT_lnd","ANT_ocn","ALA","CGI",\
    "WNA","CNA","ENA","CAM","AMZ","NEB","WSA","SSA","NEU","CEU","MED","SAH","WAF","EAF","SAF","NAS","WAS","CAS",\
    "TIB","EAS","SAS_lnd","SAS_ocn","SEA_lnd","SEA_ocn","NAU","SAU","CAR","NTP","STP","ETP","WIO"/)
  if .not.any(name.eq.possible_regions) then
    print("Your input region name of '"+name+"' is not one of the options. The possible regions are...")
    print((/possible_regions/))
    exit
  end if

  ;Load in the land-sea mask and convert to this grid
  a=addfile("$NCARG_ROOT/lib/ncarg/data/cdf/landsea.nc","r")
  lsdata=a->LSMASK
  ls_mask=landsea_mask(lsdata,variable&lat,variable&lon)
  land_var=variable
  land_var=mask(variable,ls_mask.gt.0,True)
  sea_var=variable
  sea_var=mask(variable,ls_mask.gt.0,False)
  if options.and.isatt(options,"VERBOSE").and.(options@VERBOSE) then 
    print("extract_all_AR5_regions: applied land/sea mask")
  end if

  ;Load in the Region masks and convert to this grid
  AR5_file_location=systemfunc("if [ -z $CVDP_SCRIPTS ]; then echo AR5_masks_1x1.nc; else echo $CVDP_SCRIPTS/AR5_masks_1x1.nc; fi")
  if options.and.isatt(options,"VERBOSE").and.(options@VERBOSE) then 
    print("Using the AR5 regions from: "+AR5_file_location)
  end if
  ; Note: this uses a more complicated line than a=addfile("$CVDP_SCRIPTS/AR5_masks_1x1.nc","r") 
  ;  so that this function can work in isolation outside of CVDP (by presuming mask file in current directory)
  a=addfile(AR5_file_location,"r")
  AR5_masks=a->AR5_masks
  AR5_names=str_split(AR5_masks@region_names,",")
  AR5_numbers=AR5_masks@number
  region_mask=landsea_mask(AR5_masks,variable&lat,variable&lon)
  defn_LAND=a->LAND
  defn_SEA=a->SEA
  defn_BOTH=a->BOTH
  MULTIPLY_DEF=a->MULTIPLY_DEF
  if options.and.isatt(options,"VERBOSE").and.(options@VERBOSE) then 
    print("extract_all_AR5_regions: Read variables in from regions mask file")
  end if

  ;Determine the cosine weights
  coswgt=NormCosWgtGlobe(variable&lat)
  coswgt!0="lat"
  coswgt&lat=(/variable&lat/)
  if options.and.isatt(options,"VERBOSE").and.(options@VERBOSE) then 
    print("extract_all_AR5_regions: created the coswgts")
  end if

  ;setup the variables over which to perform the looping...
  num_regions=dimsizes(AR5_names)+sum(MULTIPLY_DEF)+3+2+2;3 for global, 2 each for (Ant)arctic
  region_names=new(num_regions,string)
  if options.and.isatt(options,"VERBOSE").and.(options@VERBOSE) then 
    print("extract_all_AR5_regions: created num_regions and region_names")
  end if
  overLAND=new(num_regions,logical)
  overLAND=(/False/)
  overSEA=overLAND
  overALL=overLAND
   ;specify the manual ones
  region_names(0:2)="GLOBAL"
  overALL(0)=True
  overLAND(1)=True
  overSEA(2)=True
  region_names(3:4)="ARC"
  overLAND(3)=True
  overSEA(4)=True
  region_names(5:6)="ANT"
  overLAND(5)=True
  overSEA(6)=True
  if options.and.isatt(options,"VERBOSE").and.(options@VERBOSE) then 
    print("extract_all_AR5_regions: created variables for looping")
  end if
  ;specify the ones contained in the nc file
  reg_id=7
  do i=0,dimsizes(AR5_names)-1
    if MULTIPLY_DEF(i).eq.1 then
      ;know that these regions are both land or sea
      region_names(reg_id:reg_id+1)=(/AR5_names(i)/)
      overLAND(reg_id)=True
      overSEA(reg_id+1)=True
      reg_id=reg_id+2
    else
      region_names(reg_id)=AR5_names(i)
      overALL(reg_id)=defn_BOTH(i)
      overLAND(reg_id)=defn_LAND(i)
      overSEA(reg_id)=defn_SEA(i)
      reg_id=reg_id+1
    end if
  end do 
  if iscoord(variable,"time") then
    all_areas=new((/num_regions,dimsizes(variable&time)/),typeof(variable))
  end if
  if iscoord(variable,"month") then ;for climo variables
    all_areas=new((/num_regions,dimsizes(variable&month)/),typeof(variable))
  end if
  if options.and.isatt(options,"VERBOSE").and.(options@VERBOSE) then 
    print("extract_all_AR5_regions: Have set everything up now")
  end if

  ;Now that all the definitions are set up, we can start the actual extraction...

  do reg_i=0,num_regions-1 
    if options.and.isatt(options,"VERBOSE").and.(options@VERBOSE) then 
      print("extract_all_AR5_regions: On "+reg_i+", which is "+region_names(reg_i))
    end if
    missed=True
    if any((/"ANT","ARC","GLOBAL"/).eq.region_names(reg_i)) then
      if region_names(reg_i).eq."GLOBAL" then
        if overALL(reg_i) then
          all_areas(reg_i,:) = (/wgt_areaave_Wrap(variable,coswgt,1.0,0)/)
          if options.and.isatt(options,"stddev").and.(options@stddev) then
            all_areas(reg_i,:)=(/wgt_arearmse(variable,conform(variable,all_areas(reg_i,:),0),coswgt, 1.0, 0)/)
          end if
          region_names(reg_i)="GLOBAL_all"  
          missed=False
        end if
        if overLAND(reg_i) then
          all_areas(reg_i,:) = (/wgt_areaave_Wrap(land_var,coswgt,1.0,0)/)
          if options.and.isatt(options,"stddev").and.(options@stddev) then
            all_areas(reg_i,:)=(/wgt_arearmse(land_var,conform(land_var,all_areas(reg_i,:),0),coswgt, 1.0, 0)/)
          end if
          region_names(reg_i)="GLOBAL_lnd"  
          missed=False
        end if
        if overSEA(reg_i) then
          all_areas(reg_i,:) = (/wgt_areaave_Wrap(sea_var,coswgt,1.0,0)/)
          if options.and.isatt(options,"stddev").and.(options@stddev) then
            all_areas(reg_i,:)=(/wgt_arearmse(sea_var,conform(sea_var,all_areas(reg_i,:),0),coswgt, 1.0, 0)/)
          end if
          region_names(reg_i)="GLOBAL_ocn"  
          missed=False
        end if
      end if
      if region_names(reg_i).eq."ARC" then
        if overLAND(reg_i) then
          masked_var = land_var
          masked_var(:,{:67.5},:)=(/masked_var@_FillValue/)
          all_areas(reg_i,:) = (/wgt_areaave_Wrap(masked_var,coswgt,1.0,0)/)
          if options.and.isatt(options,"stddev").and.(options@stddev) then
            all_areas(reg_i,:)=(/wgt_arearmse(masked_var,conform(masked_var,all_areas(reg_i,:),0),coswgt, 1.0, 0)/)
          end if
          region_names(reg_i)="ARC_lnd"  
          missed=False
        end if
        if overSEA(reg_i) then
          masked_var = sea_var
          masked_var(:,{:67.5},:)=(/masked_var@_FillValue/)
          all_areas(reg_i,:) = (/wgt_areaave_Wrap(masked_var,coswgt,1.0,0)/)
          if options.and.isatt(options,"stddev").and.(options@stddev) then
            all_areas(reg_i,:)=(/wgt_arearmse(masked_var,conform(masked_var,all_areas(reg_i,:),0),coswgt, 1.0, 0)/)
          end if
          region_names(reg_i)="ARC_ocn"  
          missed=False
        end if
      end if
      if region_names(reg_i).eq."ANT" then
        if overLAND(reg_i) then
          masked_var = land_var
          masked_var(:,{-50.0:},:)=(/masked_var@_FillValue/)
          all_areas(reg_i,:) = (/wgt_areaave_Wrap(masked_var,coswgt,1.0,0)/)
          if options.and.isatt(options,"stddev").and.(options@stddev) then
            all_areas(reg_i,:)=(/wgt_arearmse(masked_var,conform(masked_var,all_areas(reg_i,:),0),coswgt, 1.0, 0)/)
          end if
          region_names(reg_i)="ANT_lnd"  
          missed=False
        end if
        if overSEA(reg_i) then
          masked_var = sea_var
          masked_var(:,{-50.0:},:)=(/masked_var@_FillValue/)
          all_areas(reg_i,:) = (/wgt_areaave_Wrap(masked_var,coswgt,1.0,0)/)
          if options.and.isatt(options,"stddev").and.(options@stddev) then
            all_areas(reg_i,:)=(/wgt_arearmse(masked_var,conform(masked_var,all_areas(reg_i,:),0),coswgt, 1.0, 0)/)
          end if
          region_names(reg_i)="ANT_ocn"  
          missed=False
        end if
      end if
    else
      this_num=AR5_numbers(ind(AR5_names.eq.region_names(reg_i)))
      if overALL(reg_i) then
        masked_var = mask(variable,region_mask.eq.this_num,True)
        all_areas(reg_i,:) = (/wgt_areaave_Wrap(masked_var,coswgt,1.0,0)/)
        if options.and.isatt(options,"stddev").and.(options@stddev) then
          all_areas(reg_i,:)=(/wgt_arearmse(masked_var,conform(masked_var,all_areas(reg_i,:),0),coswgt, 1.0, 0)/)
        end if
        missed=False
      end if
      if overLAND(reg_i) then
        masked_var = mask(land_var,region_mask.eq.this_num,True)
        all_areas(reg_i,:) = (/wgt_areaave_Wrap(masked_var,coswgt,1.0,0)/)
        if options.and.isatt(options,"stddev").and.(options@stddev) then
          all_areas(reg_i,:)=(/wgt_arearmse(masked_var,conform(masked_var,all_areas(reg_i,:),0),coswgt, 1.0, 0)/)
        end if
        if num(region_names.eq.(region_names(reg_i))).eq.2 then
          region_names(reg_i)=region_names(reg_i)+"_lnd"  
        end if
        missed=False
      end if
      if overSEA(reg_i) then
        masked_var = mask(sea_var,region_mask.eq.this_num,True)
        all_areas(reg_i,:) = (/wgt_areaave_Wrap(masked_var,coswgt,1.0,0)/)
        if options.and.isatt(options,"stddev").and.(options@stddev) then
          all_areas(reg_i,:)=(/wgt_arearmse(masked_var,conform(masked_var,all_areas(reg_i,:),0),coswgt, 1.0, 0)/)
        end if
        if region_names(reg_i-1).eq.(region_names(reg_i)+"_lnd") then
          ;if we're in this loop and the previous one was a _lnd, thn this must be an ocean equivalent
          region_names(reg_i)=region_names(reg_i)+"_ocn"  
        end if
        missed=False
      end if
    end if
    if missed then
      print("For reg_i of "+reg_i+", I didn't do anything. region_name="+region_names(reg_i)+" with "+overALL(reg_i)+","+overLAND(reg_i)+","+overSEA(reg_i))
      exit
    end if
  end do
  all_areas!0="region"
  if iscoord(variable,"time") then
    all_areas!1="time"
    all_areas&time=variable&time
  end if
  if iscoord(variable,"month") then ;for climo variables
    all_areas!1="month"
    all_areas&month=variable&month
  end if
  copy_VarAtts(variable, all_areas)

  ;Now computed all possible areas, now just select the correct one...
  output=all_areas(ind(region_names.eq.name),:)
  output@region_name=name
  return(output)
end
