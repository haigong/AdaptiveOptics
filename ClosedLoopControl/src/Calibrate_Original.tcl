#==========================================================================
# 
# 			Adaptive Optics Associates
# 			  54 CambridgePark Drive
# 			 Cambridge, MA 02140-2308
# 				    USA
# 			   (Phone) 617-864-0201
# 			    (Fax) 617-864-1348
# 
#                Copyright 1999 Adaptive Optics Associates
# 			    All Rights Reserved
# 
#==========================================================================

#--------------------------------------------------------------------------
# 
# FILE: Calibrate.tcl
# 
# DESCRIPTION:	
#   Procedures to perform system calibration for WaveScope
# 
# $Id: Calibrate.tcl,v 1.85 1999/09/29 17:02:12 stacy Exp $
# 
#--------------------------------------------------------------------------


#--------------------------------------------------------------------------
# proc Calibrate
#
# Procedure to perform system calibration.
#--------------------------------------------------------------------------

proc Calibrate { {mode "custom"} } {

  global wlCalibrate ws_stat DisplayFlag platform calMode calFiles 
    

  # Have we initialized yet?
  #
  set calMode $mode
  if { $wlCalibrate(doneInit) == "No" || $mode == "full" } {
    # Set the calibration procedure flags
    #
    foreach obj { PupilSubFlg PupilLocFlg RefRectFlg TestSubapFlg RefSpotsFlg \
                 PupilDataFlg circFlg IntFlg } {
      set wlCalibrate($obj) "Yes"
    }
    set wlCalibrate(CalcAveFlg) "No"

    if { $wlCalibrate(doneInit) == "No" } {
      set wlCalibrate(RefMode) "Take New Data"
      set wlCalibrate(EditSubFlg) "No"
    }
  }

  # Initialize Calibration data
  #
  if { [CalInit] == "Abort" } { return "Abort" }

  # Custom Reduction option creates a panel to select Test Source
  # Calibration changes and saving option
  #
  if { $calMode == "reduce" } {
    if { [ReduceSetupPanel] == "Abort" } { 
      set DisplayFlag 0
      return "Abort"
    } else {
      # No calibration updates
      #
      if { $wlCalibrate(PupilLocFlg) == "No" && \
      	     $wlCalibrate(EditSubFlg) == "No" && \
      	     $wlCalibrate(circFlg) == "No" } {
	return "NoCal"
      }
    }
    # Load all images except CloserPupilImage and FartherPupilImage
    #
    set refFiles {CloserRefSpots BestRefSpots}
    if { [CalLoadData $refFiles] == "Abort" } { 
      set DisplayFlag 0
      return "Abort"
    }
    if { [CalLoadTestData] == "Abort" } {
      set DisplayFlag 0
      return "Abort"
    }
    
  } else {     
    # Put up the calibration options selection box ( from Calibration
    # pull-down menu ) 
    #
    if { [CalibrateSetup] == "Abort" } { 
      set DisplayFlag 0
      return "Abort"
    }

    # Determine the pupil shape
    #
    set shape_flag "FALSE"
    while { $shape_flag == "FALSE" } {
      if { (![info exists wlCalibrate(PupilShape)]) || \
	     ($wlCalibrate(PupilShape) == "") } {
	wl_PanelsWarn "A Pupil Shape must be selected."
	if { [ CalibrateSetup ] == "Abort" } { 
	  set DisplayFlag 0
	  return "Abort"
	}
      } else { 
	set shape_flag "TRUE"
      }
    }

    
    # Grab or load Reference Source calibration data
    #
    if { $wlCalibrate(RefMode) == "Take New Data" } {
      if { [CalRefCollect] == "Abort" } {
	if { [winfo exists .waitwin] } { destroy .waitwin }
	set DisplayFlag 0
	CalCancel
	return "Abort"
      }
    } else {
      if { [CalLoadRefData] == "Abort" } {
	set DisplayFlag 0
	return "Abort"
      }
    }
  }

  # Grab or load Test Source calibration data
  #
  if { $wlCalibrate(TestSubapFlg) == "Yes" ||
       $wlCalibrate(PupilDataFlg) == "Yes" } {
    if { [CalTestCollect] == "Abort" } {
      if { [winfo exists .waitwin] } { destroy .waitwin }
      set DisplayFlag 0
      CalCancel
      return "Abort"
    }
  } else {
    if { [CalLoadTestData] == "Abort" } {
      set DisplayFlag 0
      return "Abort"
    }
  }


  # Perform the calibration calculations.
  # Note that if none of the calibration flags are set by the user,
  # the action here is to simply load the calibration data from disk
  #
  set calObjList { CalLensletPos CalPupilGeometry CalRefRects CalRefMatches \
		     CalTestRect CalTestMatches CalMatches CalRefPos }
  foreach obj $calObjList {
    if { [$obj] == "Abort" } {
      if { [winfo exists .waitwin] } { destroy .waitwin }
      set DisplayFlag 0
      CalCancel
      return "Abort"
    }
  }
  

  # Set flag to show calibration done
  #
  set ws_stat(caldir) set
  ws_SetGradCal
  
  
  # Unset image display window just to be sure it is really gone
  #
  if { [info exist wlCalibrate(id)] } { 
    unset wlCalibrate(id)
  }

  if { [winfo exists .waitwin] } { destroy .waitwin }
  wl_PanelsMsg "Calibration completed!"

  # Copy the calData file if it exists to calData.tcl
  #
  set calD $wlCalibrate(saveDir)/calData

  # Delete all temporary calibration files
  #  
  if { $calMode == "reduce" } { 
    if { [file exists $calD] } {
      if { $platform == "windows" } {
	file delete $calD
      } else {
	exec rm -f $calD
      }
    }
    lappend calFiles calData
    foreach obj $calFiles  {
      if { [file exists $wlCalibrate(saveDir)/$obj.tmp] } {
	if { $platform == "windows" } {
	  file delete $wlCalibrate(saveDir)/$obj.tmp
	} else {
	  exec rm -f $wlCalibrate(saveDir)/$obj.tmp
	}
      }
    }
    set calFiles [ldelete $calFiles calData]
    
  } else {

    # Rename all temporary calibration files, to make them the "existing" data.
    #	  
    if { [file exists $calD] } {
      if { $platform == "windows" } {
	file copy -force $calD $wlCalibrate(saveDir)/calData.tcl
      } else {
	exec cp -f $calD $wlCalibrate(saveDir)/calData.tcl
      }
    }
    foreach obj $calFiles {
      if { [file exists $wlCalibrate(saveDir)/$obj.tmp] } {
	if { $platform == "windows" } {
	  file rename -force $wlCalibrate(saveDir)/$obj.tmp $wlCalibrate(saveDir)/$obj
	} else {
	  exec mv -f $wlCalibrate(saveDir)/$obj.tmp $wlCalibrate(saveDir)/$obj
	}
      }
    }
  }

}

##-------------------------------------------------------------------
## proc CalInit
##
## Initialize the calibration object
##-------------------------------------------------------------------

proc CalInit { } {

  global wlCalibrate wlData wlParam wlPanel ws_stat DisplayFlag
  global platform


  # Initialize the Help Text
  #
  wsInitCalHelp

  # Initialize the id window position
  #
  if { $platform == "windows" } {
    set wlCalibrate(idxpos) 300
  } else {
    set wlCalibrate(idxpos) 500
  }
  set wlCalibrate(idypos) 200

  if { [file exists $wlCalibrate(saveDir)] } {
    set fileid [open $wlCalibrate(saveDir)/calData a]
    puts $fileid "set wlCalibrate(idxpos) {$wlCalibrate(idxpos)}"
    puts $fileid "set wlCalibrate(idypos) {$wlCalibrate(idypos)}"
    close $fileid
  }
  
  # Initialize the test window position
  #
  set wlPanel(alertWinGeometry) +100+530
  
  # Set the names for each of the calibration files
  #
  set wlCalibrate(fileNames)	\
    "Centers CloserPupilImage FartherPupilImage FinalCenters FinalMatches \
    FinalRefRects FinalTestRects Params Pupil PupilImage BestRefSpots \
    CloserRefSpots RefMatches RefPos RefRects RefSpots BestTestSpots \
    CloserTestSpots TestMatches TestRects"

  # Initialize all of the calibration data forms
  #
  foreach name $wlCalibrate(fileNames) {
    set wlCalibrate($name) "Unset"
  }

  # Set the calibration source directory
  #
  if { ![file exists $wlCalibrate(loadDir)] } {
    if { $platform == "windows" } {
      file mkdir $wlCalibrate(loadDir)
    } else {
      exec mkdir $wlCalibrate(loadDir)
    }
  }	
  
  # By default, use a single frame
  #
  set wlCalibrate(refType) "single"
  
  # We need to setup after initialization
  #
  set wlCalibrate(doneSetup) 	"No"

  # Set parameters based on MLM selection
  #
  if { [VerifyMLM] == "Abort" } {
    set DisplayFlag 0
    return "Abort"
  }
  
  if { [ws_SetWSParams] == "Abort" } \
    {
      if { [winfo exists .waitwin] } { destroy .waitwin }
      set DisplayFlag 0
      return "Abort"
    }

  # Done with initialization
  #
  set DisplayFlag 0
  set wlCalibrate(doneInit)	"Yes"
}

#--------------------------------------------------------------------------
# proc CalCancel
#
# This proc should be called before aborting calibration to clean up
# temporary files.
#--------------------------------------------------------------------------

proc CalCancel {} {

  global wlCalibrate platform calFiles

  foreach obj $calFiles {
    if { [file exists $wlCalibrate(saveDir)/$obj.tmp] } {
      if { $platform == "windows" } {
	file delete $wlCalibrate(saveDir)/$obj.tmp
      } else {
	exec rm -f $wlCalibrate(saveDir)/$obj.tmp
      }
    }
  }

  CalLoadRunData $wlCalibrate(saveDir)
}


#--------------------------------------------------------------------------
# procs CalLoadRefData and CalLoadTestData
#
# A little boilerplate to load relevant data files.
#--------------------------------------------------------------------------

proc CalLoadRefData {} {
  set refFiles {CloserPupilImage FartherPupilImage CloserRefSpots BestRefSpots}
  return [CalLoadData $refFiles]
}

proc CalLoadTestData {} {
  set testFiles { CloserTestSpots BestTestSpots PupilImage }
  return [CalLoadData $testFiles]
}


#--------------------------------------------------------------------------
# proc CalibrateSetup
#
# Puts up the calibration setup dialog box, and waits for the user to
# click one of the control buttons.  Exits on "OK" or "Cancel"
#--------------------------------------------------------------------------

proc CalibrateSetup { } {

  global wlPanel wlData wlCalibrate calMode


  # Perform the calibration setup
  #
  set msg   "Select Calibration Options"
  set blist "\"  OK  \""
  lappend blist "set wlPanel(action) \"SetupDone\""
  lappend blist "Cancel"
  lappend blist "set wlPanel(action) \"SetupAbort\""
  lappend blist "Help"
  lappend blist "ShowHelp CalSetup.html"

  PanelsGenericFrame .wcalsetup $msg CalSetupPanel "create" $blist

  wm geometry .wcalsetup +200+85

  while { 1 } {
    tkwait variable wlPanel(action)
    
    if { $wlPanel(action) == "SetupDone" } {
      if { $wlCalibrate(RefMode) == "Take New Data" &&
           $wlCalibrate(PupilSubFlg) == "No" &&
           $wlCalibrate(RefRectFlg) == "No" &&
           $wlCalibrate(RefSpotsFlg) == "No" &&
           $wlCalibrate(CalcAveFlg) == "No" } {
	wl_PanelsWarn "You must select a Reference Source option, or select Use Existing Data." +300+150 12c
      } else {
	set wlCalibrate(doneSetup) "Yes"
	if {[winfo exist .wcalsetup]} {destroy .wcalsetup}
	SaveDefaultPupilShape
	return "OK"
      }
    }

    if { $wlPanel(action) == "SetupAbort" } {
      if {[winfo exist .wcalsetup]} {destroy .wcalsetup}
      return "Abort"
    } 
  } 
}


