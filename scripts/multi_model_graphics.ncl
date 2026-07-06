; Creates graphics for the multi-model ensemble statistics (runstyle 3).
;
; For every <experiment group>_minus_<control group>.cvdp_mmm.nc file in OUTDIR (created by
; multi_model_stats.ncl), each 2D lat x lon diagnostic gets a 4-panel figure:
;   (a) experiment multi-model mean          (b) control multi-model mean
;   (c) multi-model mean anomaly, stippled   (d) cross-model standard deviation
;       where >= 2/3 of models agree on the sign of the anomaly
; written as mmm.<experiment group>_minus_<control group>.<variable>.<png/ps>, plus a
; simple <experiment group>_minus_<control group>.mmm.html index page linking the images.
;
; lev x lat (AMOC) fields and scalar index statistics are not plotted; they are available
; in the .cvdp_mmm.nc file.
;
load "$CVDP_SCRIPTS/functions.ncl"

begin
  print("Starting: multi_model_graphics.ncl")
  OUTDIR      = getenv("OUTDIR")
  OUTPUT_TYPE = getenv("OUTPUT_TYPE")
  PNG_SCALE   = tofloat(getenv("PNG_SCALE"))
  VERSION     = getenv("VERSION")

  fils = systemfunc("ls "+OUTDIR+"*.cvdp_mmm.nc 2> /dev/null")
  if (ismissing(fils(0))) then
     print("multi_model_graphics.ncl: no .cvdp_mmm.nc files found in "+OUTDIR+". Exiting.")
     exit
  end if

  wks_type = OUTPUT_TYPE
  if (wks_type.eq."png") then
     wks_type@wkWidth = 1500*PNG_SCALE
     wks_type@wkHeight = 1500*PNG_SCALE
  end if

  do ff = 0,dimsizes(fils)-1
     f = addfile(fils(ff),"r")
     tmp := str_split(fils(ff),"/")
     fprefix = str_sub_str(tmp(dimsizes(tmp)-1),".cvdp_mmm.nc","")
     expgrp = fprefix
     ctlgrp = ""
     if (isatt(f,"experiment_group")) then
        expgrp = f@experiment_group
     end if
     if (isatt(f,"control_group")) then
        ctlgrp = f@control_group
     end if

     vnames := getfilevarnames(f)
     htmlrows := new(dimsizes(vnames)+8,string)
     nrow = 0
     nplotted = 0
     do vv = 0,dimsizes(vnames)-1
        vn = vnames(vv)
        if (.not.str_match_bool(vn,"_anom_mmm")) then
           continue
        end if
        if (str_match_bool(vn,"_sd_anom_mmm")) then
           continue                          ; scalar index statistics, nothing to map
        end if
        dnames := getfilevardims(f,vn)
        if (dimsizes(dnames).ne.2) then
           continue
        end if
        if (.not.(dnames(0).eq."lat".and.dnames(1).eq."lon")) then
           continue                          ; lev x lat (AMOC) fields are not plotted
        end if
        base = str_sub_str(vn,"_anom_mmm","")

        anom := f->$vn$
        vno = base+"_mmm"
        mmm := f->$vno$
        vno = base+"_ctl_mmm"
        ctl := f->$vno$
        vno = base+"_anom_stddev"
        sdv := f->$vno$
        vno = base+"_anom_signagree"
        sa := f->$vno$
        if (all(ismissing(anom))) then
           continue
        end if

        wks = gsn_open_wks(wks_type,OUTDIR+"mmm."+fprefix+"."+base)
        plot := new(4,graphic)

        res = True
        res@gsnDraw = False
        res@gsnFrame = False
        res@mpFillOn = False
        res@mpGeophysicalLineColor = "gray42"
        res@cnFillOn = True
        res@cnLinesOn = False
        res@cnLineLabelsOn = False
        res@cnInfoLabelOn = False
        res@lbLabelBarOn = True
        res@lbLabelFontHeightF = 0.016
        res@gsnStringFontHeightF = 0.02
        res@gsnLeftStringOrthogonalPosF = 0.03
        res@gsnRightStringOrthogonalPosF = 0.03
        vunits = ""
        if (isatt(anom,"units")) then
           vunits = anom@units
        end if
        res@gsnRightString = vunits

        resM = res                           ; panels (a)+(b): common levels across experiment and control
        resM@cnFillPalette = "WhiteBlueGreenYellowRed"
        mnx = nice_mnmxintvl(min((/min(mmm),min(ctl)/)),max((/max(mmm),max(ctl)/)),14,False)
        if (.not.ismissing(mnx(0)).and.mnx(0).lt.mnx(1)) then
           resM@cnLevelSelectionMode = "ManualLevels"
           resM@cnMinLevelValF = mnx(0)
           resM@cnMaxLevelValF = mnx(1)
           resM@cnLevelSpacingF = mnx(2)
        end if
        resM@gsnLeftString = expgrp+" multi-model mean"
        plot(0) = gsn_csm_contour_map(wks,mmm,resM)
        resM@gsnLeftString = ctlgrp+" multi-model mean"
        plot(1) = gsn_csm_contour_map(wks,ctl,resM)

        resA = res                           ; panel (c): symmetric levels around 0
        resA@cnFillPalette = "BlueWhiteOrangeRed"
        amax = max((/fabs(min(anom)),fabs(max(anom))/))
        if (.not.ismissing(amax).and.amax.gt.0) then
           mnx = nice_mnmxintvl(-amax,amax,14,False)
           resA@cnLevelSelectionMode = "ManualLevels"
           resA@cnMinLevelValF = mnx(0)
           resA@cnMaxLevelValF = mnx(1)
           resA@cnLevelSpacingF = mnx(2)
        end if
        resA@gsnLeftString = "anomaly (stippled: >= 2/3 of models agree on sign)"
        plot(2) = gsn_csm_contour_map(wks,anom,resA)

        if (.not.all(ismissing(sa))) then    ; stipple where the sign agreement is at least 2/3
           sres = True
           sres@gsnDraw = False
           sres@gsnFrame = False
           sres@cnFillOn = False
           sres@cnLinesOn = False
           sres@cnLineLabelsOn = False
           sres@cnInfoLabelOn = False
           sres@gsnLeftString = ""
           sres@gsnRightString = ""
           sres@cnLevelSelectionMode = "ExplicitLevels"
           sres@cnLevels = (/0.667/)
           sp = gsn_csm_contour(wks,sa,sres)
           sopt = True
           sopt@gsnShadeFillType = "pattern"
           sopt@gsnShadeHigh = 17
           sp = gsn_contour_shade(sp,0.,0.667,sopt)
           overlay(plot(2),sp)
        end if

        resS = res                           ; panel (d): cross-model spread
        resS@cnFillPalette = "WhiteYellowOrangeRed"
        mnx = nice_mnmxintvl(0.,max(sdv),12,False)
        if (.not.ismissing(mnx(0)).and.mnx(0).lt.mnx(1)) then
           resS@cnLevelSelectionMode = "ManualLevels"
           resS@cnMinLevelValF = mnx(0)
           resS@cnMaxLevelValF = mnx(1)
           resS@cnLevelSpacingF = mnx(2)
        end if
        resS@gsnLeftString = "cross-model standard deviation of anomalies"
        plot(3) = gsn_csm_contour_map(wks,sdv,resS)

        panres = True
        panres@gsnMaximize = True
        panres@gsnPaperOrientation = "portrait"
        panres@gsnPanelMainString = base+"   ("+expgrp+" minus "+ctlgrp+")"
        panres@gsnPanelMainFontHeightF = 0.016
        gsn_panel(wks,plot,(/2,2/),panres)
        delete(wks)

        htmlrows(nrow) = "<tr><td>"+base+"</td><td><a href='mmm."+fprefix+"."+base+".png'><img src='mmm."+fprefix+"."+base+".png' width='600'></a></td></tr>"
        nrow = nrow+1
        nplotted = nplotted+1
        delete([/res,resM,resA,resS,panres/])
     end do

     if (nplotted.ge.1) then
        header = (/"<html><head><title>Multi-model mean: "+expgrp+" minus "+ctlgrp+"</title></head><body>", \
                   "<h1>Multi-model mean: "+expgrp+" minus "+ctlgrp+"</h1>", \
                   "<p>Created by the Climate Variability Diagnostics Package v"+VERSION+" (runstyle 3). Data: <a href='"+fprefix+".cvdp_mmm.nc'>"+fprefix+".cvdp_mmm.nc</a></p>", \
                   "<table border='1'>"/)
        footer = (/"</table></body></html>"/)
        html := array_append_record(header,htmlrows(:nrow-1),0)
        html := array_append_record(html,footer,0)
        asciiwrite(OUTDIR+fprefix+".mmm.html",html)
        print("multi_model_graphics.ncl: created "+nplotted+" figures and "+fprefix+".mmm.html")
     else
        print("multi_model_graphics.ncl: no plottable lat x lon multi-model fields found in "+fils(ff))
     end if
  end do
  print("Finished: multi_model_graphics.ncl")
end
