; Calculates the monsoon rainfall, using either the AR6 definitions (IPCC WG1 AR6 Annex V) or AR5 definitions
; This is somewhat of a replicate of the ESMValTool monsoon routine, with some slightly different assumptions about variability
; Variables used: pr
;
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/shea_util.ncl"
load "$CVDP_SCRIPTS/functions.ncl"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; NOW START THE PROGRAM PROPER ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

begin
  AR6_DEFS=True ;True uses the regions defined by Iturbide et al (2020)

  if AR6_DEFS then
    ; This uses the domains outlined in Cherchi et al (2021, IPCC WG1 AR6 Annex V)
    ; The inclusion criteria is that the "annual range (local summer minus local winter) of precipitation is greater than 2.5 mm day–1 (Kitoh et al., 2013)"
    ; The masks are some odd shapes (and also only defined over land), and need to read in from a file
    ; Equatorial America and Southern Africa are included despite not being proper monsoon regions
    print("Starting: monsoon.ncl [USING AR6 Definitions]")
    else
    ; This uses the "global monsoon domain" of Wang et al. (2011).
    ; The inclusion criteria is that 55% of rain falls in summer, and that the summer rainfall is 2mm/day greater than the winter rainfall
    ; All of the boxes are rectangles, but only defined over land
    print("Starting: monsoon.ncl [Using AR5 Definitions]")
  end if
  
  OUTDIR      = getenv("OUTDIR") 
  SCALE_TIMESERIES = getenv("SCALE_TIMESERIES")
  OUTPUT_DATA      = getenv("OUTPUT_DATA")  
  PNG_SCALE        = tofloat(getenv("PNG_SCALE"))
  OPT_CLIMO        = getenv("OPT_CLIMO")
  CLIMO_SYEAR      = toint(getenv("CLIMO_SYEAR"))
  CLIMO_EYEAR      = toint(getenv("CLIMO_EYEAR"))
  OUTPUT_TYPE      = getenv("OUTPUT_TYPE") 
  COLORMAP         = getenv("COLORMAP")  
  
  delim = "|"
  nsim = numAsciiRow("namelist_byvar/namelist_prect")
  na = asciiread("namelist_byvar/namelist_prect",(/nsim/),"string")
  names = new(nsim,"string")
  paths = new(nsim,"string")
  syear = new(nsim,"integer",-999)
  eyear = new(nsim,"integer",-999)

  do gg = 0,nsim-1
    names(gg) = str_strip(str_get_field(na(gg),1,delim))
    paths(gg) = str_strip(str_get_field(na(gg),2,delim))
    syear(gg) = stringtointeger(str_strip(str_get_field(na(gg),3,delim)))
    eyear(gg) = stringtointeger(str_strip(str_get_field(na(gg),4,delim)))
  end do
  delete(na)
  nyr = eyear-syear+1  

  ;decide the model names and output filenames
  modnames = new(nsim,"string")
  filenames = new(nsim,"string")
  do ee = 0,nsim-1
    modnames(ee) = str_sub_str(names(ee)," ","_")
    bc = (/"/","'","(",")"/)
    do gg = 0,dimsizes(bc)-1
      modnames(ee) = str_sub_str(modnames(ee),bc(gg),"_")
    end do
    filenames(ee) = getenv("OUTDIR")+modnames(ee)+".cvdp_data.monsoon."+syear(ee)+"-"+eyear(ee)+".nc"
  end do
  
  nyr_max = max(nyr)
  pi=4.*atan(1.0)
  rad=(pi/180.)

  if AR6_DEFS then
    domain_names=(/"NAmerM","EqAmer","SAmerM","WAfriM","SAfri","SAsiaM","EAsiaM","AusMCM"/)
  else
    ;Set up the variables to define the separate monsoons.
    ;Not as easy as you'd think as NAF crosses Greenwich and EAS is cut out of SAS.
    domain_names=(/"NAMS","SAMS","NAF","SAF","SAS","EAS","AUSMC"/)
    domain_lats=(/(/0.,40./),(/-40.,0./),(/0.,40./),(/-40.,0./),(/0.,40./),(/20.,40./),(/-40.,0./)/)
    domain_lons=(/(/240.,300./),(/270.,330./),(/-30.,60./),(/0.,60./),(/60.,150./),(/60.,150./),(/90.,150./)/)
  end if
  
;--------------------------------------------------------------------------------------     
; loop over the models  
  do ee = 0,nsim-1