#--------------------------------------------------------------------------
# proc CalTogDepend
#
# Implement dependencies between calibration options by toggling on/off
# checkbuttons in the selection panel.
#--------------------------------------------------------------------------

proc CalTogDepend { flag } {

  global wlCalibrate


  set state $wlCalibrate($flag)

  if { $state == "Yes" } {
    # When an option is toggled on, toggle on all other options that
    # it depends on.
    #
    set depend(PupilSubFlg)  {RefRectFlg TestSubapFlg RefSpotsFlg PupilLocFlg PupilDataFlg}
    set depend(RefRectFlg)   {TestSubapFlg RefSpotsFlg}
    set depend(PupilDataFlg) {PupilLocFlg TestSubapFlg}
    set depend(PupilLocFlg)  {}
    set depend(TestSubapFlg) {}
    set depend(RefSpotsFlg)  {}

    foreach item $depend($flag) {
      set wlCalibrate($item) "Yes"
    }
  } else {
    # When an option is toggled off, toggle off all other options that
    # require it.
    #
    set depend(PupilSubFlg)  {}
    set depend(PupilDataFlg) {PupilSubFlg}
    set depend(RefRectFlg)   {PupilSubFlg}
    set depend(PupilLocFlg)  {PupilDataFlg PupilSubFlg}
    set depend(RefSpotsFlg)  {PupilSubFlg RefRectFlg}
    set depend(TestSubapFlg) {PupilSubFlg RefRectFlg PupilDataFlg}

    foreach item $depend($flag) {
      set wlCalibrate($item) "No"
    }
  }
  update 
}

                
#--------------------------------------------------------------------------
# proc RefCalSelect
#
# When the user click on the radio buttons, ensures the correct toggle
# buttons are available/not available.
#--------------------------------------------------------------------------

proc RefCalSelect { } {

  global wlCalibrate


  if { $wlCalibrate(RefMode) == "Take New Data" } {
    .wcalsetup.topf.refsrc.frm.right.ave configure -state normal
    .wcalsetup.topf.refsrc.frm.right.pupila configure -state normal
    .wcalsetup.topf.refsrc.frm.right.refrect configure -state normal
    .wcalsetup.topf.refsrc.frm.right.refpos configure -state normal
    set wlCalibrate(RefSpotsFlg) "Yes"
  } else {
    .wcalsetup.topf.refsrc.frm.right.ave configure -state disabled
    .wcalsetup.topf.refsrc.frm.right.pupila configure -state disabled
    .wcalsetup.topf.refsrc.frm.right.refrect configure -state disabled
    .wcalsetup.topf.refsrc.frm.right.refpos configure -state disabled
    set wlCalibrate(CalcAveFlg) "No"
    set wlCalibrate(PupilSubFlg) "No"
    set wlCalibrate(RefRectFlg) "No"
    set wlCalibrate(RefSpotsFlg) "No"
    CalTogDepend PupilSubFlg
    CalTogDepend RefRectFlg
    CalTogDepend RefSpotsFlg
  }
}

                
#--------------------------------------------------------------------------
# proc CalSetupPanel win msg
#
# Creates the main panel for the calibration setup.
# The panel displays different options depending on calibration type.
#--------------------------------------------------------------------------

proc CalSetupPanel { win msg } {

  global wlPanel wlCalibrate calMode

  # A radio box for selection of pupil shape
  #
  frame $win.pupil -relief ridge -borderwidth 3
  pack  $win.pupil -side top -padx 2m -pady 2m -fill both
  
  label $win.pupil.label1 -text "Pupil Shape"
  pack  $win.pupil.label1 -side top  -padx 2m -pady 2m -fill both
  
  frame $win.pupil.frm3 -relief sunken
  pack  $win.pupil.frm3 -side top -padx 2m -pady 2m -fill both
  
  set choices { "Circular" "Rectangular" }
  set b 0
  foreach item $choices {
    radiobutton $win.pupil.frm3.radio$b -text $item -width 25 \
      -variable wlCalibrate(PupilShape) -value $item -highlightthickness 0
    pack  $win.pupil.frm3.radio$b -side left 
    incr b
  }

  
  if { $calMode == "custom" } {
    # A box for selection of Reference Source calibration parameters
    #
    frame $win.refsrc -relief ridge -borderwidth 3
    pack  $win.refsrc -side top -padx 2m -pady 2m -fill both
    
    label $win.refsrc.label1 -text "Reference Source Calibration"
    pack  $win.refsrc.label1 -side top  -padx 2m -pady 2m -fill x
    
    frame $win.refsrc.frm
    pack  $win.refsrc.frm -fill x
    
    frame $win.refsrc.frm.left
    pack  $win.refsrc.frm.left -anchor w -side left -fill x
    frame $win.refsrc.frm.right
    pack  $win.refsrc.frm.right -anchor e -side left -fill x
    
    set choices { "Take New Data" "Use Existing Data" }
    set b 0
    foreach item $choices {
      radiobutton $win.refsrc.frm.left.radio$b -text $item \
	-width 25 -anchor w -variable wlCalibrate(RefMode) \
	-value $item -highlightthickness 0 -command { RefCalSelect }
      pack  $win.refsrc.frm.left.radio$b -side top -expand true -fill x
      incr b
    }
    
    checkbutton $win.refsrc.frm.right.pupila -text "Pupil Subapertures" \
      -variable wlCalibrate(PupilSubFlg) -highlightthickness 0 \
      -anchor w -offvalue "No" -onvalue "Yes" \
      -command { CalTogDepend PupilSubFlg }
    pack $win.refsrc.frm.right.pupila -side top -expand true -fill x
    
    checkbutton $win.refsrc.frm.right.refrect -highlightthickness 0 \
      -anchor w -variable wlCalibrate(RefRectFlg) \
      -text "Reference Subapertures" -offvalue "No" -onvalue "Yes" \
      -command { CalTogDepend RefRectFlg }
    pack $win.refsrc.frm.right.refrect -side top -expand true -fill x
    
    checkbutton $win.refsrc.frm.right.refpos \
      -text "Reference Positions" -variable wlCalibrate(RefSpotsFlg) \
      -highlightthickness 0 -anchor w -offvalue "No" -onvalue "Yes" \
      -command { CalTogDepend RefSpotsFlg }
    pack $win.refsrc.frm.right.refpos -side top -expand true -fill x
    
    checkbutton $win.refsrc.frm.right.ave \
      -text "Average Reference Positions" \
      -variable wlCalibrate(CalcAveFlg) -highlightthickness 0 \
      -anchor w -offvalue "No" -onvalue "Yes"
    pack $win.refsrc.frm.right.ave -side top -expand true -fill x
    
    RefCalSelect
  } else {
    set wlCalibrate(RefMode) "Take New Data"
  }
  

  if { $calMode == "custom" } {
    # A box for selection of Test Source calibration parameters
    #	
    frame $win.testsrc -relief ridge -borderwidth 3
    pack  $win.testsrc -side top -padx 2m -pady 2m -fill both

    label $win.testsrc.label -text "Test Source Calibration"
    pack  $win.testsrc.label -side top -padx 2m -pady 2m -fill x

    frame $win.testsrc.frm
    pack  $win.testsrc.frm -fill x

    frame $win.testsrc.frm.left
    pack  $win.testsrc.frm.left -anchor w -side left -fill x -expand true
    frame $win.testsrc.frm.right
    pack  $win.testsrc.frm.right -anchor e -side right -fill x -expand true

    checkbutton $win.testsrc.frm.left.pupdat -text "New Test Pupil Data" \
      -variable wlCalibrate(PupilDataFlg) -highlightthickness 0 \
      -anchor w -offvalue "No" -onvalue "Yes" \
      -command { CalTogDepend PupilDataFlg }
    pack $win.testsrc.frm.left.pupdat -side top -expand true -fill x

    checkbutton $win.testsrc.frm.left.puploc -text "Test Pupil Location" \
      -variable wlCalibrate(PupilLocFlg) -highlightthickness 0 -anchor w \
      -offvalue "No" -onvalue "Yes" -command { CalTogDepend PupilLocFlg }
    pack $win.testsrc.frm.left.puploc -side top -expand true -fill x

    checkbutton $win.testsrc.frm.right.testrect \
      -text "New Test Subapertures" \
      -variable wlCalibrate(TestSubapFlg) -highlightthickness 0 \
      -anchor w -offvalue "No" -onvalue "Yes" \
      -command { CalTogDepend TestSubapFlg }
    pack $win.testsrc.frm.right.testrect -side top -expand true -fill x

    checkbutton $win.testsrc.frm.right.puplim -text "Subaps in Pupil Only" \
      -variable wlCalibrate(circFlg) -highlightthickness 0 -anchor w \
      -offvalue "No" -onvalue "Yes"
    pack $win.testsrc.frm.right.puplim -side top -expand true -fill x

    checkbutton $win.testsrc.frm.right.editrect -text "Edit Subapertures" \
      -variable wlCalibrate(EditSubFlg) -highlightthickness 0 -anchor w \
      -offvalue "No" -onvalue "Yes"
    pack $win.testsrc.frm.right.editrect -side top -expand true -fill x
  }

  # A box for selection of miscellaneous parameters
  #
  frame $win.misc -relief ridge -borderwidth 3
  pack  $win.misc -side top -padx 2m -pady 2m -fill both

  checkbutton $win.misc.autocal -variable wlCalibrate(IntFlg) -anchor w \
    -text "Automate Intensities for both Reference and Test Sources" \
    -offvalue "No" -onvalue "Yes" -highlightthickness 0
  pack $win.misc.autocal -side top -expand true -fill x
  
  if { $calMode == "full" } {
    checkbutton $win.misc.editrect -offvalue "No" -onvalue "Yes" \
      -text "Edit Test Subapertures after automatic detection" \
      -anchor w -variable wlCalibrate(EditSubFlg) \
      -highlightthickness 0
    pack $win.misc.editrect -side top -expand true -fill x
  }

}


#--------------------------------------------------------------------------
# proc CalLoadData
#
# Loads calibration data from files when not being grabbed.
#--------------------------------------------------------------------------

proc CalLoadData { files } {
    
  global wlCalibrate wlPanel


  set pupilImgFlg "Yes"

  foreach obj $files {
    set flag "None"
    if { [ file exist $wlCalibrate(loadDir)/$obj ] } {
      if { [wl_Load $wlCalibrate(loadDir)/$obj wlCalibrate($obj)] != "Failed" } {
	set flag "OK" 
      } else {
	set msg "Calibration file $obj could not be loaded.  Please\
                 locate and select the file.  Click Cancel to end calibration."
      }
    } else {
      set msg "Calibration file $obj was not found on disk.  Please\
               locate and select the file.  Click Cancel to end calibration."
    }

    while { $flag != "OK" } {
      set infile [PanelsGetFile $wlCalibrate(loadDir) $msg]

      if { ($infile == "") || ($wlPanel(action) == "Abort") ||
          ($wlPanel(action) == "Cancel") } { 

	if { [winfo exists .waitwin] } { destroy .waitwin }
	  return "Abort" 
      }

      if { [wl_Load $infile wlCalibrate($obj)] != "Failed" } {
	set flag "OK"
      }

      if { [a.rank wlCalibrate($obj)] != 2 } {
	if { [winfo exists .waitwin] } { destroy .waitwin }
	wl_PanelsMsg "The selected file contains a multiframe image! \
                      Please average the file before using it for calibration.\
                      Calibration cancelled."
	return "Abort"
      }
      
      wl_CalSaveFile $obj
    }
  }
  
  return "OK"
}


