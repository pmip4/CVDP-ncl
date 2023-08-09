;This file contains a function that will extract and compute an area statistic for an AR6 region (either mean or stddev)
; It uses predetermined 1x1o regions and landsea masks
; I've found that using the shapefiles is pretty slow
;   and NCL's sophistication of using great circles means you actually cut out the wrong areas. 

;This script is run with as part of the CVDP via the pr.indices.ncl and tas.indices.ncl routines
;  It can potentially be run elsewhere using the commands below, 
;  but only if AR6_masks_1x1.nc is in the NCL directory
;
;  load "extract_all_AR6_regions.ncl"
;  f=addfile("your_filename.nc","r")
;  variable=f->tas ;if your variable name is called "tas" in the netcdf file
;  opt=True
;    opt@VERBOSE=True ;this means it'll print out some progress reports and info for debugging
;    opt@stddev=False ;this means you will have the *average* of the area rather than the standard deviation
;  region_means=extract_all_AR6_regions(variable,opt)
;  printVarSummary(region_means)  

undef("extract_all_AR6_regions")
function extract_all_AR6_regions(variable:float,options:logical)
; the variable is expected to have its rightmost dimensions named as lat and lon
; the abbrevs must follow AR6 terminology, or have the special name of "ALL"
; if options=True, then it can have certain attributes attached to it:
;    options@stddev [if True, returns area-weighted standard deviations rather than averages]
;    options@VERBOSE [if True, provides more information about how progress is going] 
local ds,a,lsdata,ls_mask,land_var,sea_var,AR6_masks,AR6_abbrevs,AR6_numbers,region_mask,defn_BOTH,defn_LAND,defn_SEA,MULTIPLY_DEF,coswgt,num_regions,overLAND,overSEA,overALL,reg_id,i,reg_i,missed
begin
  ;start with some error checking
  ds=dimsizes(variable)
  if (dimsizes(ds).ne.3).and..not.(all(iscoord(variable,(/"lat","lon"/)))) then
    print("Your input variable must have 3 dimensions. I need (time?,lat,lon) variables")
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
    print("extract_all_AR6_regions: applied land/sea mask")
  end if

  ;Load in the Region masks and convert to this grid
  AR6_file_location=systemfunc("if [ -z $CVDP_SCRIPTS ]; then echo AR6_masks_1x1.nc; else echo $CVDP_SCRIPTS/AR6_masks_1x1.nc; fi")
  if options.and.isatt(options,"VERBOSE").and.(options@VERBOSE) then 
    print("Using the AR6 regions from: "+AR6_file_location)
  end if
  ; Note: this uses a more complicated line than a=addfile("$CVDP_SCRIPTS/AR6_masks_1x1.nc","r") 
  ;  so that this function can work in isolation outside of CVDP (by presuming mask file in current directory)
  a=addfile(AR6_file_location,"r")
  AR6_masks=a->AR6_masks
  AR6_abbrevs=AR6_masks@abbrevs
  AR6_region_names=AR6_masks@region_names
  AR6_numbers=AR6_masks@number
  region_mask=landsea_mask(AR6_masks,variable&lat,variable&lon)
  defn_LAND=a->LAND
  defn_SEA=a->OCEAN
  defn_BOTH=a->BOTH
  MULTIPLY_DEF=a->MULTIPLY_DEF
  if options.and.isatt(options,"VERBOSE").and.(options@VERBOSE) then 
    print("extract_all_AR6_regions: Read variables in from regions mask file")
  end if

  ;Determine the cosine weights
  coswgt=NormCosWgtGlobe(variable&lat)
  coswgt!0="lat"
  coswgt&lat=(/variable&lat/)
  if options.and.isatt(options,"VERBOSE").and.(options@VERBOSE) then 
    print("extract_all_AR6_regions: created the coswgts")
  end if

  ;setup the variables over which to perform the looping...
  num_regions=dimsizes(AR6_abbrevs)+sum(MULTIPLY_DEF)+3+18; Iturbide regions and 3 for global + 18 for the lat_bands
  abbrevs=new(num_regions,string)
  region_names=new(num_regions,string)
  if options.and.isatt(options,"VERBOSE").and.(options@VERBOSE) then 
    print("extract_all_AR6_regions: created num_regions and abbrevs")
  end if
  overLAND=new(num_regions,logical)
  overLAND=(/False/)
  overSEA=overLAND
  overALL=overLAND
   ;specify the manual ones
  abbrevs(0:2)="GLOBAL"
  region_names(0:2)=(/"Global","Global (land only)","Global (ocean only)"/)
  overALL(0)=True
  overLAND(1)=True
  overSEA(2)=True
  if options.and.isatt(options,"VERBOSE").and.(options@VERBOSE) then 
    print("extract_all_AR6_regions: created variables for looping")
  end if
  ;specify the ones contained in the nc file
  reg_id=3
  do i=0,dimsizes(AR6_abbrevs)-1
    if MULTIPLY_DEF(i).eq.1 then
      ;know that these regions are both land or sea
      abbrevs(reg_id:reg_id+1)=(/AR6_abbrevs(i)/)
      region_names(reg_id:reg_id+1)=(/AR6_region_names(i)+(/" (land only)"," (ocean only)"/)/)
      overLAND(reg_id)=True
      overSEA(reg_id+1)=True
      reg_id=reg_id+2
    else
      abbrevs(reg_id)=AR6_abbrevs(i)
      region_names(reg_id)=(/AR6_region_names(i)/)
      overALL(reg_id)=defn_BOTH(i)
      overLAND(reg_id)=defn_LAND(i)
      overSEA(reg_id)=defn_SEA(i)
      reg_id=reg_id+1
    end if
  end do
  band_names=(/"NH_highlats","NH_midlats","NH_tropics","SH_tropics","SH_midlats","SH_highlats"/)
  band_long_names=(/"60-90oN","30-60oN","0-30oN","0-30oS","30-60oS","60-90oS"/)
  do i=0,dimsizes(band_names)-1
    abbrevs(reg_id:reg_id+2)=band_names(i)
    region_names(reg_id:reg_id+2)=(/band_long_names(i)+(/" (all)"," (land only)"," (ocean only)"/)/)
    overALL(reg_id)=True
    overLAND(reg_id+1)=True
    overSEA(reg_id+2)=True
    reg_id=reg_id+3
  end do


  if iscoord(variable,"time") then
    output=new((/num_regions,dimsizes(variable&time)/),typeof(variable))
  end if
  if iscoord(variable,"month") then ;for climo variables
    output=new((/num_regions,dimsizes(variable&month)/),typeof(variable))
  end if
  if options.and.isatt(options,"VERBOSE").and.(options@VERBOSE) then 
    print("extract_all_AR6_regions: Have set everything up now")
  end if

  ;Now that all the definitions are set up, we can start the actual extraction...

  do reg_i=0,num_regions-1 
    if options.and.isatt(options,"VERBOSE").and.(options@VERBOSE) then 
      print("extract_all_AR6_regions: On "+reg_i+", which is "+abbrevs(reg_i))
    end if
    missed=True
    if any(band_names.eq.abbrevs(reg_i)) then
      masked_var=new(dimsizes(variable),typeof(variable), variable@_FillValue)
      copy_VarMeta(variable,masked_var)
      Nlats=(/90.,60.,30.,0.,-30.,-60./)
      Slats=(/60.,30.,0.,-30.,-60.,-90./)
      band_ind=ind(band_names.eq.abbrevs(reg_i))
      if overALL(reg_i) then
        masked_var(:,{Slats(band_ind):Nlats(band_ind)},:)=(/variable(:,{Slats(band_ind):Nlats(band_ind)},:)/)
        output(reg_i,:) = (/wgt_areaave_Wrap(masked_var,coswgt,1.0,0)/)
        if options.and.isatt(options,"stddev").and.(options@stddev) then
          output(reg_i,:)=(/wgt_arearmse(variable,conform(variable,output(reg_i,:),0),coswgt, 1.0, 0)/)
        end if
        abbrevs(reg_i)=abbrevs(reg_i)+"_all"  
        missed=False
      end if
      if overLAND(reg_i) then
        masked_var(:,{Slats(band_ind):Nlats(band_ind)},:)=(/land_var(:,{Slats(band_ind):Nlats(band_ind)},:)/)
        output(reg_i,:) = (/wgt_areaave_Wrap(masked_var,coswgt,1.0,0)/)
        if options.and.isatt(options,"stddev").and.(options@stddev) then
          output(reg_i,:)=(/wgt_arearmse(masked_var,conform(masked_var,output(reg_i,:),0),coswgt, 1.0, 0)/)
        end if
        abbrevs(reg_i)=abbrevs(reg_i)+"_lnd"  
        missed=False
      end if
      if overSEA(reg_i) then
        masked_var(:,{Slats(band_ind):Nlats(band_ind)},:)=(/sea_var(:,{Slats(band_ind):Nlats(band_ind)},:)/)
        output(reg_i,:) = (/wgt_areaave_Wrap(masked_var,coswgt,1.0,0)/)
        if options.and.isatt(options,"stddev").and.(options@stddev) then
          output(reg_i,:)=(/wgt_arearmse(masked_var,conform(masked_var,output(reg_i,:),0),coswgt, 1.0, 0)/)
        end if
        abbrevs(reg_i)=abbrevs(reg_i)+"_ocn"  
        missed=False
      end if
      delete(masked_var)
    else
      if abbrevs(reg_i).eq."GLOBAL" then
        if overALL(reg_i) then
          output(reg_i,:) = (/wgt_areaave_Wrap(variable,coswgt,1.0,0)/)
          if options.and.isatt(options,"stddev").and.(options@stddev) then
            output(reg_i,:)=(/wgt_arearmse(variable,conform(variable,output(reg_i,:),0),coswgt, 1.0, 0)/)
          end if
          abbrevs(reg_i)="GLOBAL_all"  
          missed=False
        end if
        if overLAND(reg_i) then
          output(reg_i,:) = (/wgt_areaave_Wrap(land_var,coswgt,1.0,0)/)
          if options.and.isatt(options,"stddev").and.(options@stddev) then
            output(reg_i,:)=(/wgt_arearmse(land_var,conform(land_var,output(reg_i,:),0),coswgt, 1.0, 0)/)
          end if
          abbrevs(reg_i)="GLOBAL_lnd"  
          missed=False
        end if
        if overSEA(reg_i) then
         output(reg_i,:) = (/wgt_areaave_Wrap(sea_var,coswgt,1.0,0)/)
          if options.and.isatt(options,"stddev").and.(options@stddev) then
            output(reg_i,:)=(/wgt_arearmse(sea_var,conform(sea_var,output(reg_i,:),0),coswgt, 1.0, 0)/)
          end if
          abbrevs(reg_i)="GLOBAL_ocn"  
          missed=False
        end if
      else
        this_num=AR6_numbers(ind(AR6_abbrevs.eq.abbrevs(reg_i)))
        if overALL(reg_i) then
          masked_var = mask(variable,region_mask.eq.this_num,True)
          output(reg_i,:) = (/wgt_areaave_Wrap(masked_var,coswgt,1.0,0)/)
          if options.and.isatt(options,"stddev").and.(options@stddev) then
            output(reg_i,:)=(/wgt_arearmse(masked_var,conform(masked_var,output(reg_i,:),0),coswgt, 1.0, 0)/)
          end if
          missed=False
        end if
        if overLAND(reg_i) then
          masked_var = mask(land_var,region_mask.eq.this_num,True)
          output(reg_i,:) = (/wgt_areaave_Wrap(masked_var,coswgt,1.0,0)/)
          if options.and.isatt(options,"stddev").and.(options@stddev) then
            output(reg_i,:)=(/wgt_arearmse(masked_var,conform(masked_var,output(reg_i,:),0),coswgt, 1.0, 0)/)
          end if
          if num(abbrevs.eq.(abbrevs(reg_i))).eq.2 then
            abbrevs(reg_i)=abbrevs(reg_i)+"_lnd"  
          end if
          missed=False
        end if
        if overSEA(reg_i) then
          masked_var = mask(sea_var,region_mask.eq.this_num,True)
          output(reg_i,:) = (/wgt_areaave_Wrap(masked_var,coswgt,1.0,0)/)
          if options.and.isatt(options,"stddev").and.(options@stddev) then
            output(reg_i,:)=(/wgt_arearmse(masked_var,conform(masked_var,output(reg_i,:),0),coswgt, 1.0, 0)/)
          end if
          if abbrevs(reg_i-1).eq.(abbrevs(reg_i)+"_lnd") then
            ;if we're in this loop and the previous one was a _lnd, thn this must be an ocean equivalent
            abbrevs(reg_i)=abbrevs(reg_i)+"_ocn"  
          end if
          missed=False
        end if
      end if
    end if
    if missed then
      print("For reg_i of "+reg_i+", I didn't do anything. abbrev="+abbrevs(reg_i)+" with "+overALL(reg_i)+","+overLAND(reg_i)+","+overSEA(reg_i))
      exit
    end if
  end do
  output!0="region"
  if iscoord(variable,"time") then
    output!1="time"
    output&time=variable&time
  end if
  if iscoord(variable,"month") then ;for climo variables
    output!1="month"
    output&month=variable&month
  end if
  copy_VarAtts(variable, output)
  output@abbrevs=abbrevs
  output@region_names=region_names
  return(output)
end