;--------------------------------------------------------------------------------------     
; In a departure from CVDP standard practice, there is no option to NOT write out data.
; Instead this enables us to loop over the many different models and indices
; the data is always written out and then read back in later for plotting.
    
    modname=modnames(ee)
    fn=filenames(ee)
    if (.not.isfilepresent2(fn)) then
      z = addfile(fn,"c")
      z@source = "NCAR Climate Analysis Section's Climate Variability Diagnostics Package v"+getenv("VERSION")+" [Altered by C. Brierley, UCL]"
      z@notes = "Data from "+names(ee)+" from "+syear(ee)+"-"+eyear(ee)
      if (OPT_CLIMO.eq."Full") then
        z@climatology = syear(ee)+"-"+eyear(ee)+" climatology removed prior to all calculations (other than means)"
      else
        if (CLIMO_SYEAR.lt.0) then
          z@climatology = (eyear(ee)+CLIMO_SYEAR)+"-"+(eyear(ee)+CLIMO_EYEAR)+" climatology removed prior to all calculations (other than means)"
        else
          z@climatology = CLIMO_SYEAR+"-"+CLIMO_EYEAR+" climatology removed prior to all calculations (other than means)"
        end if
      end if
      z@Conventions = "CF-1.6"
    else
      z = addfile(fn,"w")
    end if
    
    ;Read in the paths
    pr = data_read_in(paths(ee),"PRECT",syear(ee),eyear(ee))
    ;skip this model is all missing 
    if isatt(pr,"is_all_missing") then
      delete(pr)
      continue
    else
      ; read in the surface temperatures, orient lats/lons correctly, set time coordinate variable up
      if (OPT_CLIMO.eq."Full") then
        climo_pr = clmMonTLL(pr)
      else
        check_custom_climo(names(ee),syear(ee),eyear(ee),CLIMO_SYEAR,CLIMO_EYEAR)
        temp_arr = pr
        delete(temp_arr&time)
        temp_arr&time = cd_calendar(pr&time,-1)
        if (CLIMO_SYEAR.lt.0) then
          climo_pr = clmMonTLL(temp_arr({(eyear(ee)+CLIMO_SYEAR)*100+1:(eyear(ee)+CLIMO_EYEAR)*100+12},:,:))
        else
          climo_pr = clmMonTLL(temp_arr({CLIMO_SYEAR*100+1:CLIMO_EYEAR*100+12},:,:))
        end if   
        delete(temp_arr)
      end if
       
      coswgt=NormCosWgtGlobe(pr&lat)
      coswgt!0="lat"
      coswgt&lat=pr&lat
      area=climo_pr(0,:,:);set up array with lat/lon metadata
      area=(/conform(area,tofloat(coswgt),0)/)
      area=area*(4*pi*6371.22^2)/sum(area);results in area of grid boxes in km^2
  
      ;Now calculate the climatological global monsoon domain for plotting
      climo_Annual=dim_avg_n_Wrap(climo_pr,0)
      climo_MJJAS=dim_avg_n_Wrap(climo_pr(4:8,:,:),0)
      climo_NDJFM=climo_MJJAS
      climo_NDJFM=(/dim_avg_n((/climo_pr(0,:,:),climo_pr(1,:,:),climo_pr(2,:,:),\
              climo_pr(10,:,:),climo_pr(11,:,:)/),0)/)
      climo_summer=climo_MJJAS
      climo_summer({-90:0},:) = climo_NDJFM({-90:0},:)
      climo_winter=climo_NDJFM
      climo_winter({-90:0},:) = climo_MJJAS({-90:0},:)
      ;calculate the rain falling during the monsoon (i.e. pr_summer in monsoon domain)
      monsoon_domain=climo_summer
      if AR6_DEFS then
        monsoon_domain=where(((climo_summer-climo_winter).gt.2.5),climo_summer,climo_summer@_FillValue)
      else
        climo_intensity=climo_Annual
        climo_intensity=climo_summer-climo_winter
        monsoon_domain=where((climo_summer.gt.climo_Annual*0.55).and.(climo_intensity.gt.2),climo_summer,climo_summer@_FillValue)
      end if
      ;write out the global monsoon maps to file
      if AR6_DEFS then
        z->monsoon_domain=set_varAtts(monsoon_domain,"Monsoon domain's rainfall","mm/day","climatology, after IPCC WG1 AR6 Annex V")
        delete([/climo_Annual,climo_MJJAS,climo_NDJFM,climo_summer,climo_winter,monsoon_domain,climo_pr/]);tidy up
      else
        z->monsoon_domain=set_varAtts(monsoon_domain,"Monsoon domain's rainfall","mm/day","climatology, after IPCC AR5 Fig 14.1a")
        z->monsoon_intensity=set_varAtts(climo_intensity,"Seasonal rainfall intensity (summer-winter)","mm/day","climatology [used to calculated global monsoon domain]")
        z->monsoon_summer_rainrate=set_varAtts(climo_summer,"Summer (MJJAS) rainfall intensity","mm/day","climatology [used to calculated global monsoon domain]")
        delete([/climo_Annual,climo_MJJAS,climo_NDJFM,climo_summer,climo_winter,climo_intensity,monsoon_domain,climo_pr/]);tidy up
      end if

      ; Now create some monsoon timeseries. 
      ; Firstly need create the necessary fields to define monsoon rainfall (interannually)
      ; Using "USGS water years" of Nov-Oct. This means we lose a year from the front in the SH (as the ND do not exist for the first instance)
      ; [This wasn't a problem for the climatology, as we're effectively replaced the missing ND with 
      ;  the climatological value: the difference is negligible and easier to code and compute].
      pr_ann_jandec=month_to_annual(pr,1);use this to routine create an annual field with appropriate metadata
      pr_ann_jandec=(/pr_ann_jandec@_FillValue/)
      Annual=pr_ann_jandec
      NDJFM=pr_ann_jandec
      MJJAS=pr_ann_jandec
      f_yr=dimsizes(pr&time)-1;final year of dataset
      pu_yr=dimsizes(pr&time)-13;penultimate year of dataset
      Annual(1:,:,:)=(/dim_avg_n_Wrap((/pr(10:pu_yr:12,:,:),pr(11:pu_yr:12,:,:),pr(12:f_yr:12,:,:),\
              pr(13:f_yr:12,:,:),pr(14:f_yr:12,:,:),pr(15:f_yr:12,:,:),\
              pr(16:f_yr:12,:,:),pr(17:f_yr:12,:,:),pr(18:f_yr:12,:,:),\
              pr(19:f_yr:12,:,:),pr(20:f_yr:12,:,:),pr(21:f_yr:12,:,:)/),0)/)
      NDJFM(1:,:,:)=(/dim_avg_n((/pr(10:pu_yr:12,:,:),pr(11:pu_yr:12,:,:),pr(12:f_yr:12,:,:),\
              pr(13:f_yr:12,:,:),pr(14:f_yr:12,:,:)/),0)/)
      MJJAS(1:,:,:)=(/dim_avg_n_Wrap((/pr(16::12,:,:),pr(17::12,:,:),pr(18::12,:,:),\
              pr(19::12,:,:),pr(20::12,:,:)/),0)/)
      pr_summer=MJJAS
      pr_summer(:,{-90:0},:) = NDJFM(:,{-90:0},:) ;move from pure calendar years into NH/SH summers
      pr_winter=NDJFM
      pr_winter(:,{-90:0},:) = MJJAS(:,{-90:0},:)
      intensity=pr_summer-pr_winter
      ;calculate the rain falling during the monsoon (i.e. pr_summer in monsoon domain)
      monsoonrain=pr_summer
      monsoonarea=pr_ann_jandec
      if AR6_DEFS then
        monsoonrain=where(intensity.gt.2.5,pr_summer,pr_summer@_FillValue)
        monsoonarea=where(intensity.gt.2.5,conform(pr_ann_jandec,area,(/1,2/)),0)
      else
        monsoonrain=where((pr_summer.gt.Annual*0.55).and.(intensity.gt.2),pr_summer,pr_summer@_FillValue)
        monsoonarea=where((pr_summer.gt.Annual*0.55).and.(intensity.gt.2),conform(pr_ann_jandec,area,(/1,2/)),0)
      end if ;Now I can create timeseries of monsoon area and rainfall every year
      delete([/pr_ann_jandec,Annual,NDJFM,MJJAS,pr_summer,pr_winter,intensity,f_yr,pu_yr/]);tidy up
      
      ;write out the global monsoon timeseries to file
      TIME=ispan(syear(ee),eyear(ee),1)
      TIME@units="YYYY"
      TIME@long_name = "time"
      monsoon_area_global=dim_sum_n_Wrap(monsoonarea,(/1,2/))
      monsoon_area_global!0 = "TIME"
      monsoon_area_global&TIME = TIME
      z->monsoon_area_global=set_varAtts(monsoon_area_global,"Area of global monsoon domain","km2","Calculated after IPCC AR5 Fig 14.1a, but for each water year (i.e. Nov-Oct, labelled for end date)")
      monsoon_rain_global=wgt_areaave_Wrap(monsoonrain,coswgt,1.0,0)
      monsoon_rain_global!0 = "TIME"
      monsoon_rain_global&TIME = ispan(syear(ee),eyear(ee),1)
      monsoon_rain_global&TIME = TIME
      z->monsoon_rain_global=set_varAtts(monsoon_rain_global,"rainfall over global monsoon domain","mm/day","averaged over summer for each water year (i.e. Nov-Oct, labelled for end date). After IPCC AR5 Fig 14.1a, but with annually varying domain.")
      delete([/monsoon_area_global,monsoon_rain_global/])
 
      ;The named monsoon domains are only defined over land...
      d = addfile("$NCARG_ROOT/lib/ncarg/data/cdf/landsea.nc","r")
      basemap = d->LSMASK
      lsm = landsea_mask(basemap,pr&lat,pr&lon)
      monsoonrain = mask(monsoonrain,conform(monsoonrain,lsm,(/1,2/)).ne.1,False)
      monsoonarea = mask(monsoonarea,conform(monsoonarea,lsm,(/1,2/)).ne.1,False)
      delete([/d,basemap,lsm/])

      if AR6_DEFS then
        ;Load in the Monsoon Region masks and convert to this grid
        a=addfile("$CVDP_SCRIPTS/AR6_masks_1x1.nc","r")
        AR6_masks=a->AR6_monsoons
        domain_names=AR6_masks@abbrevs
        domain_longnames=AR6_masks@monsoon_names
        domain_numbers=AR6_masks@number
        region_mask=landsea_mask(AR6_masks,pr&lat,pr&lon)

        do reg_i=0,dimsizes(domain_names)-1
          this_rain=mask(monsoonrain,conform(monsoonrain,region_mask,(/1,2/)).eq.domain_numbers(reg_i),True)
          this_area=mask(monsoonarea,conform(monsoonarea,region_mask,(/1,2/)).eq.domain_numbers(reg_i),True)
          monsoon_area_ts=dim_sum_n_Wrap(this_area,(/1,2/))
          monsoon_area_ts!0 = "TIME"
          monsoon_area_ts&TIME = TIME
          monsoon_rain_ts=wgt_areaave_Wrap(this_rain,coswgt,1.0,0)
          monsoon_rain_ts!0 = "TIME"
          monsoon_rain_ts&TIME = TIME
          ;write out individaul monsoon timeseries and tidy up
          varname="monsoon_rain_"+domain_names(reg_i)
          z->$varname$ = set_varAtts(monsoon_rain_ts,"rainfall over "+domain_names(reg_i)+" domain","mm/day","averaged over summer for each water year (i.e. Nov-Oct, labelled for end date). After IPCC WG1 AR6 Annex V, but with annually varying domain.")
          varname="monsoon_area_"+domain_names(reg_i)
          z->$varname$=set_varAtts(monsoon_area_ts,"Area of "+domain_names(reg_i)+" monsoon domain","km2","Calculated after IPCC WG1 AR6 Annex V, but for each water year (i.e. Nov-Oct, labelled for end date)")
          delete([/this_rain,this_area,monsoon_area_ts,monsoon_rain_ts,varname/])
        end do; loop over the regions
      else
        ;then loop over the actual monsoon domains. Taking area and averaged rain rate
        do reg_i=0,dimsizes(domain_names)-1      
          if domain_names(reg_i).eq."SAS" then
            this_rain=monsoonrain(:,{domain_lats(reg_i,0):domain_lats(reg_i,1)},{domain_lons(reg_i,0):domain_lons(reg_i,1)})
            this_area=monsoonarea(:,{domain_lats(reg_i,0):domain_lats(reg_i,1)},{domain_lons(reg_i,0):domain_lons(reg_i,1)})
            SAS_mask=this_rain(0,:,:)
            SAS_mask=(/1/)
            SAS_mask({domain_lats(reg_i+1,0):},{domain_lons(reg_i+1,0):})=(/0/)
            this_rain=mask(this_rain,conform(this_rain,SAS_mask,(/1,2/)).eq.0,False)
            this_area=mask(this_area,conform(this_area,SAS_mask,(/1,2/)).eq.0,False)
            delete([/SAS_mask/])
          else
            if domain_names(reg_i).eq."NAF" then
              ;NAF crosses Greenwich Meridian, so needs a lonFlip
              tmp_rain=lonFlip(monsoonrain)
              tmp_area=lonFlip(monsoonarea)
              this_rain=tmp_rain(:,{domain_lats(reg_i,0):domain_lats(reg_i,1)},{domain_lons(reg_i,0):domain_lons(reg_i,1)})
              this_area=tmp_area(:,{domain_lats(reg_i,0):domain_lats(reg_i,1)},{domain_lons(reg_i,0):domain_lons(reg_i,1)})
              delete([/tmp_rain,tmp_area/])
            else
              this_rain=monsoonrain(:,{domain_lats(reg_i,0):domain_lats(reg_i,1)},{domain_lons(reg_i,0):domain_lons(reg_i,1)})
              this_area=monsoonarea(:,{domain_lats(reg_i,0):domain_lats(reg_i,1)},{domain_lons(reg_i,0):domain_lons(reg_i,1)})
            end if
          end if
          this_coswgt=coswgt({domain_lats(reg_i,0):domain_lats(reg_i,1)})
          monsoon_area_ts=dim_sum_n_Wrap(this_area,(/1,2/))
          monsoon_area_ts!0 = "TIME"
          monsoon_area_ts&TIME = TIME
          monsoon_rain_ts=wgt_areaave_Wrap(this_rain,this_coswgt,1.0,0)
          monsoon_rain_ts!0 = "TIME"
          monsoon_rain_ts&TIME = TIME
          ;write out individaul monsoon timeseries and tidy up
          varname="monsoon_rain_"+domain_names(reg_i)
          z->$varname$ = set_varAtts(monsoon_rain_ts,"rainfall over "+domain_names(reg_i)+" domain","mm/day","averaged over summer for each water year (i.e. Nov-Oct, labelled for end date). After IPCC AR5 Fig 14.3, but with annually varying domain.")
          varname="monsoon_area_"+domain_names(reg_i)
          z->$varname$=set_varAtts(monsoon_area_ts,"Area of "+domain_names(reg_i)+" monsoon domain","km2","Calculated after IPCC AR5 Fig 14.1a and Fig 14.3, but for each water year (i.e. Nov-Oct, labelled for end date)")
          delete([/this_coswgt,this_rain,this_area,monsoon_area_ts,monsoon_rain_ts,varname/])      
        end do; loop over the regions
      end if ;AR6_DEFS 
      ;tidy up
      delete([/pr,coswgt,area,monsoonrain,monsoonarea/])
    end if; if all(ismissing(pr))

    delete([/modname,fn,z,TIME/])
  end do; the data processing loop over the models.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Another loop (over the indices) is needed to then make the plots.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ;First plot the global monsoon domains on a map
  wks_domain=gsn_open_wks(OUTPUT_TYPE,getenv("OUTDIR")+"global_monsoon_domain")
  if (COLORMAP.eq.0) then
    gsn_define_colormap(wks_domain,"precip3_16lev")
  else
    gsn_define_colormap(wks_domain,"BlueDarkRed18")
  end if
  ;define some resources for the plotting
  res = True
   res@mpProjection = "WinkelTripel"
   res@mpGeophysicalLineColor = "gray42"
   res@mpPerimOn    = False
   res@mpGridLatSpacingF =  90            ; change latitude  line spacing
   res@mpGridLonSpacingF = 180.           ; change longitude line spacing
   res@mpGridLineColor   = "transparent"  ; trick ncl into drawing perimeter
   res@mpGridAndLimbOn   = True           ; turn on lat/lon lines  
   res@mpFillOn = False
   res@mpCenterLonF = 210.
   res@mpOutlineOn = True  
   if (OUTPUT_TYPE.eq."png") then
      res@mpGeophysicalLineThicknessF = 2.  
   else
      res@mpGeophysicalLineThicknessF = 1.  
   end if
   res@gsnDraw      = False
   res@gsnFrame     = False
   res@cnLineLabelsOn = False
   res@cnFillOn        = True
   res@cnLinesOn       = False
   res@lbLabelBarOn    = False
   res@cnLevelSelectionMode = "ExplicitLevels"
   res@gsnLeftStringOrthogonalPosF = -0.05
   res@gsnLeftStringParallelPosF = .005
   res@gsnRightStringOrthogonalPosF = -0.05
   res@gsnRightStringParallelPosF = 0.96
   res@gsnRightString = ""
   res@gsnLeftString = ""
   res@gsnLeftStringFontHeightF = 0.014
   res@gsnCenterStringFontHeightF = 0.018
   res@gsnRightStringFontHeightF = 0.014
   res@cnLevels  = (/0.5,1,2,3,4,5,6,7,8,9,10,12,14,16,18/)
  
  ;Now create the individual panels via a loop
  map_domains = new(nsim,"graphic") 
  do ee=0,nsim-1 ;loop over the models
    fn=filenames(ee)
    if isfilepresent(fn) then
      z = addfile(fn,"r")
      if isfilevar(z,"monsoon_domain") then ;if area_name exists then both will 
        monsoon_domain=z->monsoon_domain
        res@gsnLeftString = syear(ee)+"-"+eyear(ee) 
        res@gsnRightString = monsoon_domain@units
        res@gsnCenterString = names(ee) 
        map_domains(ee)=gsn_csm_contour_map(wks_domain,monsoon_domain,res)
        delete([/monsoon_domain/])
      end if ;isfilevar(z,vname+"_lnd")
      delete([/z/])
    end if ;isfilepresent(z)
    delete([/fn/])
  end do; the data processing loop over the models.
  panres = True
    panres@gsnMaximize = True  
    panres@gsnPaperOrientation = "portrait"
    panres@gsnPanelLabelBar = True
    panres@gsnPanelYWhiteSpacePercent = 3.0
    panres@pmLabelBarHeightF = 0.05
    panres@pmLabelBarWidthF = 0.65
    panres@lbTitleOn = False
    panres@lbBoxLineColor = "gray70"
    if (nsim.le.4) then
      if (nsim.eq.1) then
        panres@txFontHeightF = 0.022
        panres@gsnPanelBottom = 0.50
      else
        panres@txFontHeightF = 0.0145
        panres@gsnPanelBottom = 0.50
      end if
    else
      panres@txFontHeightF = 0.016
      panres@gsnPanelBottom = 0.05
    end if
    panres@lbLabelFontHeightF = 0.013
    panres@lbLabelStride = 1
    ncol = floattointeger(sqrt(nsim))
    nrow = (nsim/ncol)+mod(nsim,ncol)  
    panres@txString = "Global Monsoon Rainfall"
  gsn_panel2(wks_domain,map_domains,(/nrow,ncol/),panres)
  delete([/wks_domain,panres,res/])