#--------------------------------------------------------------------------
# proc CalRefCollect 
#
# Collects Reference Source calibration data based on the user's selections.
#--------------------------------------------------------------------------

proc CalRefCollect { } {
    
  global wlCalibrate aos_stageinit aos_camerainit 
  global stagePos platform wsParam
    

  set dir $wlCalibrate(loadDir)
    
  if {($aos_stageinit == 0) || ($aos_camerainit == 0) }  {
    set msg "Hardware has not been initialized.\n
New Reference Source data cannot be grabbed.\n
Continue with saved data?"
    if { [wl_PanelsContinueAbort $msg +200+85 12c] == "Continue" } {
      return [CalLoadRefData]
    } else {
      return "Abort"
    }
  }

    
  # Set the stage positions relative to image to collect
  #
  set closer_pupil_pos  $stagePos(CloserPupilImage)
  set farther_pupil_pos $stagePos(FartherPupilImage)
  set closer_ref_spots  $stagePos(CloserRefSpots)
  set best_ref_spots    $stagePos(BestRefSpots)


  # Prompt the user to put in reference source
  #
  if { [wl_PanelsContinueAbort \
      "Please place the Reference Source in the system."] == "Abort" } {
    return "Abort"
  }

  if { $wlCalibrate(PupilSubFlg) == "Yes" } {
    # If collecting images for pupil calibration
    #
    ws_DataRep "Moving stage..."
    update
    stage.calibrate.absolute $closer_pupil_pos

    # Call exposure routine if exposure not yet determined
    #
    ws_DataRep "Checking/setting exposure..."
    update
    if { $wlCalibrate(IntFlg) == "Yes" } { 
      if { [SetProperExposure refNonPupilExposure] == "Abort" } {
	return "Abort"
      }
    } else {
      set msg "Please adjust the light intensity and exposure."
      if { [CalAdjustExposure $msg refNonPupilExposure \
	  "Reference Pupil" ] == "Abort" } {
	return "Abort"
      }
    }

    ws_DataRep "Grabbing the closer reference pupil image...."
    update
    while { [ stage.get.moving ] == 1 } {
      update 
    }

    if { $platform == "windows" } {
      after 200
    } 

    if [ catch { fg.grab 1 = ttt } result ] {
      if [ catch { fg.grabc 1 = ttt } result ] {
	wl_PanelsWarn "Is a Camera Image Display open?  Close it, then click OK."
      }
    }
    if [ catch { fg.grab 1 = ttt } result ] {
      if [ catch { fg.grabc 1 = ttt } result ] {
	wl_PanelsWarn "Couldn't grab frames.  Calibration cannot continue."
	return "Abort"
      }
    }

    a.copy ttt = wlCalibrate(CloserPupilImage)
    a.save ttt ${dir}/CloserPupilImage.tmp

    ws_DataRep "Moving stage..."
    update
    stage.calibrate.absolute $farther_pupil_pos

    while { [ stage.get.moving ] == 1 } {
      update
    } 
    ws_DataRep "Grabbing the farther reference pupil image...."
    update

    if { $platform == "windows" } {
      after 200
    }

    if [ catch { fg.grab 1 = ttt } result ] {
      if [ catch { fg.grabc 1 = ttt } result ] {
	wl_PanelsWarn "Is a Camera Image Display open?  Close it, then click OK."
      }
    }
    if [ catch { fg.grab 1 = ttt } result ] {
      if [ catch { fg.grabc 1 = ttt } result ] {
	wl_PanelsWarn "Couldn't grab frames.  Calibration cannot continue."
	return "Abort"
      }
    }

    a.copy ttt = wlCalibrate(FartherPupilImage)
    a.save ttt ${dir}/FartherPupilImage.tmp
  }

  # Closer reference
  #
  if { $wlCalibrate(RefRectFlg) == "Yes" } {
	
    ws_DataRep "Moving stage..."
    update
    stage.calibrate.absolute $closer_ref_spots

    # Call exposure routine 
    #
    ws_DataRep "Checking/setting exposure..."
    update
    if { $wlCalibrate(IntFlg) == "Yes" } { 
      if { [SetProperExposure refSpotExposure] == "Abort" } {
	return "Abort"
      }
    } else {	
      set msg "Please adjust the light intensity and exposure."
      if { [CalAdjustExposure $msg refSpotExposure \
	  "Reference Spots"] == "Abort" } {
	return "Abort"
      }
    }

    ws_DataRep "Grabbing the closer reference spot image...."
    update
    while { [ stage.get.moving ] == 1 } {
      update
    } 

    if { $platform == "windows" } {
      after 200
    } 

    if [ catch { fg.grab 1 = ttt } result ] {
      if [ catch { fg.grabc 1 = ttt } result ] {
	wl_PanelsWarn "Is a Camera Image Display open?  Close it, then click OK."
      }
    }
    if [ catch { fg.grab 1 = ttt } result ] {
      if [ catch { fg.grabc 1 = ttt } result ] {
	wl_PanelsWarn "Couldn't grab frames.  Calibration cannot continue."
	return "Abort"
      }
    }

    a.copy ttt = wlCalibrate(CloserRefSpots)
    a.save ttt ${dir}/CloserRefSpots.tmp
  }

  # Best reference
  #
  if { $wlCalibrate(RefRectFlg) == "Yes" || \
      $wlCalibrate(RefSpotsFlg) == "Yes" } {

    ws_DataRep "Moving stage..."
    update
    stage.calibrate.absolute $best_ref_spots
    while { [ stage.get.moving ] == 1 } {
      update
    } 

    # Call exposure routine 
    #
    ws_DataRep "Checking/setting exposure..."
    update
    if { $wlCalibrate(IntFlg) == "Yes" } { 
      if { [SetProperExposure refSpotExposure] == "Abort" } {
	return "Abort"
      }
    } else {
      set msg "Please adjust the light intensity and exposure."
      if { [CalAdjustExposure $msg refSpotExposure \
	  "Reference Spots" ] == "Abort" } {
	if { [winfo exists .waitwin] } { destroy .waitwin }
	return "Abort"
      }
    }

    ws_DataRep "Grabbing best reference spot image..."
    update

    if { $wlCalibrate(CalcAveFlg) == "Yes" } { 
      set numGrab $wsParam(maxFrames)
    } else {
      set numGrab 1
    }
    if { $platform == "windows" } {
      after 200
    } 

    if [ catch { fg.grab $numGrab = ttt } result ] {
      if [ catch { fg.grabc $numGrab = ttt } result ] {
	wl_PanelsWarn "Is a Camera Image Display open?  Close it, then click OK."
      }
    }
    if [ catch { fg.grab $numGrab = ttt } result ] {
      if [ catch { fg.grabc $numGrab = ttt } result ] {
	wl_PanelsWarn "Couldn't grab frames.  Calibration cannot continue."
	return "Abort"
      }
    }

    a.copy ttt = wlCalibrate(BestRefSpots)
    a.save ttt ${dir}/BestRefSpots.tmp
    
    if { [winfo exists .waitwin] } { destroy .waitwin }
  }
}


#--------------------------------------------------------------------------
# proc CalTestCollect 
#
# Collects Test Source calibration data based on the user's selections.
#--------------------------------------------------------------------------

proc CalTestCollect { } {
    
  global wlCalibrate aos_stageinit aos_camerainit stagePos platform 
    

  set dir $wlCalibrate(loadDir)
    
  if {($aos_stageinit == 0) || ($aos_camerainit == 0) }  {
    set msg "Hardware has not been initialized.\n
New Test Source data cannot be grabbed.\n
Continue with saved data?"
    if { [wl_PanelsContinueAbort $msg +200+85 12c] == "Continue" } {
      return [CalLoadTestData]
    } else {
      return "Abort"
    }
  }


  # Set the stage positions relative to image to collect
  #
  set pupil_pos        $stagePos(PupilImage)
  set closer_ref_spots $stagePos(CloserRefSpots)
  set best_ref_spots   $stagePos(BestRefSpots)


  # Prompt the user to put in test source
  #
  if { [wl_PanelsContinueAbort \
      "Please place the Test Source in the system."] == "Abort" } {
    return "Abort"
  }


  if { $wlCalibrate(PupilDataFlg) == "Yes"} {

    ws_DataRep "Moving stage..."
    update
    stage.calibrate.absolute $pupil_pos

    # Call exposure routine if exposure not yet determined
    #
    ws_DataRep "Checking/setting exposure..."
    update
    if { $wlCalibrate(IntFlg) == "Yes" } { 
      if { [SetProperExposure testPupilExposure] == "Abort" } {
	return "Abort"
      }
    } else {
      set msg "Please adjust the light intensity and exposure."
      if { [CalAdjustExposure $msg testPupilExposure \
	  "Test Pupil"] == "Abort" } {
	return "Abort"
      }
    }

    ws_DataRep "Grabbing test pupil image..."
    update
    while { [ stage.get.moving ] == 1 } { 
      update
    } 

    if { $platform == "windows" } {
      after 200
    } 

    if [ catch { fg.grab 1 = ttt } result ] {
      if [ catch { fg.grabc 1 = ttt } result ] {
	wl_PanelsWarn "Is a Camera Image Display open?  Close it, then click OK."
      }
    }
    if [ catch { fg.grab 1 = ttt } result ] {
      if [ catch { fg.grabc 1 = ttt } result ] {
	wl_PanelsWarn "Couldn't grab frames.  Calibration cannot continue."
	return "Abort"
      }
    }
    a.copy ttt = wlCalibrate(PupilImage)
    a.save ttt ${dir}/PupilImage.tmp
  } else {
    CalLoadData { PupilImage }
  }

  if { $wlCalibrate(TestSubapFlg) == "Yes" } {
	
    ws_DataRep "Moving stage..."
    update
    stage.calibrate.absolute $closer_ref_spots

    # Call exposure routine 
    #
    ws_DataRep "Checking/setting exposure..."
    update
    if { $wlCalibrate(IntFlg) == "Yes" } { 
      if { [SetProperExposure testSpotExposure] == "Abort" } {
	return "Abort"
      }
    } else {
      set msg "Please adjust the light intensity and exposure."
      if { [CalAdjustExposure $msg testSpotExposure "Test Spots"] == "Abort" } {
	return "Abort"
      }
    }

    ws_DataRep "Grabbing closer test spot image..."
    update
    while { [ stage.get.moving ] == 1 } { 
      update
    } 
    
    if { $platform == "windows" } {
      after 200
    } 

    if [ catch { fg.grab 1 = ttt } result ] {
      if [ catch { fg.grabc 1 = ttt } result ] {
	wl_PanelsWarn "Is a Camera Image Display open?  Close it, then click OK."
      }
    }
    if [ catch { fg.grab 1 = ttt } result ] {
      if [ catch { fg.grabc 1 = ttt } result ] {
	wl_PanelsWarn "Couldn't grab frames.  Calibration cannot continue."
	return "Abort"
      }
    }
    a.copy ttt = wlCalibrate(CloserTestSpots)
    a.save ttt ${dir}/CloserTestSpots.tmp

    
    ws_DataRep "Moving stage..."
    update
    stage.calibrate.absolute $best_ref_spots
    while { [ stage.get.moving ] == 1 } {
      update
    } 

    # Call exposure routine 
    #
    ws_DataRep "Checking/setting exposure..."
    update
    if { $wlCalibrate(IntFlg) == "Yes" } { 
      if { [SetProperExposure testSpotExposure] == "Abort" } {
	return "Abort"
      }
    } else {
      set msg "Please adjust the light intensity and exposure."
      if { [CalAdjustExposure $msg testSpotExposure \
	  "Test Spots"] == "Abort" } {
	return "Abort"
      }
    }

    ws_DataRep "Grabbing the best test spot image..."
    update
    
    if { $platform == "windows" } {
      after 200
    } 

    if [ catch { fg.grab 1 = ttt } result ] {
      if [ catch { fg.grabc 1 = ttt } result ] {
	wl_PanelsWarn "Is a Camera Image Display open?  Close it, then click OK."
      }
    }
    if [ catch { fg.grab 1 = ttt } result ] {
      if [ catch { fg.grabc 1 = ttt } result ] {
	wl_PanelsWarn "Couldn't grab frames.  Calibration cannot continue."
	return "Abort"
      }
    }
    a.copy ttt = wlCalibrate(BestTestSpots)
    a.save ttt ${dir}/BestTestSpots.tmp
  }   
}


