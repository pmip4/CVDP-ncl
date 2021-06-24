;;;;;;;;;;;;;;;;
;; This program creates a mask file for the AR5 regions, which can be applied with landsea_mask
;;    Such a file is needed, becuase the using the shapefiles does not select the regions correctly. 
;;    NCL is too sophisticated and draws great circles between the vertices, rather than following line so lat/lon
;;;;;;;;;;;;;;;;
begin

  a = addfile("$NCARG_ROOT/lib/ncarg/data/cdf/landsea.nc","r")
  lsdata = a->LSMASK
  AR5_masks=lsdata
  AR5_masks=(/tobyte(0.)/)
  region_names=(/"ALA","AMZ","CAM","CAS","CEU","CGI","CNA","EAF","EAS","ENA",\ ;SREX regions
             "MED","NAS","NAU","NEB","NEU","SAF","SAH","SAS","SAU",\
             "SEA","SSA","TIB","WAF","WAS","WNA","WSA",\
             "CAR","NTP","STP","ETP","WIO"/) ;and the new regions [Avoiding ANT & ARC as overlapping]
  RECT=(/True,False,False,True,False,True,True,True,True,True,\ ;SREX regions
             True,True,True,True,False,True,True,True,True,\
             True,False,True,True,True,True,False,\
             False,True,True,True,True/)
  NUMBER=tobyte((/1,7,6,20,12,2,4,16,22,5,\
              13,18,25,8,11,17,14,23,26,\
              24,10,21,15,19,3,9,\
              27,28,29,30,31/))
  ;start manually definign some rectangular corners
  lat_ranges=new((/dimsizes(region_names),2/),float)
  lon_ranges=new((/dimsizes(region_names),2/),float)
  lat_ranges(ind(region_names.eq."ALA"),:)=(/60,72.6/)
  lon_ranges(ind(region_names.eq."ALA"),:)=(/-168.0,-105.0/)
  lat_ranges(ind(region_names.eq."CAS"),:)=(/30,50/)
  lon_ranges(ind(region_names.eq."CAS"),:)=(/60,75/)
  lat_ranges(ind(region_names.eq."CGI"),:)=(/50,85/)
  lon_ranges(ind(region_names.eq."CGI"),:)=(/-105,-10/)
  lat_ranges(ind(region_names.eq."CNA"),:)=(/28.6,50/)
  lon_ranges(ind(region_names.eq."CNA"),:)=(/-105,-85/)
  lat_ranges(ind(region_names.eq."EAF"),:)=(/-11.4,15/)
  lon_ranges(ind(region_names.eq."EAF"),:)=(/25,52/)
  lat_ranges(ind(region_names.eq."EAS"),:)=(/20,50/)
  lon_ranges(ind(region_names.eq."EAS"),:)=(/100,145/)
  lat_ranges(ind(region_names.eq."ENA"),:)=(/25,50/)
  lon_ranges(ind(region_names.eq."ENA"),:)=(/-85,-60/)
  lat_ranges(ind(region_names.eq."MED"),:)=(/30,45/)
  lon_ranges(ind(region_names.eq."MED"),:)=(/-10,40/)
  lat_ranges(ind(region_names.eq."NAS"),:)=(/50,70/)
  lon_ranges(ind(region_names.eq."NAS"),:)=(/40,180/)
  lat_ranges(ind(region_names.eq."NAU"),:)=(/-30,-10/)
  lon_ranges(ind(region_names.eq."NAU"),:)=(/110,155/)
  lat_ranges(ind(region_names.eq."NEB"),:)=(/-20,0/)
  lon_ranges(ind(region_names.eq."NEB"),:)=(/-50,-34/)
  lat_ranges(ind(region_names.eq."SAF"),:)=(/-35,-11.4/)
  lon_ranges(ind(region_names.eq."SAF"),:)=(/-10,52/)
  lat_ranges(ind(region_names.eq."SAH"),:)=(/15,30/)
  lon_ranges(ind(region_names.eq."SAH"),:)=(/-20,40/)
  lat_ranges(ind(region_names.eq."SAS"),:)=(/5,30/)
  lon_ranges(ind(region_names.eq."SAS"),:)=(/60,95/) ;NOTE NEEDS (95-100oE,20-30oN) added on
  lat_ranges(ind(region_names.eq."SAU"),:)=(/-50,-30/)
  lon_ranges(ind(region_names.eq."SAU"),:)=(/110,180/)
  lat_ranges(ind(region_names.eq."SEA"),:)=(/-10,20/)
  lon_ranges(ind(region_names.eq."SEA"),:)=(/95,155/)
  lat_ranges(ind(region_names.eq."TIB"),:)=(/30,50/)
  lon_ranges(ind(region_names.eq."TIB"),:)=(/75,100/)
  lat_ranges(ind(region_names.eq."WAF"),:)=(/-11.4,15/)
  lon_ranges(ind(region_names.eq."WAF"),:)=(/-20,25/)
  lat_ranges(ind(region_names.eq."WAS"),:)=(/15,50/)
  lon_ranges(ind(region_names.eq."WAS"),:)=(/40,60/)
  lat_ranges(ind(region_names.eq."WNA"),:)=(/28.6,60/)
  lon_ranges(ind(region_names.eq."WNA"),:)=(/-130,-105/)
  lat_ranges(ind(region_names.eq."NTP"),:)=(/5,25/)
  lon_ranges(ind(region_names.eq."NTP"),:)=(/155,210/)
  lat_ranges(ind(region_names.eq."STP"),:)=(/-25,-5/)
  lon_ranges(ind(region_names.eq."STP"),:)=(/155,230/)
  lat_ranges(ind(region_names.eq."ETP"),:)=(/-5,5/)
  lon_ranges(ind(region_names.eq."ETP"),:)=(/155,210/)
  lat_ranges(ind(region_names.eq."WIO"),:)=(/-25,5/)
  lon_ranges(ind(region_names.eq."WIO"),:)=(/52,75/)

  overLAND=new(dimsizes(region_names),"integer")
  overLAND!0="number"
  delete(overLAND@_FillValue)
  overLAND=(/1/)
  overSEA=overLAND
  overSEA=(/0/)
  overALL=overLAND
  overALL=(/0/)
  do reg_i=0,dimsizes(region_names)-1
    if any((/"CAR","NTP","STP","ETP","WIO"/).eq.region_names(reg_i)) then
      overLAND(reg_i)=0
      overSEA(reg_i)=0
      overALL(reg_i)=1
    end if
    if any((/"SAS","SEA"/).eq.region_names(reg_i)) then
      overSEA(reg_i)=1
    end if
  end do
  MULTIPLE_DEFN=overLAND
  MULTIPLE_DEFN=(/dim_num_n((/overLAND,overSEA,overALL/),0)-1/) ;identified regions that have multiple definitions

  do reg_i=0,dimsizes(region_names)-1
    if RECT(reg_i) then
      these_lons=lon_ranges(reg_i,:)
      these_lats=lat_ranges(reg_i,:)
      if any(these_lons.le.0) then ;need to flip coords
        flip=lonFlip(AR5_masks)
        flip({these_lats(0):these_lats(1)},{these_lons(0):these_lons(1)})=NUMBER(reg_i)
        AR5_masks=(/lonFlip(flip)/)
      else
        AR5_masks({these_lats(0):these_lats(1)},{these_lons(0):these_lons(1)})=NUMBER(reg_i)
        if region_names(reg_i).eq."SAS" then
          AR5_masks({20:30},{95:100})=NUMBER(reg_i)
        end if
      end if
    end if
  end do
  
  ;and now for the awkward ones...
  flip=lonFlip(AR5_masks)
  ; Europe
    Europe=flip({45:75},{-10:40})
    rc=regline((/-10.,-10.,40./),(/48.,48.,61.3/));put in the corners, with a repetition to let regline to not fail
    line_of_lats=rc*Europe&lon+rc@yintercept
    Europe=where(conform(Europe,Europe&lat,0).gt.conform(Europe,line_of_lats,1),\
           NUMBER(ind(region_names.eq."NEU")),NUMBER(ind(region_names.eq."CEU")))
    flip({45:75},{-10:40})=Europe
    delete([/rc,line_of_lats,Europe/])
  ; Caribbean
    Caribbean=flip({11.4:25},{-85.8:-60})
    rc=regline((/-85.8,-85.8,-68.8/),(/25,25,11.4/));put in the corners, with a repetition to let regline to not fail
    line_of_lats=rc*Caribbean&lon+rc@yintercept
    Caribbean=where(conform(Caribbean,Caribbean&lat,0).gt.conform(Caribbean,line_of_lats,1),\
           NUMBER(ind(region_names.eq."CAR")),Caribbean)
    flip({11.4:25},{-85.8:-60})=Caribbean
    delete([/rc,line_of_lats,Caribbean/])
  ; Amazon
    Amazon=flip({-20:11.4},{-79.7:-50})
    Amazon=(/tobyte(1)/)
    rc=regline((/-79.7,-79.7,-66.4/),(/-1.2,-1.2,-20/));put in the corners, with a repetition to let regline to not fail
    line_of_lats=rc*Amazon&lon+rc@yintercept
    Amazon=where(conform(Amazon,Amazon&lat,0).lt.conform(Amazon,line_of_lats,1),\
             tobyte(0),Amazon)
    rc=regline((/-79.7,-79.7,-68.8/),(/-1.2,-1.2,11.4/));put in the corners, with a repetition to let regline to not fail
    line_of_lats=rc*Amazon&lon+rc@yintercept
    Amazon=where(conform(Amazon,Amazon&lat,0).gt.conform(Amazon,line_of_lats,1),\
            tobyte(0),Amazon)
    flip({-20:11.4},{-79.7:-50})=where(Amazon.ne.tobyte(0),NUMBER(ind(region_names.eq."AMZ")),flip({-20:11.4},{-79.7:-50}))
    delete([/rc,line_of_lats,Amazon/])
  ; Central America and Mexico
    CAmer=flip({-1.2:28.6},{-118.3:-68.8})
    CAmer=(/tobyte(1)/)
    rc=regline((/-85.8,-85.8,-68.8/),(/25,25,11.4/));put in the corners, with a repetition to let regline to not fail
    line_of_lats=rc*CAmer&lon+rc@yintercept
    CAmer=where(conform(CAmer,CAmer&lat,0).gt.conform(CAmer,line_of_lats,1),\
           tobyte(0),CAmer)
    rc=regline((/-79.7,-79.7,-68.8/),(/-1.2,-1.2,11.4/));put in the corners, with a repetition to let regline to not fail
    line_of_lats=rc*CAmer&lon+rc@yintercept
    CAmer=where(conform(CAmer,CAmer&lat,0).lt.conform(CAmer,line_of_lats,1),\
            tobyte(0),CAmer)
    rc=regline((/-79.7,-79.7,-118.3/),(/-1.2,-1.2,28.6/));put in the corners, with a repetition to let regline to not fail
    line_of_lats=rc*CAmer&lon+rc@yintercept
    CAmer=where(conform(CAmer,CAmer&lat,0).lt.conform(CAmer,line_of_lats,1),\
            tobyte(0),CAmer)
    flip({-1.2:28.6},{-118.3:-68.8})=where(CAmer.ne.tobyte(0),NUMBER(ind(region_names.eq."CAM")),flip({-1.2:28.6},{-118.3:-68.8}))
    delete([/rc,line_of_lats,CAmer/])
  ; Southeastern South America
    SAmer=flip({-56.7:0.5},{-82.0:-39.4})
    SAmer=(/tobyte(1)/)
    SAmer({-20:},{-66.4:})=(/tobyte(0)/)
    rc=regline((/-50,-50,-20/),(/-72.1,-72.1,-66.4/));put in the corners, with a repetition to let regline to not fail
    line_of_lons=rc*SAmer&lat+rc@yintercept
    SAmer=where(conform(SAmer,SAmer&lon,1).lt.conform(SAmer,line_of_lons,0),\
            tobyte(0),SAmer)
    rc=regline((/-50,-50,-56.7/),(/-72.1,-72.1,-67.3/));put in the corners, with a repetition to let regline to not fail
    line_of_lons=rc*SAmer&lat+rc@yintercept
    SAmer=where(conform(SAmer,SAmer&lon,1).lt.conform(SAmer,line_of_lons,0),\
            tobyte(0),SAmer)
    flip({-56.7:0.5},{-82.0:-39.4})=where(SAmer.ne.tobyte(0),NUMBER(ind(region_names.eq."SSA")),flip({-56.7:0.5},{-82.0:-39.4}))
    delete([/rc,line_of_lons,SAmer/])
  ; Finally Western South America
    SAmer=flip({-56.7:0.5},{-82.0:-39.4})
    SAmer({-20:},{-66.4:})=(/tobyte(4)/);just set as not 0
    flip({-56.7:0.5},{-82.0:-39.4})=where(SAmer.eq.tobyte(0),NUMBER(ind(region_names.eq."WSA")),flip({-56.7:0.5},{-82.0:-39.4}))
    delete(SAmer)

  ;Return the awkward flipped regions to the proper mask
  AR5_masks=(/lonFlip(flip)/)  

  ;load "~/ncl/common.ncl"
  ;roughlatlonplot(AR5_masks)

  ;reorder for output
  number=tointeger(NUMBER)
  number!0="number"
  order = dim_pqsort(number,2)
  NUMBER=NUMBER(order)
  NUMBER!0="number"
  region_names=region_names(order)
  LAND=tointeger(overLAND(order))
  LAND!0="number"
  LAND&number=number
  LAND@long_name="Region defined only over land"
  SEA=tointeger(overSEA(order))
  SEA!0="number"
  SEA&number=number
  SEA@long_name="Region defined only over the ocean"
  BOTH=overALL(order)
  BOTH@long_name="Region defined over both land and sea"
  BOTH!0="number"
  BOTH&number=number
  MULTIPLY_DEF=tointeger(MULTIPLE_DEFN(order))
  MULTIPLY_DEF!0="number"
  MULTIPLY_DEF&number=number
  MULTIPLY_DEF@long_name="Is the region multiply defined (e.g. over land .and. sea)"

  system("rm -f "+"ncl_scripts/AR5_masks_1x1.nc")
  outfil=addfile("ncl_scripts/AR5_masks_1x1.nc","c")
  AR5_masks@long_name="AR5 Regions"
  AR5_masks@description="A combined mask to show regions delineated by the IPCC (except Arctic and Antarctic; http://www.ipcc-data.org/guidelines/pages/ar5_regions.html)"
  AR5_masks@number=number
  AR5_masks@NUMBER=NUMBER
  AR5_masks@region_names=str_join(region_names,",")
  number@region_names=region_names
  NUMBER@region_names=region_names
  printVarSummary(number)
  outfil->number=(/number/)
  outfil->region_bytes=NUMBER
  outfil->LAND=LAND
  outfil->SEA=SEA
  outfil->BOTH=BOTH
  outfil->MULTIPLY_DEF=MULTIPLY_DEF
  outfil->AR5_masks=AR5_masks
end 
  
;; Test the application of the new mask...
;load "~/ncl/common.ncl"
;rainf=addfile("/data/aod/Beijing_obs/ERA20C.pre.nc","r")
;rain=rainf->tp(0,:,:)
;PAGEf = addfile("PAGE_regions/PAGE_masks_1x1.nc","r")
;PAGE_masks  = PAGEf->PAGE_masks
;PAGE_ERA = landsea_mask(PAGE_masks,rain&latitude,rain&longitude)
;rain = mask(rain,PAGE_ERA.eq.7,True)
;roughlatlonplot(rain)
