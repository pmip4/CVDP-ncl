; Calculates the pr area averages for the IPCC reference regions
; Variables used: pr
;
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/shea_util.ncl"
load "$CVDP_SCRIPTS/functions.ncl"
load "$CVDP_SCRIPTS/extract_all_AR5_regions.ncl"

begin
  print("Starting: pr.indices.ncl")
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
    filenames(ee) = getenv("OUTDIR")+modnames(ee)+".cvdp_data.pr.indices."+syear(ee)+"-"+eyear(ee)+".nc"
  end do
  
  nyr_max = max(nyr)

;--------------------------------------------------------------------------------------     
; loop over the models  
  do ee = 0,nsim-1
;--------------------------------------------------------------------------------------     
; In a departure from CVDP standard practice, there is no option to NOT write out data.
; Instead to enable loop over the many different indices, the data is always written out
; and then read back in later for plotting.
    
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
    ;skip this model if it's all missing 
    if isatt(pr,"is_all_missing") then
      delete(pr)
      continue
    else
      if (OPT_CLIMO.eq."Full") then
        climo = clmMonTLL(pr)
        pr = rmMonAnnCycTLL(pr)
      else
        check_custom_climo(names(ee),syear(ee),eyear(ee),CLIMO_SYEAR,CLIMO_EYEAR)
        temp_arr = pr
        delete(temp_arr&time)
        temp_arr&time = cd_calendar(pr&time,-1)
        if (CLIMO_SYEAR.lt.0) then
           climo = clmMonTLL(temp_arr({(eyear(ee)+CLIMO_SYEAR)*100+1:(eyear(ee)+CLIMO_EYEAR)*100+12},:,:))       
        else
           climo = clmMonTLL(temp_arr({CLIMO_SYEAR*100+1:CLIMO_EYEAR*100+12},:,:))                 
        end if
        delete(temp_arr)
        pr   = calcMonAnomTLL(pr,climo) 
      end if ;We'll compute the absolute area average, rather than the anomaly (I feel that is more useful)
      
      if typeof(pr).ne."float" then
         temp_arr=pr
         delete(pr)
         pr=tofloat(temp_arr)
         copy_VarMeta(temp_arr, pr)
         delete(temp_arr)
         temp_arr=climo
         delete(climo)
         climo=tofloat(temp_arr)
         copy_VarMeta(temp_arr, climo)
         delete(temp_arr)
      end if

      ;Use the special extract_all_AR5_regions function to compute all the area averages
      all_region_avgs=extract_all_AR5_regions(pr,False)
      all_region_climos=extract_all_AR5_regions(climo,False) 
      region_names=str_split(all_region_avgs@region_names,",")

      ;Having made all the timeseries, it is time to write them to the output file
      do reg_i=0,dimsizes(region_names)-1
        ;store the indices in the netcdf file
        pr_ind=all_region_avgs(reg_i,:)
        if .not.isfilevar(z,"date").and.isvar("pr_ind") then
          date = cd_calendar(pr_ind&time,-1)
          date@long_name = "current date (YYYYMM)"
          delete(date@calendar)
          date!0 = "time"
          date&time = pr_ind&time
          date@units = "1"
          z->date = date
          delete(date)
        end if
        if isvar("pr_ind") then
          vname="ipcc_"+region_names(reg_i)+"_pr"
          longname=region_names(reg_i)+" area_avgd precip"
          delete(pr_ind@region_names)
          pr_ind@region_name=region_names(reg_i)
          pr_ind@AnnCycle=(/all_region_climos(reg_i,:)/)
          pr_ind@comment = "Area average for "+region_names(reg_i)+" (extr. with 1x1o mask)"
          z->$vname$ = set_varAtts(pr_ind,longname,"","") 
          delete([/pr_ind,vname,longname/])
        end if
      end do; loop over the regions
      ;tidy up
      delete([/pr,all_region_avgs,climo/])
    end if; if all(ismissing(pr))
    delete([/modname,fn/])
  end do; the data processing loop over the models.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Another loop (over the indices) for plotting purposes.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ;set some unchanging plot resources
  xyres = True
  xyres@gsnDraw = False
  xyres@gsnFrame = False
  xyres@gsnRightString = ""
  xyres@gsnLeftString = ""
  xyres@gsnYRefLine = 0.0
  xyres@gsnYRefLineColor = "gray42"
  xyres@xyLineColor = "gray62"
  xyres@gsnXYAboveFillColors = "red"
  xyres@gsnXYBelowFillColors = "blue"
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
  
  do reg_i=0,dimsizes(region_names)-1 ;loop over the regions
    wks_type = OUTPUT_TYPE
    if (wks_type.eq."png") then
      wks_type@wkWidth = 1500*PNG_SCALE
      wks_type@wkHeight = 1500*PNG_SCALE
    end if
    wks_reg=gsn_open_wks(wks_type,getenv("OUTDIR")+"ipcc_"+region_names(reg_i)+"_pr.timeseries")
    gsn_define_colormap(wks_reg,"ncl_default")
    xy_reg = new(nsim,"graphic") 
    envelope = new(nsim,"graphic")    

    vname="ipcc_"+region_names(reg_i)+"_pr"
    
    do ee=0,nsim-1 ;plotting loop over the models
      ;set some varying plot resources
      if (SCALE_TIMESERIES.eq."True") then
        xyres@vpWidthF = 0.9*((nyr(ee)*1.)/nyr_max)
      else
        xyres@vpWidthF = 0.9
      end if    
      xyres@trXMinF = syear(ee)-.5
      xyres@trXMaxF = eyear(ee)+1.5
      xyres@gsnLeftString = names(ee)

      modname=modnames(ee)
      fn=filenames(ee)
      if isfilepresent(fn) then
        z = addfile(fn,"r")
        if isfilevar(z,vname) then
          pr_ind=z->$vname$
          time = z->time
          nyears=dimsizes(pr_ind)/12
          if nyears.gt.(5*30) then
            ;this routine can be really slow to plot 100s of years of monthly data,
            ;so if longer than 150yrs then just show a running std. dev. instead 
            runaveres=xyres
            runaveres@xyLineColor = "black"
            delete([/runaveres@gsnXYAboveFillColors,runaveres@gsnXYBelowFillColors/])
            nstddev=30 ;5 years in months
            ts_stddev=pr_ind
            ts_stddev(0:nstddev/2-1)=pr_ind@_FillValue
            ts_stddev(dimsizes(ts_stddev)-nstddev/2:dimsizes(ts_stddev)-1)=pr_ind@_FillValue
            do i=nstddev/2,dimsizes(ts_stddev)-nstddev/2-1
             ts_stddev(i)=dim_stddev(pr_ind(i-nstddev/2:i+nstddev/2))
            end do
            arr = new((/2,nyears/5/),typeof(pr_ind))
            spanner=ispan(0,dimsizes(pr_ind)-1,1)
            tttt = dtrend_msg(spanner,pr_ind,False,True)
            ts_runave=runave(pr_ind,nstddev,0)
            runaveres@trYMaxF=max(ts_runave)+1.1*max(ts_stddev)
            runaveres@trYMinF=min(ts_runave)-1.1*min(ts_stddev)
            arr(0,:) = (/ ts_runave(:12*(nyears-nyears%5)-11:60) /)
            arr(1,:) = (/(spanner(:12*(nyears-nyears%5)-11:60)*tttt@slope)+tttt@y_intercept/)
            runaveres@gsnRightString = decimalPlaces(tttt@slope*nyears,2,True)+pr_ind@units+" "+\
                                 nyears+"yr~S~-1~N~"
            time_subset=fspan(syear(ee),eyear(ee)+.91667,nyears/5)
            xy_reg(ee) = gsn_csm_xy(wks_reg,time_subset,arr,runaveres) 
            gsres=True
            gsres@gsFillColor="lightskyblue1"
            xlocs=new(2*dimsizes(time_subset),float)
            xlocs(0:dimsizes(time_subset)-1)=time_subset
            xlocs(dimsizes(time_subset):2*dimsizes(time_subset)-1)=time_subset(::-1)
            ylocs=new(2*dimsizes(time(:12*(nyears-nyears%5)-11:60)),float)
            ylocs(0:dimsizes(time(:12*(nyears-nyears%5)-11:60))-1)=ts_runave(:12*(nyears-nyears%5)-11:60)-ts_stddev(:12*(nyears-nyears%5)-11:60)
            ylocs(dimsizes(time(:12*(nyears-nyears%5)-11:60)):2*dimsizes(time(:12*(nyears-nyears%5)-11:60))-1)=ts_runave(:12*(nyears-nyears%5)-11:-60)+ts_stddev(:12*(nyears-nyears%5)-11:-60)
            gsres@tfPolyDrawOrder="PreDraw"
            envelope(ee)=gsn_add_polygon(wks_reg, xy_reg(ee), xlocs, ylocs,gsres)
            title = pr_ind@comment
            delete([/pr_ind,arr,tttt,runaveres,gsres,xlocs,ylocs,ts_runave,ts_stddev,spanner,time_subset/])
          else
            arr = new((/2,dimsizes(pr_ind)/),typeof(pr_ind))
            tttt = dtrend_msg(ispan(0,dimsizes(pr_ind)-1,1),pr_ind,False,True)
            arr(0,:) = (/ pr_ind /)
            arr(1,:) = (/  (ispan(0,dimsizes(pr_ind)-1,1)*tttt@slope)+tttt@y_intercept /)
            xyres@gsnRightString = decimalPlaces(tttt@slope*dimsizes(pr_ind),2,True)+pr_ind@units+" "+nyr(ee)+"yr~S~-1~N~"
            xy_reg(ee) = gsn_csm_xy(wks_reg,fspan(syear(ee),eyear(ee)+.91667,dimsizes(pr_ind)),arr,xyres) 
            title = pr_ind@comment
            delete([/tttt,pr_ind,arr/])
          end if
          delete([/time,nyears/])
        end if ;isfile(z).and.isfilevar(fn,"pr_ind")
        delete(z)
      end if ;isfilepresent(z)
      delete([/modname,fn/])
    end do; the plotting loop over the models.

    ;And now actually create the panel plots...
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

    if isvar("xy_reg").and..not.all(ismissing(xy_reg)) then
      panres@txString = title
      gsn_panel2(wks_reg,xy_reg,lp,panres)    
      delete([/wks_reg,xy_reg,title/])
    end if
    delete([/panres/])
    ;finished plotting sections
  end do; loop over the regions
  print("Finished: pr.indices.ncl")
end