#--------------------------------------------------------------------------
# proc CalParamsInit
#
# Initialize the calibration data
#--------------------------------------------------------------------------

proc CalParamsInit { } {

  global wlCalibrate wsParam wlData


  # Default psfScale set by Liz for get_mtf_pd in case
  # retrieve data called before Calibration run performed.
  # Is recalculated in Calibration procedure though
  #
  set wlCalibrate(psfScale) [expr \
        ( $wsParam(Lambda) / $wlCalibrate(wsAperture) )* 250000.0 ]

  set wlCalibrate(doneInit)	"No"
    
}


#--------------------------------------------------------------------------
# proc CalLoadRunData
#
# Loads calibration data necessary for running a test into wlCalibrate.
#--------------------------------------------------------------------------

proc CalLoadRunData { dir } {
    
  global wlCalibrate 
  
  
  foreach obj {FinalCenters FinalRefRects FinalTestRects Params Pupil RefPos } {
    set flag "None"
    if { [ file exist $dir/$obj ] } {
	    
      if { [wl_Load $dir/$obj wlCalibrate($obj)] == "Failed" } {
	set flag "Fail"
	return "Abort"
      }
      set flag "OK" 
    } else {
      set msg "Could not load file $obj, which is created during calibration. \
               Be sure Calibration has been done."
      set flag "Fail"
      break
    }
  }

  if { $flag == "Fail" } { 
    wl_PanelsMsg $msg 
    return "Abort"
  }
}


#################################################################
## The following procedures are used for the Pupil calibration ##
#################################################################

#--------------------------------------------------------------------------
# proc calGetPupil
#
# Displays a window in which the user can specify the pupil center
# coordinates and radius via mouse actions.
#--------------------------------------------------------------------------

proc calGetPupil { msg } {

  global wlPanel wlCalibrate wsMLMParams

    
  if {[ winfo exist .bwin ]} {destroy .bwin}

  toplevel .bwin 
  wm geometry .bwin +235+250
  wm title .bwin "Pupil Geometry"
    
  frame .bwin.top
  pack  .bwin.top -side top -fill x
    
  message .bwin.top.m1 -text $msg -width 9c 
  pack    .bwin.top.m1 -side top
    
  set pxx [a.ext $wlCalibrate(Params) 0 1]
  set pyy [a.ext $wlCalibrate(Params) 3 1]
   
  set avgParam [expr $pxx + $pyy ]
  set avgParam [expr $avgParam / 2.0]

  set muperpix [expr $wsMLMParams(spacing) * $avgParam]
  set pixpermm [expr 1000.0 /$muperpix]
  set pixmm [format %3.4f $pixpermm] 
  message .bwin.top.m2 -width 9c -text "Pupil image scale is $pixmm pixels per mm"
  pack .bwin.top.m2 -side top

  frame .bwin.bottom
  pack  .bwin.bottom -side top -fill y -padx 4 -pady 4

  button .bwin.bottom.b1 -text "  OK  " \
	-command {CalSetPupil; set wlPanel(action) "Done"}
  button .bwin.bottom.b2 -text "Cancel" -command {set wlPanel(action) "Abort"}
  pack   .bwin.bottom.b1 .bwin.bottom.b2 -side left -padx 10 -pady 5
    
  grab set .bwin

  while { 1 } {
    tkwait variable wlPanel(action)

    if { ($wlPanel(action) == "Done") || ($wlPanel(action) == "Abort") } {
      if { [winfo exist .bwin] } { destroy .bwin }
      return $wlPanel(action)
    }    
  }
}


##------------------------------------------------------------------
## proc CalSetPupil
##
## Update PupilImage parameters 
##------------------------------------------------------------------

proc CalSetPupil {} \
{
    global  wlCalibrate  

    if { $wlCalibrate(PupilShape) == "Circular" } { 
	circleGet wlCalibrate(Pupil)
    } else {
	rectGet wlCalibrate(Pupil)
    }
}



##------------------------------------------------------------------
## proc wl_calRefreshPupil
##
## Refresh the Pupil image 
##------------------------------------------------------------------

proc wl_calRefreshPupil {} {

    global wlCalibrate
    
    if { $wlCalibrate(PupilShape) == "Circular" } { 
	circleInit $wlCalibrate(PupilImage) $wlCalibrate(Pupil) "Pupil Image"
    } else { 
	rectInit $wlCalibrate(PupilImage) $wlCalibrate(Pupil) "Pupil Image"
    }
}



#--------------------------------------------------------------------------
# proc CalPupilGeometry 
#
# Calculates pupil position and radius from the pupil image
# 
# Allows the user to enter the pupil position and radius.
# Produces the global variable wlCalibrate(Pupil), a v3
# array containing the x and y position of the pupil center
# and the pupil radius in pixels, 
#
# It also writes the following files in the Calibration directory
#	Pupil
#--------------------------------------------------------------------------

proc CalPupilGeometry {} {

  global wlCalibrate 
    

  # If necessary, load Pupil image and update global variables
  #
  update
  if { $wlCalibrate(PupilLocFlg) == "No" } {

    CalLoadFile Pupil

    if { $wlCalibrate(PupilShape) == "Circular" } { 
      set wlCalibrate(xcent) [a.extele wlCalibrate(Pupil) 0]
      set wlCalibrate(ycent) [a.extele wlCalibrate(Pupil) 1]
      set wlCalibrate(rad) [a.extele wlCalibrate(Pupil) 2]
    } else { 
      a.split wlCalibrate(Pupil) = col row width height
      set wlCalibrate(col) [a.dump col]
      set wlCalibrate(row) [a.dump row]
      set wlCalibrate(width) [a.dump width]
      set wlCalibrate(height) [a.dump height]
    }
  } else {

    wl_PanelsWait .wlwait "Calculating Pupil Position and Radius..."
    update
    a.copy wlCalibrate(PupilImage) = pupl


    # Try to find the pupil
    #
    wl_findPupil $pupl 

    if {[winfo exist .wlwait]} { destroy .wlwait }
    update


    # Show the result and allow the user to modify
    #
    if { $wlCalibrate(PupilShape) == "Circular" } { 
      circleInit $wlCalibrate(PupilImage) $wlCalibrate(Pupil) "Pupil Image"
      set msg "Use the mouse to change the location or size of the pupil."
    } else { 
      rectInit $wlCalibrate(PupilImage) $wlCalibrate(Pupil) "Pupil Image"
      set msg "Use the mouse to change the location or size of the pupil.  \
	  Click on the right or top edge of the rectangle to reshape."
    }
    
    CalSetPupil
    update
	
    if { [ calGetPupil $msg ] == "Abort" } { 
      if { $wlCalibrate(PupilShape) == "Circular" } { 
	circleTerm
      } else { 
	rectTerm
      }
      return "Abort"
    }

    # Save the result
    #
    a.save wlCalibrate(Pupil) $wlCalibrate(saveDir)/Pupil.tmp

    # Update global variables
    #    
    if { $wlCalibrate(PupilShape) == "Circular" } { 
      set wlCalibrate(xcent) [a.extele wlCalibrate(Pupil) 0]
      set wlCalibrate(ycent) [a.extele wlCalibrate(Pupil) 1]
      set wlCalibrate(rad) [a.extele wlCalibrate(Pupil) 2]
      circleTerm
    } else { 
      a.split wlCalibrate(Pupil) = col row width height
      set wlCalibrate(col) [a.dump col]
      set wlCalibrate(row) [a.dump row]
      set wlCalibrate(width) [a.dump width]
      set wlCalibrate(height) [a.dump height]
      rectTerm
    }
  }
  
  # If so requested, recalculate the pupil subap grid only inside
  # the Test pupil
  #
  if { $wlCalibrate(circFlg) == "Yes" } {
    if { $wlCalibrate(PupilShape) == "Circular" } { 
      alg.make.grid.circ wlCalibrate(Params) wlCalibrate(Pupil) \
	  $wlCalibrate(CCDxpix) $wlCalibrate(CCDypix) = wlCalibrate(Centers)
    } else { 
      alg.make.grid.rect wlCalibrate(Params) wlCalibrate(Pupil) \
	  $wlCalibrate(CCDxpix) $wlCalibrate(CCDypix) = wlCalibrate(Centers)
    }
    a.save wlCalibrate(Centers) $wlCalibrate(saveDir)/Centers.tmp
  }
}


#######################################################################
#
# This is the algorithm to automatically fit an outline to the
# pupil image. Eventually, this should be extended to cover
# obscured, elliptical and rectangular pupils
#
#######################################################################

proc wl_findPupil { pupil } {

    global wlCalibrate 

    a.copy $pupil = lpup
    
#
# mods to make fitting more reliable:
# 1 - rebinning by 4X4
# 2 - median filter
# AW  5/26/97
#
# Since the pupil image is reduced by a factor of four by rebinning
# it is necessary to multiply results by a factor of four
# to make scale correct

    a.rebin lpup 4 4 = lpup
    a.med lpup = lpup
    if { $wlCalibrate(PupilShape) == "Circular" } { 
	alg.fit.circle lpup 1 = outline
	a.mul outline 4.0 = wlCalibrate(Pupil)
    } else {
	alg.fit.rect lpup = outline
	a.split outline = a b c d
	a.mul a 4.0 = ao
	a.mul b 4.0 = bo
	a.mul c 4.0 = co
	a.mul d 4.0 = do
	a.merge ao bo co do = outline
	a.copy outline = wlCalibrate(Pupil)
    } 
    return
}


#################################################################  
## The following procedures are used to calibrate the Lenslet 
## parameters
#################################################################



#--------------------------------------------------------------------------
# proc CalLensletPos
#
# Calculates lenslet positions from the 
# bright and dark pupil grids. It produces the global variables
#
#	wlCalibrate(Params)	pupil subaperture parameters - these are
#               six parameters that define a regular grid that fits the image
#	wlCalibrate(Centers)	pupil subaperture centers (unmatched)
#
# It also writes the following files in the Calibration directory
#
#	Params
#	Centers
#--------------------------------------------------------------------------