;;;;Now plot the timeseries...
  ;set some unchanging plot resources
  xyres = True
  xyres@gsnDraw = False
  xyres@gsnFrame = False
  xyres@gsnRightString = ""
  xyres@gsnLeftString = ""
  xyres@gsnYRefLine = 0.0
  xyres@gsnYRefLineColor = "gray42"
  xyres@xyLineColor = "gray62"
  if (OUTPUT_TYPE.eq."png") then
    xyres@xyLineThicknessF = .75  
  else
    xyres@xyLineThicknessF = .5  
  end if   
  xyres@tiYAxisString = ""
  if (nsim.le.5) then
    xyres@tmXBLabelFontHeightF = 0.0125
    xyres@tmYLLabelFontHeightF = 0.0125
    xyres@gsnLeftStringFontHeightF = 0.017
    xyres@gsnCenterStringFontHeightF = 0.017
    xyres@gsnRightStringFontHeightF = 0.013         
  else
    xyres@tmXBLabelFontHeightF = 0.018
    xyres@tmYLLabelFontHeightF = 0.018
    xyres@gsnLeftStringFontHeightF = 0.024
    xyres@gsnCenterStringFontHeightF = 0.024
    xyres@gsnRightStringFontHeightF = 0.020    
  end if
  xyres@vpHeightF = 0.3
  xyres@gsnCenterString = ""
  xyres@tiMainOn = False
  xyres@gsnLeftStringOrthogonalPosF = 0.025
  xyres@gsnCenterStringOrthogonalPosF = xyres@gsnLeftStringOrthogonalPosF
  xyres@gsnRightStringOrthogonalPosF = xyres@gsnLeftStringOrthogonalPosF
  xyres@gsnXYAboveFillColors = "aquamarine4"
  xyres@gsnXYBelowFillColors = "peru"
  
  ;loop over the regions for average rainfall amount (and global)
  do plot_i=0,dimsizes(domain_names) 
    if plot_i.eq.0 then
      ;global
      rain_name="monsoon_rain_global"
      rain_title="Average summer rainfall over global monsoon domain (mm/day)"
    else
      rain_name="monsoon_rain_"+domain_names(plot_i-1)
      rain_title="Average monsoon rainfall over "+domain_names(plot_i-1)+" domain (mm/day)"
    end if
    wks_rain=gsn_open_wks(OUTPUT_TYPE,getenv("OUTDIR")+rain_name+".timeseries")
    gsn_define_colormap(wks_rain,"ncl_default")
    xy_rain = new(nsim,"graphic") 
    envelope_rain = new(nsim,"graphic") 
    do ee=0,nsim-1 ;loop over the models
      fn=filenames(ee)
      xyres@gsnLeftString = modnames(ee)
      if isfilepresent(fn) then
        z = addfile(fn,"r")
        if isfilevar(z,rain_name) then ;if area_name exists then both will 
          TIME=z->TIME
          nyears=dimsizes(TIME)
          if (SCALE_TIMESERIES.eq."True") then
            xyres@vpWidthF = (nyears*0.9)/nyr_max
          else
            xyres@vpWidthF = 0.9
          end if    
          ts_rain=z->$rain_name$
          if dimsizes(ts_rain).gt.(5*30) then
            ;plotting every year for 1000 year long control runs takes far too long
            ; and the result isn't visible. So just plot an s.d. envelope instead
            ; Chosen a cut-off at 150yrs. You may want to alter for historical runs
            runaveres=xyres
            runaveres@xyLineColor = "black"
            delete([/runaveres@gsnXYAboveFillColors,runaveres@gsnXYBelowFillColors/])
            nstddev=30 ;30 years
            ts_stddev=ts_rain
            ts_stddev(0:nstddev/2-1)=ts_rain@_FillValue
            ts_stddev(dimsizes(ts_stddev)-nstddev/2:dimsizes(ts_stddev)-1)=ts_rain@_FillValue
            do i=nstddev/2,dimsizes(ts_stddev)-nstddev/2-1
             ts_stddev(i)=dim_stddev(ts_rain(i-nstddev/2:i+nstddev/2))
            end do
            arr = new((/2,nyears/5/),typeof(ts_rain))
            spanner=ispan(0,nyears-1,1)
            tttt = dtrend_msg(spanner,ts_rain,False,True)
            ts_runave=runave(ts_rain,nstddev,0)
            runaveres@trYMaxF=max(ts_runave)+1.1*max(ts_stddev)
            runaveres@trYMinF=min(ts_runave)-1.1*min(ts_stddev)
            arr(0,:) = (/ ts_runave(:nyears-nyears%5-1:5) /)
            arr(1,:) = (/(spanner(:nyears-nyears%5-1:5)*tttt@slope)+tttt@y_intercept/)
            runaveres@gsnRightString = decimalPlaces(tttt@slope*nyears,2,True)+ts_rain@units+" "+\
                                 nyears+"yr~S~-1~N~"
            xy_rain(ee) = gsn_csm_xy(wks_rain,TIME(:nyears-nyears%5-1:5),arr,runaveres) 
            gsres=True
            gsres@gsFillColor="lightskyblue1"
            xlocs=new(2*dimsizes(TIME(:nyears-nyears%5-1:5)),float)
            xlocs(0:dimsizes(TIME(:nyears-nyears%5-1:5))-1)=TIME(:nyears-nyears%5-1:5)
            xlocs(dimsizes(TIME(:nyears-nyears%5-1:5)):2*dimsizes(TIME(:nyears-nyears%5-1:5))-1)=TIME(:nyears-nyears%5-1:-5)
            ylocs=new(2*dimsizes(TIME(:nyears-nyears%5-1:5)),float)
            ylocs(0:dimsizes(TIME(:nyears-nyears%5-1:5))-1)=ts_runave(:nyears-nyears%5-1:5)-ts_stddev(:nyears-nyears%5-1:5)
            ylocs(dimsizes(TIME(:nyears-nyears%5-1:5)):2*dimsizes(TIME(:nyears-nyears%5-1:5))-1)=ts_runave(:nyears-nyears%5-1:-5)+ts_stddev(:nyears-nyears%5-1:-5)
            gsres@tfPolyDrawOrder="PreDraw"
            envelope_rain(ee)=gsn_add_polygon(wks_rain, xy_rain(ee), xlocs, ylocs,gsres)
            delete([/TIME,nyears,ts_rain,arr,tttt,runaveres,gsres,xlocs,ylocs,ts_runave,ts_stddev,spanner/])
          else
            ;if less that 150 years, plot every single year
            arr = new((/2,nyears/),typeof(ts_rain))
            tttt = dtrend_msg(ispan(0,nyears-1,1),ts_rain,False,True)
            arr(0,:) = (/ ts_rain /)
            arr(1,:) = (/  (ispan(0,nyears-1,1)*tttt@slope)+tttt@y_intercept /)
            xyres@gsnRightString = decimalPlaces(tttt@slope*nyears,2,True)+ts_rain@units+" "+\
                                 nyears+"yr~S~-1~N~"
            xy_rain(ee) = gsn_csm_xy(wks_rain,ts_rain&TIME,arr,xyres) 
            delete([/TIME,nyears,ts_rain,arr,tttt/])
          end if
        end if ;isfilevar(z,vname+"_lnd")
        delete([/z/])
      end if ;isfilepresent(z)
      delete([/fn/])
    end do; the data processing loop over the models.
    ;And now actually create each rainfall amount panel plot...
    ncol = floattointeger(sqrt(nsim))
    nrow = (nsim/ncol)+mod(nsim,ncol) 
    panres = True
    panres@gsnMaximize = True
    panres@gsnPaperOrientation = "portrait"
    panres@gsnPanelYWhiteSpacePercent = 3.0
    if (nsim.le.10) then
      panres@txFontHeightF = 0.016
    else
      panres@txFontHeightF = 0.012
    end if
    if (SCALE_TIMESERIES.eq."True") then
      tt = ind(nyr.eq.nyr_max)
      panres@gsnPanelScalePlotIndex = tt(0)
      delete(tt)
    end if
    if (nsim.le.12) then
      lp = (/nsim,1/)
    else
      lp = (/nrow,ncol/)   ;(/nsim/2+1,nsim/8+1/)  
    end if
    if .not.all(ismissing(xy_rain)) then
      panres@txString = rain_title
      gsn_panel2(wks_rain,xy_rain,lp,panres)    
      delete([/wks_rain,xy_rain,rain_title,rain_name/])
    end if
  end do;loop over domains for rainfall amount

  ;loop over the regions for area (and global)
  do plot_i=0,dimsizes(domain_names) 
    if plot_i.eq.0 then
      ;global
      area_name="monsoon_area_global"
      area_title="Area of global monsoon domain (km2)"
    else
      area_name="monsoon_area_"+domain_names(plot_i-1)
      area_title="Area of "+domain_names(plot_i-1)+" monsoon domain (km2)"
    end if
    wks_area=gsn_open_wks(OUTPUT_TYPE,getenv("OUTDIR")+area_name+".timeseries")
    gsn_define_colormap(wks_area,"ncl_default")
    xy_area = new(nsim,"graphic") 
    envelope_area = new(nsim,"graphic") 

    do ee=0,nsim-1 ;loop over the models
      fn=filenames(ee)
      xyres@gsnLeftString = modnames(ee)
      if isfilepresent(fn) then
        z = addfile(fn,"r")
        if isfilevar(z,area_name) then ;if area_name exists then both will 
          TIME=z->TIME
          nyears=dimsizes(TIME)
          if (SCALE_TIMESERIES.eq."True") then
            xyres@vpWidthF = (nyears*0.9)/nyr_max
          else
            xyres@vpWidthF = 0.9
          end if    
          ts_area=z->$area_name$
          if dimsizes(ts_area).gt.(5*30) then
            ;plotting every year for 1000 year long control runs takes far too long
            ; and the result isn't visible. So just plot an s.d. envelope instead
            ; Chosen a cut-off at 150yrs. You may want to alter for historical runs
            runaveres=xyres
            runaveres@xyLineColor = "black"
            delete([/runaveres@gsnXYAboveFillColors,runaveres@gsnXYBelowFillColors/])
            nstddev=30 ;30 years
            ts_stddev=ts_area
            ts_stddev(0:nstddev/2-1)=ts_area@_FillValue
            ts_stddev(dimsizes(ts_stddev)-nstddev/2:dimsizes(ts_stddev)-1)=ts_area@_FillValue
            do i=nstddev/2,dimsizes(ts_stddev)-nstddev/2-1
             ts_stddev(i)=dim_stddev(ts_area(i-nstddev/2:i+nstddev/2))
            end do
            arr = new((/2,nyears/5/),typeof(ts_area))
            spanner=ispan(0,nyears-1,1)
            tttt = dtrend_msg(spanner,ts_area,False,True)
            ts_runave=runave(ts_area,nstddev,0)
            runaveres@trYMaxF=max(ts_runave)+1.1*max(ts_stddev)
            runaveres@trYMinF=min(ts_runave)-1.1*min(ts_stddev)
            arr(0,:) = (/ ts_runave(:nyears-nyears%5-1:5) /)
            arr(1,:) = (/(spanner(:nyears-nyears%5-1:5)*tttt@slope)+tttt@y_intercept/)
            runaveres@gsnRightString = decimalPlaces(tttt@slope*nyears,2,True)+ts_area@units+" "+\
                                 nyears+"yr~S~-1~N~"
            xy_area(ee) = gsn_csm_xy(wks_area,TIME(:nyears-nyears%5-1:5),arr,runaveres) 
            gsres=True
            gsres@gsFillColor="lightskyblue1"
            xlocs=new(2*dimsizes(TIME(:nyears-nyears%5-1:5)),float)
            xlocs(0:dimsizes(TIME(:nyears-nyears%5-1:5))-1)=TIME(:nyears-nyears%5-1:5)
            xlocs(dimsizes(TIME(:nyears-nyears%5-1:5)):2*dimsizes(TIME(:nyears-nyears%5-1:5))-1)=TIME(:nyears-nyears%5-1:-5)
            ylocs=new(2*dimsizes(TIME(:nyears-nyears%5-1:5)),float)
            ylocs(0:dimsizes(TIME(:nyears-nyears%5-1:5))-1)=ts_runave(:nyears-nyears%5-1:5)-ts_stddev(:nyears-nyears%5-1:5)
            ylocs(dimsizes(TIME(:nyears-nyears%5-1:5)):2*dimsizes(TIME(:nyears-nyears%5-1:5))-1)=ts_runave(:nyears-nyears%5-1:-5)+ts_stddev(:nyears-nyears%5-1:-5)
            gsres@tfPolyDrawOrder="PreDraw"
            envelope_area(ee)=gsn_add_polygon(wks_area, xy_area(ee), xlocs, ylocs,gsres)
            delete([/TIME,nyears,ts_area,arr,tttt,runaveres,gsres,xlocs,ylocs,ts_runave,ts_stddev,spanner/])
          else
            arr = new((/2,nyears/),typeof(ts_area))
            tttt = dtrend_msg(ispan(0,nyears-1,1),ts_area,False,True)
            arr(0,:) = (/ ts_area /)
            arr(1,:) = (/  (ispan(0,nyears-1,1)*tttt@slope)+tttt@y_intercept /)
            xyres@gsnRightString = decimalPlaces(tttt@slope*nyears,2,True)+ts_area@units+" "+\
                                 nyears+"yr~S~-1~N~"
            xy_area(ee) = gsn_csm_xy(wks_area,ts_area&TIME,arr,xyres) 
            delete([/TIME,nyears,ts_area,arr,tttt/])
          end if
        end if ;isfilevar(z,vname+"_lnd")
        delete([/z/])
      end if ;isfilepresent(z)
      delete([/fn/])
    end do; the data processing loop over the models.

    ;And now actually create each area panel plot...
    ncol = floattointeger(sqrt(nsim))
    nrow = (nsim/ncol)+mod(nsim,ncol) 
    panres = True
    panres@gsnMaximize = True
    panres@gsnPaperOrientation = "portrait"
    panres@gsnPanelYWhiteSpacePercent = 3.0
    if (nsim.le.10) then
      panres@txFontHeightF = 0.016
    else
      panres@txFontHeightF = 0.012
    end if
    if (SCALE_TIMESERIES.eq."True") then
      tt = ind(nyr.eq.nyr_max)
      panres@gsnPanelScalePlotIndex = tt(0)
      delete(tt)
    end if
    if (nsim.le.12) then
      lp = (/nsim,1/)
    else
      lp = (/nrow,ncol/)   ;(/nsim/2+1,nsim/8+1/)  
    end if
    if .not.all(ismissing(xy_area)) then
      panres@txString = area_title
      gsn_panel2(wks_area,xy_area,lp,panres)     
      delete([/wks_area,xy_area,area_title,area_name/])
    end if
  end do;loop over domains for area
  
  print("Finished: monsoon.ncl")
end