proc CalLensletPos {} {

  global wlCalibrate wlPanel wsCalHelpText


  if { ![catch { a.type wlCalibrate(Params)} ] } {
    a.set wlCalibrate(Params) 0 = wlCalibrate(Params) 
  }

  if { $wlCalibrate(PupilSubFlg) == "No" } {
    CalLoadFile Params 
    CalLoadFile Centers
    return "OK" 
  }

  # Get the bright and dark grids from disk
  #
  if { [file exists $wlCalibrate(loadDir)/CloserPupilImage.tmp ] } {
    a.load $wlCalibrate(loadDir)/CloserPupilImage.tmp = bright
  } else {
    a.load $wlCalibrate(loadDir)/CloserPupilImage = bright
  }
  if { [file exists $wlCalibrate(loadDir)/FartherPupilImage.tmp ] } {
    a.load $wlCalibrate(loadDir)/FartherPupilImage.tmp = dark
  } else {
    a.load $wlCalibrate(loadDir)/FartherPupilImage = dark
  }
  a.to bright f = bright

  # Subtract them to remove background noise
  #
  a.sub bright dark = wlCalibrate(PupilSpots)	

  # Set guess at spacing to the value determined by MLM selected
  #
  set spacing $wlCalibrate(subapSpacing)

  wl_PanelsWait .waitwin "Calculating Pupil Parameters..."
  update

  # Do the subaperture grid finding algorithm
  #	
  alg.find.params wlCalibrate(PupilSpots) $wlCalibrate(subapSpacing) = \
      wlCalibrate(Params)
  update
	    
  # Make the array of subaperture centers
  #
  set cols [a.cols wlCalibrate(PupilSpots)]
  set rows [a.rows wlCalibrate(PupilSpots)]
  alg.make.grid wlCalibrate(Params) $cols $rows = wlCalibrate(Centers)    	

  # Test centers against known MLM size. We know MLM is roughly aligned
  # with x-y coordinates. This allows for 10% error in spacing
  #
  set tol [expr 0.2 * sqrt( [expr $wlCalibrate(MLM_xxpar) * \
      $wlCalibrate(MLM_xxpar) + $wlCalibrate(MLM_yypar) * \
      $wlCalibrate(MLM_xxpar)] ) ]
  update	
  set xx [expr abs( [a.extele wlCalibrate(Params) 0] - $wlCalibrate(MLM_xxpar))]
  set xy [expr abs( [a.extele wlCalibrate(Params) 1] )]
  set yx [expr abs( [a.extele wlCalibrate(Params) 2] )]
  set yy [expr abs( [a.extele wlCalibrate(Params) 3] - $wlCalibrate(MLM_yypar))]
    
  if { $xy > $tol || $yx > $tol || $xx > $tol || $yy > $tol } {
    update
    id.new wlCalibrate(id)
    id.set.xy $wlCalibrate(id) $wlCalibrate(idxpos) $wlCalibrate(idypos)
    id.set.array wlCalibrate(id) wlCalibrate(PupilSpots)
    id.set.pos.array wlCalibrate(id) wlCalibrate(Centers)
    id.set.title wlCalibrate(id) "Pupil Subaperture Centers"

    if { "Abort" == [ PanelsCalError \
	"The Pupil Subaperture calculations are out of tolerance.  The\
	system is unlikely to run acceptably.  Click OK to proceed anyway, \
	Cancel to end calibration or Help for more information." \
        $wsCalHelpText(PupSub) ] } {   
      unset wlCalibrate(id)
      return "Abort"
    }
    update	    

    id.set.pos.array wlCalibrate(id) wlCalibrate(Centers)
   
    if { [winfo exists .waitwin] } { destroy .waitwin } 
      
    if { "Abort" == [ wlMan_LensletPos ] } {
      unset wlCalibrate(id)
      return "Abort"
    } 
       
    unset wlCalibrate(id)
  }

  a.save wlCalibrate(Params)  $wlCalibrate(saveDir)/Params.tmp
  a.save wlCalibrate(Centers) $wlCalibrate(saveDir)/Centers.tmp
  return "OK"
}



##############################################################
##  Procedures are to calibrate the Reference Rectangles    ##
##############################################################


    
#--------------------------------------------------------------------------
# proc CalRefRects
#
# Calculates the reference rectangles from the reference spots. 
# It generates the following global variables:
#
#	wlCalibrate(RefRects)		reference rectangles
#
# It also writes the following files in the Calibration directory:
#
#	RefRects
#--------------------------------------------------------------------------

proc CalRefRects {} {

  global wlCalibrate wlPanel wsCalHelpText


  if { $wlCalibrate(RefRectFlg) == "No" && \
       $wlCalibrate(PupilLocFlg) == "No" } {
    CalLoadFile RefRects
    return "OK" 
  }

  wl_PanelsWait .waitwin "Calculating Reference Rectangles..."
  update  
    
  # Allow for the case that the ref spots are a multiple frame set
  #
  update 
  if {[a.plns wlCalibrate(BestRefSpots)] > 1} {
    a.extpln wlCalibrate(BestRefSpots) 0 = brs
  } else {
    a.copy wlCalibrate(BestRefSpots) = brs
  }
    
  # Now find the subaperture rectangles
  #
  alg.find.rects brs = wlCalibrate(RefRects)
  update

  # This is a test to see if a sufficient number of subapertures
  # has been found
  #
  ws_CalcNumRects ref

  if { [a.cols wlCalibrate(RefRects)] < $wlCalibrate(Numsubs) } {
    id.new wlCalibrate(id)
    id.set.xy $wlCalibrate(id) $wlCalibrate(idxpos) $wlCalibrate(idypos)
    id.set.array wlCalibrate(id) brs
    id.set.title wlCalibrate(id) "Reference Rectangles"
    id.set.rect.array wlCalibrate(id) wlCalibrate(RefRects)
    update 

    if { "Abort" == [ PanelsCalError \
	"The Reference Subaperture calculations are not ideal.  The system \
	will probably run acceptably, anyway.  Click OK to proceed, \
	Cancel to end calibration or Help for more information" \
        $wsCalHelpText(RefRects) ] } {
       unset wlCalibrate(id)
       return "Abort"
     }

     unset wlCalibrate(id)
     a.save wlCalibrate(RefRects) $wlCalibrate(saveDir)/RefRects.tmp
     return "OK"

   } else {
     a.save wlCalibrate(RefRects) $wlCalibrate(saveDir)/RefRects.tmp
   }
}


############################################################
##  Procedures are to calibrate the Reference Matches     ##
############################################################

#--------------------------------------------------------------------------
# proc CalRefMatches
# 
# Calculates the reference rectangle to pupil subaperture matches. 
# It generates the following global variables:
#
#	wlCalibrate(refMatches)
#		reference rectangle to pupil center matches
#
# It also writes the following files in the Calibration directory:
#	RefMatches
#--------------------------------------------------------------------------

proc CalRefMatches {} {

  global wlCalibrate wlPanel wsCalHelpText stagePos


  if { $wlCalibrate(RefRectFlg) == "No" && \
       $wlCalibrate(PupilLocFlg) == "No"} {
    CalLoadFile RefMatches
    return "OK"
  }

  wl_PanelsWait .waitwin "Calculating Reference Rectangle to Subaperture Center Matches..."
  update

  # Set matchsize to a default
  #
  alg.set.matchsize $wlCalibrate(matchsize)
    

  # If ref spot file is multi-frame,  just use first frame
  #
  if {[a.plns wlCalibrate(BestRefSpots)] > 1} {
    a.extpln wlCalibrate(BestRefSpots) 0 = frs
  } else {
    a.copy wlCalibrate(BestRefSpots) = frs
  }

  # Do arithmetic to get parameters for matching algorithm
  #
  set stagebestspots [expr $wlCalibrate(StageBestSpots)-$stagePos(PupilImage)]
  set stagecloserspots [expr $wlCalibrate(StageCloserSpots)-$stagePos(PupilImage)]

  # Execute the matching algorithm
  #
  if { $wlCalibrate(CloserRefSpots) == "Unset" } { 
      CalLoadFile CloserRefSpots
  }
  alg.match.rects.cents wlCalibrate(RefRects) frs wlCalibrate(CloserRefSpots) \
      wlCalibrate(Centers) $stagebestspots $stagecloserspots = \
      wlCalibrate(RefMatches)

  # Test for various errors
  #
  set nmatches [a.cols wlCalibrate(RefMatches)]
  if { $nmatches == 0 } { 
    wl_PanelsMsg "No Reference Subapertures to Pupil Subapertures matches found!"
    return "OK"
  }

  if { $wlCalibrate(circFlg) == "No" } {
    set nrects [expr 0.9 * [a.cols wlCalibrate(RefRects)]]
  } else {
    set nrects [expr 0.9 * [a.cols wlCalibrate(Centers)]]
  }

  if { $nmatches < $nrects } {
    id.new wlCalibrate(id)
    id.set.xy $wlCalibrate(id) $wlCalibrate(idxpos) $wlCalibrate(idypos)
    id.set.array wlCalibrate(id) frs 
    id.set.title wlCalibrate(id) "Matched Reference Rectangles"
    a.v6tov2v4 wlCalibrate(RefMatches) = fpos rects
    id.set.rect.array wlCalibrate(id) rects
    update

    scan $nrects %d nrects_int
    if { "Abort" == [ PanelsCalError \
	"The calculation of Reference subaperture to Pupil subaperture \
	matches is not ideal.   The system expected $nrects_int subaperture \
	matches, but got $nmatches.  Click OK to proceed anyway, Cancel \
	to end calibration or Help for more information" \
        $wsCalHelpText(RefMatches) ] } {
      unset wlCalibrate(id)
      return "Abort"
    }

    if {[winfo exist .waitwin]} {
      if { [winfo exists .waitwin] } { destroy .waitwin }
    }

    a.save wlCalibrate(RefMatches) $wlCalibrate(saveDir)/RefMatches.tmp

    return "OK"

  } else {
    a.save wlCalibrate(RefMatches) $wlCalibrate(saveDir)/RefMatches.tmp
  }
}


#--------------------------------------------------------------------------
# proc CalRefPos
# 
# Calculates the reference spot positions.  It sets the global variable
# wlCalibrate(RefPos), and writes or loads the file 'RefPos' in the
# Calibration directory.
#--------------------------------------------------------------------------

proc CalRefPos {} {

  global wlCalibrate


  if { $wlCalibrate(RefSpotsFlg) == "No" && \
       $wlCalibrate(TestSubapFlg) == "No" && \
       $wlCalibrate(PupilLocFlg) == "No" && \
       $wlCalibrate(EditSubFlg) == "No" } {
    CalLoadFile RefPos
    return "OK"
  }

  wl_PanelsWait .bwin "Calculating Reference Spot Positions..."
  update

  if { [file exists $wlCalibrate(loadDir)/FinalRefRects.tmp ] } {
    wl_Load $wlCalibrate(loadDir)/FinalRefRects.tmp wlCalibrate(FinalRefRects)
  } elseif { [ wl_Load $wlCalibrate(loadDir)/FinalRefRects \
            wlCalibrate(FinalRefRects) ] == "Failed" } {
    return "Abort"
  }


  # If the ref spots are multi-frame, average the ref spot positions
  #
  set nplns [a.plns wlCalibrate(BestRefSpots)]

  if { $nplns > 1} {
    a.extpln wlCalibrate(BestRefSpots) 0 = frs
    alg.fit.spots frs wlCalibrate(FinalRefRects) = sumRefPos

    for {set j 1} {$j < $nplns} {incr j} {
      a.extpln wlCalibrate(BestRefSpots) $j = ttt
      alg.fit.spots ttt wlCalibrate(FinalRefRects) = parRefPos
      a.add parRefPos sumRefPos = sumRefPos
    }

    a.v2toxy sumRefPos = x y
    a.div x $nplns = x
    a.div y $nplns = y
    a.xytov2 x y = wlCalibrate(RefPos)
  } else {
    a.copy wlCalibrate(BestRefSpots) = brs
    alg.fit.spots brs wlCalibrate(FinalRefRects) = wlCalibrate(RefPos)   
  }
    
  if {[winfo exist .bwin]} { destroy .bwin }
    
  a.save wlCalibrate(RefPos) $wlCalibrate(saveDir)/RefPos.tmp
}


#--------------------------------------------------------------------------
# proc CalTestRect
#
# Calculates the test rectangles.  It generates the global variable
# wlCalibrate(TestRects), the array of test rectangles.
#
# It also writes the file TestRects into the Calibration directory.
#--------------------------------------------------------------------------

proc CalTestRect {} {

  global wlCalibrate wlPanel wsCalHelpText platform stagePos


  if { [file exists $wlCalibrate(loadDir)/BestTestSpots.tmp ] } {
    wl_Load $wlCalibrate(loadDir)/BestTestSpots.tmp spots
  } elseif { [wl_Load $wlCalibrate(loadDir)/BestTestSpots spots] == "Failed" } {
    return "Abort"
  }

  if { $wlCalibrate(TestSubapFlg) == "No" && $wlCalibrate(PupilLocFlg) == "No" } {
    if { [CalLoadFile TestRects] == "Abort" } {
      return "Abort"
    }
  } else {
    wl_PanelsWait .waitwin "Calculating Test Rectangles..."
    update 

    alg.find.rects spots = wlCalibrate(TestRects)  

    # Test to see if there may be a problem with rectangle finding
    #
    ws_CalcNumRects test

    if { [a.cols wlCalibrate(TestRects)] < $wlCalibrate(Numsubs) } {
      id.new wlCalibrate(id)
      id.set.xy $wlCalibrate(id) $wlCalibrate(idxpos) $wlCalibrate(idypos)
      id.set.array wlCalibrate(id) spots
      id.set.title wlCalibrate(id) "Test Rectangles"
      id.set.rect.array wlCalibrate(id) wlCalibrate(TestRects)
      update            

      if { "Abort" == [ PanelsCalError \
	  "The Test Subaperture calculations are not ideal.  The system \
	  will probably run acceptably, anyway.  Click OK to proceed, \
	  Cancel to end calibration or Help for more information" \
          $wsCalHelpText(TestRects) ] } {
	unset wlCalibrate(id)
	return "Abort"
      }
      
      if {[winfo exist .waitwin]} { destroy .waitwin }
      
      a.save wlCalibrate(TestRects) $wlCalibrate(saveDir)/TestRects.tmp
    }
  }

  # Give the user the ability to edit rectangles, if they selected
  # that option.
  #
  if { $wlCalibrate(EditSubFlg) == "Yes" } {

    # If the user selected "Subaps in Pupil Only", then do some
    # calculations to give them just those subabs to edit.
    #
    if { $wlCalibrate(circFlg) == "Yes" } {
      if { [file exists $wlCalibrate(loadDir)/CloserTestSpots.tmp ] } {
	wl_Load $wlCalibrate(loadDir)/CloserTestSpots.tmp closerSpots
      } elseif { [wl_Load $wlCalibrate(loadDir)/CloserTestSpots closerSpots] \
	  == "Failed" } {
	return "Abort"
      }
      update
      set stagebestspots [expr $wlCalibrate(StageBestSpots) - \
	  $stagePos(PupilImage)]
      set stagecloserspots [expr $wlCalibrate(StageCloserSpots) - \
	  $stagePos(PupilImage)]

      alg.match.rects.cents wlCalibrate(TestRects) spots closerSpots \
	  wlCalibrate(Centers) $stagebestspots $stagecloserspots = \
	  wlCalibrate(TestMatches)
	 
      a.v6tov2v4 wlCalibrate(TestMatches) = \
	  wlCalibrate(Centers) wlCalibrate(TestRects)
    }

    # Here's where we actually put up the edit window.
    #
    if { $platform == "windows" } { 
      editInit $spots $wlCalibrate(TestRects) "Test Rectangles"
      if {[winfo exist .waitwin]} { destroy .waitwin }
      if {[ wl_PanelsContinueAbort "Edit the Test Rectangles. Click OK when done." \
	  ] != "Continue" } {
	editTerm
	return "Abort" 
      }
      editGet wlCalibrate(TestRects)
      editTerm
    } else {
      id.new wlCalibrate(id)	
      id.set.xy $wlCalibrate(id) $wlCalibrate(idxpos) $wlCalibrate(idypos)	
      id.set.array wlCalibrate(id) spots	
      id.set.title wlCalibrate(id) "Test Rectangles"	
      id.set.rect.array wlCalibrate(id) wlCalibrate(TestRects)
      update            

      if {[winfo exist .waitwin]} { destroy .waitwin }
      if {[ wl_PanelsContinueAbort "Edit the Test Rectangles. Click OK when done." \
	  ] != "Continue" } {
	unset wlCalibrate(id)
	return "Abort" 
      }
      id.get.rect.array wlCalibrate(id) wlCalibrate(TestRects)
    }
    a.save wlCalibrate(TestRects) $wlCalibrate(saveDir)/TestRects.tmp
  } else { 
    a.save wlCalibrate(TestRects) $wlCalibrate(saveDir)/TestRects.tmp
  }
}


#--------------------------------------------------------------------------
# proc CalTestMatches
#
# Calculates the test rectangle to pupil subaperture matches.  
# It generates the following global variables:
#
#	wlCalibrate(TestMatches)  
#           test rectangle to pupil center matches
#
# It also writes the file TestMatches into the Calibration directory
#--------------------------------------------------------------------------

proc CalTestMatches {} {

  global wlCalibrate wlPanel wsCalHelpText stagePos


  if { $wlCalibrate(TestSubapFlg) == "No" && \
       $wlCalibrate(circFlg) == "No" && \
       $wlCalibrate(EditSubFlg) == "No" } { 
    CalLoadFile TestMatches
    return "OK" 
  }

  wl_PanelsWait .waitwin "Calculating Test Rectangle to Subaperture Center Matches"
  if { [file exists $wlCalibrate(loadDir)/BestTestSpots.tmp ] } {
    wl_Load $wlCalibrate(loadDir)/BestTestSpots.tmp bestSpots
  } elseif { [ wl_Load $wlCalibrate(loadDir)/BestTestSpots bestSpots ] == \
            "Failed" } {
    return "Abort"
  }
  update 

  if { [file exists $wlCalibrate(loadDir)/CloserTestSpots.tmp ] } {
    wl_Load $wlCalibrate(loadDir)/CloserTestSpots.tmp closerSpots
  } elseif { [wl_Load $wlCalibrate(loadDir)/CloserTestSpots closerSpots] == \
      "Failed" } {
    return "Abort"
  }
  update 
    
  alg.set.matchsize $wlCalibrate(matchsize)
  set stagebestspots [expr $wlCalibrate(StageBestSpots) - $stagePos(PupilImage)]
  set stagecloserspots [expr $wlCalibrate(StageCloserSpots) - \
      $stagePos(PupilImage)]

  alg.match.rects.cents wlCalibrate(TestRects) bestSpots closerSpots \
      wlCalibrate(Centers) $stagebestspots \
      $stagecloserspots = wlCalibrate(TestMatches)
  update

  # Test for several possible errors
  #
  set nmatches [a.cols wlCalibrate(TestMatches)]
    
  if { $nmatches == 0 } { 
    wl_PanelsMsg "No Test Subapertures to Pupil Subapertures matches found!"
    return "OK"
  }
    
  if { $wlCalibrate(circFlg) == "No" } {
    set nrects [expr 0.9 * [a.cols wlCalibrate(TestRects)]]
  } else {
    set nrects [expr 0.9 * [a.cols wlCalibrate(Centers)]]
  }
    
  if { $nmatches < $nrects } {
    id.new wlCalibrate(id)
    id.set.xy $wlCalibrate(id) $wlCalibrate(idxpos) $wlCalibrate(idypos)
    id.set.array wlCalibrate(id) bestSpots
    id.set.title wlCalibrate(id) "Matched Test Rectangles"
    a.v6tov2v4 wlCalibrate(TestMatches) = fpos rects
    id.set.rect.array wlCalibrate(id) rects
    update             

    scan $nrects %d nrects_int
    if { "Abort" == [ PanelsCalError \
	"The calculation of Test subaperture to Pupil subaperture \
	matches is not ideal.   The system expected $nrects_int subaperture \
	matches, but got $nmatches.  Click OK to proceed anyway, Cancel \
	to end calibration or Help for more information" \
        $wsCalHelpText(TestMatches) ] } {
      unset wlCalibrate(id) 
      return "Abort"
    }
    
    if {[winfo exist .waitwin]} {
      if { [winfo exists .waitwin] } {
	destroy .waitwin
      }
    }

    a.save wlCalibrate(TestMatches) $wlCalibrate(saveDir)/TestMatches.tmp
    unset wlCalibrate(id)    
    return "OK"
    
  } else {
    a.save wlCalibrate(TestMatches) $wlCalibrate(saveDir)/TestMatches.tmp
  }
}


#--------------------------------------------------------------------------
# proc CalMatches 
#
# Calculates the matching of the test matches to the ref matches.  
# Generates the following global variables:
#
#	wlCalibrate(FinalCenters)
#	wlCalibrate(FinalRefRects)
#	wlCalibrate(FinalTestRects)
#
# It also writes the following files in the Calibration directory:
#
#	FinalCenters
#	FinalRefRects
#	FinalTestRects
#--------------------------------------------------------------------------

proc CalMatches {} {

  global wlCalibrate

   
  if { $wlCalibrate(TestSubapFlg) == "No" && \
       $wlCalibrate(circFlg) == "No" && \
       $wlCalibrate(EditSubFlg) == "No" } {
    CalLoadFile FinalTestRects
    CalLoadFile FinalRefRects
    CalLoadFile FinalCenters
    return "OK" 
  }

  wl_PanelsWait .waitwin \
      "Matching Reference Subapertures with Test Subapertures..."


  # Do the matchmatching and update globals
  #
  alg.match.matches wlCalibrate(RefMatches) wlCalibrate(TestMatches) = \
      wlCalibrate(FinalRefMatches) wlCalibrate(FinalTestMatches)

  a.v6tov2v4 wlCalibrate(FinalRefMatches) = \
      wlCalibrate(FinalCenters) wlCalibrate(FinalRefRects)

  a.v6tov2v4 wlCalibrate(FinalTestMatches) = \
      wlCalibrate(FinalCenters) wlCalibrate(FinalTestRects)

  set nmatches [a.cols wlCalibrate(FinalTestRects)]
    
  if { $nmatches == 0 } { 
    wl_PanelsMsg "No Reference Subapertures to Test Subapertures matches found!"

    return "OK"
  }
  update 
    
  if {[winfo exist .waitwin]} {
    if { [winfo exists .waitwin] } { destroy .waitwin }
  }

  a.save wlCalibrate(FinalTestRects) $wlCalibrate(saveDir)/FinalTestRects.tmp
  a.save wlCalibrate(FinalRefRects) $wlCalibrate(saveDir)/FinalRefRects.tmp
  a.save wlCalibrate(FinalCenters) $wlCalibrate(saveDir)/FinalCenters.tmp
}


############################################################################
#
# Now follow a number of panel generating routines
# that are specific to Calibration. They should probably be
# moved to the Panels script
#
############################################################################


##---------------------------------------------------------------
## proc CalprocRadio fname llbl llblw lbls gvar lblws bindproc 
## 
## Display labels and check buttons inside frame "fname". 
## A label is shown on the left and correspond to element 0
## in list lbls. Radio buttons are shown for the alternatives 
## for global variable gvar, which are listed in elements 
## listed 1 to n of lbls. 
## The label's width are passed in parameters "lblw". 
## Changes in gvar are binded to procedure "bindproc."
##---------------------------------------------------------------

proc CalprocRadio { fname llbl llblw lbls gvar lblws bindproc } {

    # put a frame around the whole thing
    frame $fname -relief ridge -borderwidth 1; pack $fname -side top

    # draw the label
    frame $fname.label ; pack $fname.label -side left 
    label $fname.label.label -text $llbl \
	-width $llblw -anchor sw
    pack $fname.label.label  -side left

    frame $fname.radios; pack $fname.radios -side left 
    # put the radio buttons
    set count 0
    foreach name [lrange $lbls 0 end] {
	radiobutton $fname.radios.$name -variable $gvar -value $name \
	    -text $name -width [lindex $lblws $count ] -anchor sw
	pack $fname.radios.$name -side left
	incr count

	bind $fname.radios.$name <ButtonRelease-1> $bindproc
    }


}


##---------------------------------------------------------------
## proc Calproc fname lbl gvar lblw gvarw bindproc 
## 
## Display labels inside frame "fname". The labels are string 
## "lbl" and the value of a global variable "gvar", respectively.
## The width of each label are passed in parameters "lblw" and
## "gvarw". Both labels are binded to procedure "bindproc."
##---------------------------------------------------------------

proc Calproc { fname lbl gvar lblw gvarw bindproc } {

    frame $fname -relief ridge -borderwidth 1; pack $fname -side top

    frame $fname.label ; pack $fname.label -side left 
    label $fname.label.label -text  $lbl -width $lblw -anchor sw
    pack $fname.label.label  -side left

    frame $fname.entry; pack $fname.entry -side left 
    label $fname.entry.entry -textvariable $gvar -width $gvarw -anchor sw
    pack $fname.entry.entry -side left -expand true -fill x

    bind $fname <ButtonRelease-1> $bindproc
    bind $fname.label <ButtonRelease-1> $bindproc
    bind $fname.entry <ButtonRelease-1> $bindproc
    bind $fname.label.label <ButtonRelease-1> $bindproc
    bind $fname.entry.entry <ButtonRelease-1> $bindproc
}


#--------------------------------------------------------------------------
# proc SaveDefaultPupilShape
#
# When the user clicks "OK" in the calibration setup dialog box, this
# procedure gets called to save the selected pupil in a file.
#--------------------------------------------------------------------------

proc SaveDefaultPupilShape { } {

  global wlCalibrate LISTS_DIR


  set fileid [open $LISTS_DIR/defaultPupil.tcl w]
  puts $fileid "set wlCalibrate(PupilShape) $wlCalibrate(PupilShape)"
  close $fileid
}


#---------------------------------------------------------------------------
# proc OKCancelDisp
#
# This is a specialized dialog box.  'msg' should either be "dim" or
# "bright".  Displays a message and prompts the user to select OK, Cancel,
# or Camera Image Display.
# Returns Continue on OK or Abort on Cancel.
#---------------------------------------------------------------------------

proc OKCancelDisp { msg geom } {

  global applicationName wlPanel platform animprogpid


  if { [winfo exist .ocd] } { destroy .ocd }

  toplevel .ocd
  wm geometry .ocd $geom
  wm title .ocd "$applicationName"
    
  frame .ocd.frame1 -relief flat 
  pack  .ocd.frame1 -side top
    
  label .ocd.frame1.b -bitmap question
  pack  .ocd.frame1.b -side left -pady 4m -padx 4m
    
  if { $platform == "windows" } { 
    set mesg "The light source is too $msg.
Adjust the source, then click OK.
Click 'Camera Image Display' to view the beam 
(you must close the Display before clicking OK).
Click Cancel to abort Calibration."
  } else {
    set mesg "The light source is too $msg.
Adjust the source, then click OK.
Click 'Camera Image Display' to view the beam 
Click Cancel to abort Calibration."
  }
  message .ocd.frame1.mess -text $mesg -width 12c
  pack    .ocd.frame1.mess -side left

  frame .ocd.frame2 -relief flat 
  pack  .ocd.frame2 -side top
    
  button .ocd.frame2.ybutton -text " OK " \
          -command { set wlPanel(action) Continue }
  button .ocd.frame2.dbutton -text "Camera Image Display" \
	  -command { alignInterface:showRealTimeDisplay }
  button .ocd.frame2.nbutton -text Cancel \
	  -command { set wlPanel(action) Abort }
  pack   .ocd.frame2.ybutton .ocd.frame2.dbutton .ocd.frame2.nbutton \
          -side left -padx 2m -pady 2m
    
  bind .ocd <Destroy> { set wlPanel(action) Abort }

  tkwait variable wlPanel(action)

  set answer $wlPanel(action)
  if { $platform != "windows" } {
    if { [info exists animprogpid] } {
      catch {exec kill -9 $animprogpid}
      unset animprogpid
    }
  }
  if { [winfo exist .ocd] } { destroy .ocd }
  update
    
  return $answer
}


#---------------------------------------------------------------------------
# proc SetProperExposure name
#
# Automatically change the camera exposure to have a maximum value
# be between 100 and 200.  If this is not possible (too bright or too
# dark), give the user the option to adjust it.
#---------------------------------------------------------------------------

proc SetProperExposure { name } { 

  global platform wsdb
  

  set flag "FALSE"
  update
  alignInterface:setCameraExposure $wsdb($name)

  while { $flag != "TRUE" } {
    update

    # Grab an image to test
    #
    if { $platform == "windows" } {
      after 200
    } 

    if [ catch { fg.grab 1 = im } result ] {
      if [ catch { fg.grabc 1 = im } result ] {
	wl_PanelsWarn "Is a Camera Image Display open?  Close it, then click OK."
      }
    }
    if [ catch { fg.grab 1 = im } result ] {
      if [ catch { fg.grabc 1 = im } result ] {
	wl_PanelsWarn "Couldn't grab frames.  Calibration cannot continue."
	return "Abort"
      }
    }
    
    update
    set max [a.max im]

    if { $name == "refNonPupilExposure" || $name == "testPupilExposure" } {
	set minInt 30
    } else {
	set minInt 100
    }
    set maxInt 225

    if { $max > $maxInt } { 
      if { $wsdb($name) == "1/10000" } {
	if { [OKCancelDisp "bright" +200+85] == "Abort" } {
	  set wsdb($name) "1/4000"
	  return "Abort"
	}
      } else {
	camera_exposure shorter $name
      }
      update
    } elseif { $max < $minInt } { 
      if { $wsdb($name) == "1/60" } {
	if { [OKCancelDisp "dim" +200+85] == "Abort" } {
	  set wsdb($name) "1/125" 
	  return "Abort"
	}
      } else {
	camera_exposure longer $name
      }
      update
    } else {
      set flag "TRUE"
    }
    update
  }
    
  if { $flag == "FALSE" } { 
    return "Abort"			
  }
}


#---------------------------------------------------------------------------
# proc CalAdjustExposure
#
# Show message and prompt the user to Display an image, or 
# answer Continue or Abort.
# Returns Continue or Abort if the window is destroyed
# This functionality is mostly duplicated by a similar
# routine in the Alignment portion of the code. These should
# be unified.
#---------------------------------------------------------------------------
proc CalAdjustExposure { msg name title } {

    global applicationName wlPanel wsdb DisplayFlag wlCalibrate
    global ttcalimdis ttsymbol

    # set the camera_exposure to the current value 

    alignInterface:setCameraExposure $wsdb($name)

    if { [winfo exist .adj] } { destroy .adj }

    toplevel .adj
 
    wm geometry .adj +100+350
 
    wm title .adj $title

    message .adj.message -width 8c -text $msg
    
    frame .adj.control -relief flat
    button .adj.control.longer -text Longer \
	-command "camera_exposure longer $name;\
		       if { $DisplayFlag == 1 } { ttCalibrateDisplay }"
    label .adj.control.time -text "$wsdb($name) sec" 
    button .adj.control.shorter -text Shorter \
	-command  "camera_exposure shorter $name;\
		       if { $DisplayFlag == 1 } { ttCalibrateDisplay }"
    pack .adj.control.longer \
	 .adj.control.time \
	 .adj.control.shorter \
	 -side top

    frame .adj.frame2 -relief flat 
    button .adj.frame2.ybutton -text Continue \
	-command { set wlPanel(action) Continue }
    pack .adj.frame2.ybutton -side left -padx 2m -pady 2m

    button .adj.frame2.dbutton -text "Display" \
	-command { set DisplayFlag 1 ; ttCalibrateDisplay }
    pack .adj.frame2.dbutton -side left -padx 2m -pady 2m

    button .adj.frame2.nbutton -text Abort \
	-command { set wlPanel(action) Abort }
    pack .adj.frame2.nbutton -side right -padx 2m -pady 2m

    pack .adj.message \
	 .adj.control \
	 .adj.frame2 \
	 -side top
    
    bind .adj <Destroy> { set wlPanel(action) Abort }

    tkwait variable wlPanel(action)

    set exposureList [alignInterface:getExposureList]
    set wsdb($name) [ lindex $exposureList [current_exposure] ]
    if { [file exists $wlCalibrate(saveDir)] } {
	set fileid [open $wlCalibrate(saveDir)/calData a]
	puts $fileid "set wsdb($name) {$wsdb($name)}"
	close $fileid
    }

    set answer $wlPanel(action)

    if { [winfo exist .adj] } { destroy .adj }
    
    if {[info exist ttcalimdis]} { 
	unset ttcalimdis 
	unset ttsymbol
    }

    return $answer
}


#---------------------------------------------------------------------------
# proc ttCalibrateDisplay
#
# Show the display of Pupil/Spots while adjusting intensity
#---------------------------------------------------------------------------
proc ttCalibrateDisplay { }  {

  global ttcalimdis ttsymbol wlCalibrate platform
  

  if { ![info exist ttsymbol] } {
    set ttsymbol "-"
  } else {
    if { $ttsymbol == "-" } {
      set ttsymbol "|"
    } else {
      set ttsymbol "-"
    }
  }
 
  if {![info exist ttcalimdis]} { id.new ttcalimdis }
  if { $platform == "windows" } { 
    id.set.xy $ttcalimdis 350 180
    id.set.wh $ttcalimdis 620 500
  } else {
    id.set.xy $ttcalimdis $wlCalibrate(idxpos) $wlCalibrate(idypos)
  }
  id.set.title ttcalimdis "Grabbed Image $ttsymbol"

  if { $platform == "windows" } {
    after 200
  }

  if [ catch { fg.grab 1 = im } result ] {
    if [ catch { fg.grabc 1 = im } result ] {
      wl_PanelsWarn "Is a Camera Image Display open?  Close it, then click OK."
    }
  }
  if [ catch { fg.grab 1 = im } result ] {
    if [ catch { fg.grabc 1 = im } result ] {
      wl_PanelsWarn "Couldn't grab frames.  Calibration cannot continue."
      return "Abort"
    }
  }

  if { $platform == "windows" } { 
    id.set.update ttcalimdis im
  } else {
    id.set.array ttcalimdis im
  }
}


###############################################################################
#
# ws_CalcNumRects
#
# Calculates the approximate maximum number of rectangles that one
# could expect for either test or ref images. Sets the threshold
# for error detection at 80% of this maximum
#
################################################################################
proc ws_CalcNumRects { type } \
{
    global wlCalibrate

    if { $type == "test" } \
    {
	update
	if { $wlCalibrate(PupilShape) == "Circular" } { 
	    set puprad $wlCalibrate(rad)
	    set parea [expr $puprad * $puprad * 3.14159]
	} else { 
	    set parea [expr $wlCalibrate(width) * $wlCalibrate(height)]
	}
	if { $parea > [expr $wlCalibrate(CCDxpix) * $wlCalibrate(CCDypix)] } {
	    set parea [expr $wlCalibrate(CCDxpix) * $wlCalibrate(CCDypix)]
	}
	set subspx [expr 1 /  [a.extele wlCalibrate(Params) 0]]
	set subspy [expr 1 /  [a.extele wlCalibrate(Params) 3]]
	set subarea [expr $subspx * $subspy]
	set wlCalibrate(Numsubs) [expr 0.80 * $parea / $subarea]
	update
    }	
    if { $type == "ref" } \
    {
	update
	set subspx [expr 1 /  [a.extele wlCalibrate(Params) 0]]
	set subspy [expr 1 /  [a.extele wlCalibrate(Params) 3]]
	update
	set nsubsx [expr $wlCalibrate(CCDxpix) / $subspx]
	set nsubsy [expr $wlCalibrate(CCDypix) / $subspy]
	set wlCalibrate(Numsubs) [expr 0.80 * $nsubsx * $nsubsy]
	update
    }
}


#-------------------------------------------------------------------#
#
# ws_SetWSParams
#
# Routine that sets parameters that are needed by
# calibration algorithms.
#
#-------------------------------------------------------------------#
proc ws_SetWSParams {} \
  {
    global wlCalibrate wsMLMParams stagePos ws_stat wsParam

    #
    # Get the MLM name and params 
    #
    # Check to see if MLM has been selected
    # if not force user to select one!


    while { $ws_stat(mlm) == ""} \
      {
	if { [SelectMLM] == "cancel" } {
	  return "Abort"
	} else {
	  if { [file exists $wlCalibrate(saveDir)] } {
	    set fileid [open $wlCalibrate(saveDir)/calData a]
	    puts $fileid "set ws_stat(mlm) {$ws_stat(mlm)}"
	    close $fileid
	  }
	}
      }

    ws_GetMLMSpec
    
    if { [file exists $wlCalibrate(saveDir)] } {
      set fileid [open $wlCalibrate(saveDir)/calData a]
      foreach i { name spacing type fl } {
	puts $fileid "set wsMLMParams($i) {$wsMLMParams($i)}"
      }
      close $fileid
    }


#
# Calculate necessary parameters

# Then there are parameters that need to be derived from system level
# parameters
#

    set wlCalibrate(psfScale) [expr ( $wsParam(Lambda) / $wlCalibrate(wsAperture) ) \
				 * 250000.0 ]

    set wlCalibrate(subapSpacing) \
      [expr ($wsMLMParams(spacing) * $wlCalibrate(wsMag)) / $wlCalibrate(wsPixSiz) ]

    set minsep [expr int([expr $wlCalibrate(subapSpacing) / 1.414])]
    set maxsep [expr int([expr $wlCalibrate(subapSpacing) * 1.414])]
    alg.rects.minmax.sep $minsep $maxsep

    if { $wsMLMParams(type) == "S"} { 
      set wlCalibrate(MLM_xxpar) [expr 1.0 / $wlCalibrate(subapSpacing)]
      set wlCalibrate(MLM_yypar) [expr 1.0 / $wlCalibrate(subapSpacing)] 
    } else {
      ######## do something hex ##########
    }



    set wlCalibrate(StageBestSpots) $stagePos(BestRefSpots)

    set wlCalibrate(StageCloserSpots) $stagePos(CloserRefSpots)

}

#####################################################################
#
# 
#
#####################################################################
proc ws_SetGradCal {} \
{
  global wlCalibrate wsMLMParams stagePos stageParams
  set stgMov [expr $stagePos(BestRefSpots) - $stagePos(PupilImage)]
  set stgMov [expr $stgMov * 1000 / $stageParams(StepsPerMM)]
  
  set pxx [a.ext $wlCalibrate(Params) 0 1 ]
  set pyy [a.ext $wlCalibrate(Params) 3 1 ]
  
  set avgParam [expr $pxx + $pyy ]
  set avgParam [expr $avgParam / 2.0]
  
  set wlCalibrate(micronsPerPix) [expr $wsMLMParams(spacing) * \
				  $wsMLMParams(spacing) * $avgParam / $stgMov]
  
  if { [file exists $wlCalibrate(saveDir)] } {
    set fileid [open $wlCalibrate(saveDir)/calData a]
    puts $fileid "set wlCalibrate(micronsPerPix) {$wlCalibrate(micronsPerPix)}"
    close $fileid
  }
}
#####################################################################
#
# This is a stand in for a status panel
#
#####################################################################
proc ws_DataRep { msg } \
{
  # status

  wl_PanelsWait .waitwin "$msg "
}

###################################################################
#
# wlMan_LensletPos
#
# Allows the user to interactively change lenslet grid
#
###################################################################
proc wlMan_LensletPos { } {

    global wlPanel wlCalibrate

    set wlCalibrate(xmove) 0.0
    set wlCalibrate(ymove) 0.0
    set wlCalibrate(xmag) 1.0
    set wlCalibrate(ymag) 1.0
    set wlCalibrate(xrot) 0.0
    set wlCalibrate(yrot) 0.0

    
    if {[ winfo exist .llwin ]} {destroy .llwin}

    toplevel .llwin 
    if {[info exist wlPanel(midWinGeometry)]} {

	wm geometry .llwin $wlPanel(smallWinGeometry)

    } else {

	wm geometry .llwin +0+400

    }

    wm title .llwin "Lenslet Position Parameters"
    
    frame .llwin.top -relief raised -bd 2 
    pack .llwin.top -side top -fill x
    
    message .llwin.top.m1 -text "Click on \"Apply\" or press \"Enter\" to change the parameters;, \"Done\" accepts them." \
	-width 9c 
    pack .llwin.top.m1 -side top
    

    frame .llwin.mid -relief sunken -bd 4 -height 1.7c -borderwidth 3
    
    pack .llwin.mid -side top -fill y -padx 4 -pady 4
    
    # Three frames, for X center, Y center and radius 

    wl_PanelsBasicEntry  .llwin.mid  "Move  X" "wlCalibrate(xmove)"

    wl_PanelsBasicEntry  .llwin.mid  "Move  Y" "wlCalibrate(ymove)"

    wl_PanelsBasicEntry  .llwin.mid  "Magnify  X" "wlCalibrate(xmag)"

    wl_PanelsBasicEntry  .llwin.mid  "Magnify  Y" "wlCalibrate(ymag)"

    wl_PanelsBasicEntry  .llwin.mid  "Rotate x" "wlCalibrate(xrot)"

    wl_PanelsBasicEntry  .llwin.mid  "Rotate y" "wlCalibrate(yrot)"

    # action area

    frame .llwin.bottom -relief sunken -bd 4 
    
    pack .llwin.bottom -side top -fill y -padx 4 -pady 4

    bind .llwin <Return>  { wlMan_SetParam }
    bind .llwin <Escape>  { set wlPanel(action) "Abort" }

    button .llwin.bottom.b0 -text Apply \
	-command { wlMan_SetParam }
    pack .llwin.bottom.b0 -side left
    button .llwin.bottom.b1 -text Done \
	-command { set wlPanel(action) "Done"}
    pack .llwin.bottom.b1 -side left
    button .llwin.bottom.b2 -text "Abort" \
    	-command { set wlPanel(action) "Abort"}
    pack .llwin.bottom.b2 -side right
    
    grab set .llwin

    while { 1 } {

	tkwait variable wlPanel(action)

	if { $wlPanel(action) == "Done" } {

	    if { [winfo exist .llwin] } { destroy .llwin }

	    return $wlPanel(action)

	}    

	if { $wlPanel(action) == "Abort" } {

	    if { [winfo exist .llwin] } { destroy .llwin }

	    return $wlPanel(action)

	}    

    }

}

###################################################
#
# updates the parameters via transformation
#
###################################################
proc wlMan_SetParam { } {

    global wlCalibrate

    set cols [a.cols wlCalibrate(PupilSpots)]

    set rows [a.rows wlCalibrate(PupilSpots)]

    wlMan_transTrans wlCalibrate(Params) $wlCalibrate(xmove) \
	$wlCalibrate(ymove) $wlCalibrate(xmag) $wlCalibrate(ymag) \
	$wlCalibrate(xrot) $wlCalibrate(yrot)

    alg.make.grid wlCalibrate(Params) $cols $rows = \
	wlCalibrate(Centers)

    id.set.pos.array wlCalibrate(id) wlCalibrate(Centers)

    set wlCalibrate(xmove) 0.0
    set wlCalibrate(ymove) 0.0
    set wlCalibrate(xmag) 1.0
    set wlCalibrate(ymag) 1.0
    set wlCalibrate(xrot) 0.0
    set wlCalibrate(yrot) 0.0
   
}
################################################################
# Generates new transformation matrices, given original matrices
# and parameters specifying translation, magnification and 
# rotation. In other words, given a transformation specified
# by
#
#     Xnew1 = S1*Xold + T1
#
# and translation (tx, ty), magnification (mx, my) and rotation
# angle 'ang', the procedures calculates new matrices Snew and 
# Tnew, given by
#
#     Xnew2 = S2*S1*Xold + S2*T1 + T2
#           = Snew * Xold + Tnew
# 
# Snew and Tnew replace S1 and T1
#
# S and T are organized in a vector P = (s11 s12 s21 s22 t1 t2)
#################################################################

proc wlMan_transTrans { Pin tx ty mx my xrot yrot} {

    global wlCalibrate
    upvar $Pin P

    a.flat 3 3 0 = P1

    a.repele [a.extele P 0] P1 0 0 = P1
    a.repele [a.extele P 1] P1 1 0 = P1
    a.repele [a.extele P 4] P1 2 0 = P1
    a.repele [a.extele P 2] P1 0 1 = P1
    a.repele [a.extele P 3] P1 1 1 = P1
    a.repele [a.extele P 5] P1 2 1 = P1
    a.repele 1 P1 2 2 = P1

    a.flat 3 3 0 = P2
    
    a.repele [expr (1.0/$mx)*cos(3.1416*$yrot/180)] P2 0 0 = P2
    a.repele [expr -(1.0/$my)*sin(3.1416*$xrot/180)] P2 1 0 = P2
    a.repele [expr -$tx/$wlCalibrate(subapSpacing)] P2 2 0 = P2
    a.repele [expr (1.0/$mx)*sin(3.1416*$yrot/180)] P2 0 1 = P2
    a.repele [expr (1.0/$my)*cos(3.1416*$xrot/180)] P2 1 1 = P2
    a.repele [expr -$ty/$wlCalibrate(subapSpacing)] P2 2 1 = P2
    a.repele 1 P2 2 2 = P2

    a.matprod P2 P1 =  P3

    a.repele [a.extele P3 0 0] P 0 = P
    a.repele [a.extele P3 1 0] P 1 = P
    a.repele [a.extele P3 2 0] P 4 = P
    a.repele [a.extele P3 0 1] P 2 = P
    a.repele [a.extele P3 1 1] P 3 = P
    a.repele [a.extele P3 2 1] P 5 = P

}


#####################################################################
#
# The following routines were designed to deal with the manual
# loading of Calibration files. They were retained because at
# the time this was generated, the proceedure for saving and
# retreving Calibration data was undefined.
#
#####################################################################

##-------------------------------------------------------------------
## proc wl_CalSetLoadDir
##
## Set the base directory to load calibration files from
##-------------------------------------------------------------------

proc wl_CalSetLoadDir { base } \
{
    global wlCalibrate

    set wlCalibrate(loadDir) "$base/$wlCalibrate(baseDirName)"
}


#--------------------------------------------------------------------------
# proc CalLoadFile
#
# Load in a calibration file given by $name. The file will be taken from
# $wlCalibrate(loadDir)
#--------------------------------------------------------------------------

proc CalLoadFile { name } {

  global wlCalibrate


  # Have we been passed a valid calibration file type?
  #
  if { [lsearch -exact $wlCalibrate(fileNames) $name] == -1 } {
    wl_PanelsMsg "Attempted to load invalid calibration file: $name"
    return "Abort"
  }

  # Get the full path to the file
  #
  set file_name "$wlCalibrate(loadDir)/$name"

  # Does the file exists?
  #
  if { ! [file exists $file_name] } { 
    wl_PanelsMsg "Calibration file does not exist: $file_name" 
    return "Abort"
  }

  # Load the file
  #
  wl_Load $file_name wlCalibrate($name)

  return "OK"
}


##-------------------------------------------------------------------
## proc wl_CalSetSaveDir
##
## Set the base directory to save calibration files to
##-------------------------------------------------------------------

proc wl_CalSetSaveDir { base } \
{
    global wlCalibrate

    set wlCalibrate(saveDir) "$base/$wlCalibrate(baseDirName)"
}

##------------------------------------------------------------------
## proc wl_CalSaveFile
##
## Save a calibration array $name. The save file will be taken from
## $wlCalibrate(saveDir)
##------------------------------------------------------------------

proc wl_CalSaveFile { name } \
{
    global wlCalibrate

    #
    # Have we been passed a valid calibration file type?
    #
    if { [lsearch -exact $wlCalibrate(fileNames) $name] == -1 } {

	wl_PanelsMsg "attempt to save invalid calibration file: $name"

	return "Abort"

    }

    #
    # Get the full path to the file
    #
    set file_name "$wlCalibrate(saveDir)/$name"

    #
    # Save the file
    #
    wl_Save $wlCalibrate($name) $file_name 

}