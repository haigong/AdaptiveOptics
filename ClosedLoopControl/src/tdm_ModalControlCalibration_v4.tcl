#------------------------------------------------------------------------
# tdm_ModalControlCalibration.tcl                tcl script
#
# Procedures used in calibration of transparent electrode membrane
# mirror using for use with modal control algorithm.  This file is
# based upon tdm_ModalControlProcedures_v12.tcl which is its pre-
# decessor.
#
# Procedures in this file:
#
#       calibrateDMForModalControl
#       pokeBinnedActuators_TrainModalControl
#       getWFReconInflFuncPeakPosition
#       findPeakInteractive
#       mouseDownEvent
#       flattenDMUsingModalControl
#       computeMembraneShapeAndLaplacian
#       computeModalControlVoltagesAndSendToDACs
#       decomposeWavefrontIntoZernikeCoeffs
#       displayActuatorGridAndWavefront
#
# Note:  to initialize procedures in this file with the wavescope
# software, add lines such as the following to the tclIndex.tcl file
# in usr/aos/wavescope/scripts/
#        e.g. set auto_index(decomposeWavefrontZernikeCoeffs) \
#               [list source [file join tdm_ModalControlProcedures.tcl]]
#
# version 4
# plk 06/23/2005
#------------------------------------------------------------------------

# =======================================================================
# OPERATION FLAGS:  These must be set to "1" in the proper order by
# executing the appropriate procedures to prepare the device for closed
# loop operation.
#
# ORDER           NAME                                PROCEDURE
#  1 gRegisterCoordsForModalControlFlag      registerDMForModalControl
#  2 gCalibrateDMForModalControlFlag         calibrateSemiAutoDMForModalControl
#  3 gTrainDMForModalControlFlag             trainDM
# =======================================================================
global gRegisterCoordsForModalControlFlag
global gCalibrateDMForModalControlFlag


# Image display ID for the FINDPEAK image display window.  Used in
# modal control training.
global FINDPEAK_ID

# Image display ID for the ACTUATORGRIDANDWAVEFRONT display window.
# Used to validate actuator position calibration.
global ACTUATORGRIDANDWAVEFRONT_ID

# User selected position of peak in current image.  Used in findPeakInteractive
global double gUserSelectPeakX
global double gUserSelectPeakY

# Conversion factors from "wavefront pixel" coordinates to "image pixel"
# coordinates.  See registerCoordsForModalControl
global gWavPixToImagPixColXConvFactA
global gWavPixToImagPixRowYConvFactA



# Number of terms in Zernike expansion of wavefront, integer
global gNumberOfZernikeTerms

# Zernike coefficients of current wavefront, V2 array
global gWavefrontZernikeCoeffsV2

global gMembraneShapeZernikeCoeffsV2
global gMembraneLaplacianZernikeCoeffsV2

# Membrane shape and Laplacian, computed at actuator center positions
# < xi  yi   xi(xi,yi)   del2 xi(xi,yi) >
# See computeMembraneShapeAndLaplacian
global gMembraneShapeV4

# X,Y positions of each binned actuator center, in "wavefront pixel"
# coordinates and "image pixel" coordinates respectively.  See
# registerCoordsForModalControl for details.
global gActuatorPositionV4
global gActuatorPosition_ImagPixV4

# <i j x y> position of test actuators used in
# semi-auto training method
global gFirstTestActuatorPositionV4
global gSecondTestActuatorPositionV4

# binning parameters used in modal control procedures.
global gModalControlNumberOfActuatorsPerBin
global gModalControlNumberOfBinnedActuators

#---------------------------------------------------------------------------
# registerCoordsForModalControl
#
# register coordinate system determined by mouse down events in wavefront
# display window with coordinates used in wavescope calibration.  User is
# presented with a wavefront image display, and asked to label the center
# of the display with a small rectangle.  The position of the pointer is
# then used to determine the registration coefficients between the
# wavefront pixel coordinates and the image pixel coordinates.  The result
# of this procedure is population of the global variables gWavPixToImagPix
# ColXConvFactA and gWavPixToImagPixRowYConvFactA with the necessary values
# to do the conversion.
#
# "Wavefront pixel" coordinates:
#            Used in wavefront image display windows.
#            (x,y) = (col., row) [0,0] x [~45,35]
#            origin is in lower left corner of window.
#
# "Image pixel" coordinates:
#            Used in image display windows; set during wavescope calibration.
#            (x,y) = (col., row) [0,0] x [640,480]
#            origin is in lower left corner of window.
#
#
# called by: displayRegisterCoordsPanel
#---------------------------------------------------------------------------
proc registerCoordsForModalControl { } \
{

    global FINDPEAK_ID

    global wlCalibrate stagePos
    global gWavPixToImagPixColXConvFactA
    global gWavPixToImagPixRowYConvFactA

    global gRegisterCoordsForModalControlFlag




    if { $wlCalibrate(doneInit) != "Yes" } {
	dialog "Please Calibrate WaveScope."
	return
    }
    stage.calibrate.absolute $stagePos(BestRefSpots)

    # set image display for the findpeak window, used in
    # findPeakInteractive procedure.  Initialize ID window
    # and place it on the display.
    id.new FINDPEAK_ID
    id.set.title FINDPEAK_ID "Wavefront. East is Up; North is Right."
    id.set.wh FINDPEAK_ID 350 350
    id.set.xy FINDPEAK_ID 50 100


    # Have user select center of wavefront using mouse.  X,Y
    # positions of center are returned in V4 vector.

    # columns are "i" values, rows are "j" values in wavescope software
    set theDummyRow 0
    set theDummyCol 0
    calibrateTestActuator theDummyCol \
                          theDummyRow \
                          theFindPeakDisplayCenterPositionV4

    #DEBUG
    puts stdout "registerCoordsForModalControl:"
    puts stdout "[a.dump theFindPeakDisplayCenterPositionV4]"

    # values returned by mouse selection procedure are in
    # "wavefront pixel" coordinates, where (0,0) is lower left
    # of the wavefront display window, and typ. values are
    # X = [0,45]  Y = [0,30]
    #
    a.v4tov2v2 theFindPeakDisplayCenterPositionV4 = theIJV2 theCenterXY_WavPixV2
    a.v2toxy theCenterXY_WavPixV2 = theCenterColX_WavPixA theCenterRowY_WavPixA

    a.inv theCenterColX_WavPixA = theInvCenterColX_WavPixA
    a.inv theCenterRowY_WavPixA = theInvCenterRowY_WavPixA



    # center of wavefront pupil, from calibration, in
    # "image pixel" coordinates.  These coords are X = [0,640]
    # Y = [0,480] where (0,0) is lower left of window.  Center
    # of pupil is established in calibration procedure.  Wavescope
    # computations, Zernike polynomial etc. are performed in these
    # image pixel coordinates.
    #
    # wlCalibrate(Pupil) [0] = center X value (Col)
    #                    [1] = center Y value (Row)
    #                    [2] = pupil radius
    #
    a.extele wlCalibrate(Pupil) 0 = theCenterColX_ImagPixA
    a.extele wlCalibrate(Pupil) 1 = theCenterRowY_ImagPixA


    # conversion factors from "wavefront pixel" to
    # "image pixel" coordinates.  Coordinates selected
    # with mouse selection procedure must be multiplied
    # by these factors to convert them to coordinates
    # compatible with wavescope wavefront computations.
    a.mul theCenterColX_ImagPixA \
          theInvCenterColX_WavPixA \
          = gWavPixToImagPixColXConvFactA

    a.mul theCenterRowY_ImagPixA \
          theInvCenterRowY_WavPixA \
          = gWavPixToImagPixRowYConvFactA



    id.exit FINDPEAK_ID


    puts stdout "registerCoordsForModalControl: completed."
}



#---------------------------------------------------------------------------
# getWFReconInflFuncPeakPosition
#
# Gets the wavefront recontstructed influence function peak position. Given
# wavefront gradient data from an influence function measurement, this
# procedure reconstructs the wavefront, finds the extremum, corresponding
# to the peak of the wavefront, and returns the X,Y coordinates of this
# peak.
#
#
# input parameter:   inGradV4     column vector array of v4 elements where
#                                 each element is of the form
#                                 < x , y, dphi/dx , dphi/dy >.  This is
#                                 the measured wavefront gradient.
#
# output parameter:  outXYV2      v2 array specifying the x,y coordinates
#                                 of the position where
#                                 abs( (dphi/dx)^2 + (dphi/dy)^2 )
#                                 is a minimum.
#
# (will be) called by:  pokeBinnedActuators_CalibrateModalControl
# in place of getV4GradientEqZeroPosition
#
#
#
# plk 5/17/2005
#---------------------------------------------------------------------------

proc getWFReconInflFuncPeakPosition { inGradV4 outXYV2 } {

   global wlCalibrate params

   upvar $inGradV4 theGradV4
   upvar $outXYV2 theXYV2

   a.v4tov2v2 $theGradV4 = theXYPosV2 theGradV2

   # create a regular 2D output gradient array and weight mask
   alg.conv.pg.arrays $theGradV4 $wlCalibrate(Params) = theGxGyV2 theMaskArray

   # reconstruct the wavefront from gradient, mask data.  Output is
   # 2D array of floating point values.
   alg.recon.fast theGxGyV2 theMaskArray = theWavefrontSurfaceF

   findPeakInteractive theWavefrontSurfaceF theXYV2

}



#---------------------------------------------------------------------------
# findPeakInteractive
#
# finds the spot(s) / peaks in an array and returns the peak position in
# x,y coordinates as a vector V2.
#
# Uses wavescope atomic functions to perform image segmentation.  Displays
# OPD on an image display window, along with rectangle marking the peak
# identified with this procedure.
#
# parameters   in2DArrayF    input 2D array of float values (i.e. an image,
#                            or a wavefront).
#              outXYV2       output vector V2 of < x, y > column, row
#                            values of the peak in the input array.
#
# called by:  getWFReconInflFuncPeakPosition
#
# plk 5/17/2005
#---------------------------------------------------------------------------

proc findPeakInteractive { in2DArrayF outXYV2 } {

    global FINDPEAK_ID
    global double gUserSelectPeakX
    global double gUserSelectPeakY

    upvar $in2DArrayF theArray
    upvar $outXYV2 theXYV2

     
    # display the current array in the findpeak window
    id.set.array FINDPEAK_ID theArray

    # execute this procedure when user selects a point with the mouse
    id.set.callback FINDPEAK_ID mouseDownEvent

    # find the peak(s) in theArray
    alg.find.rects.slow theArray = theRectArray

    #DEBUG
    #puts stdout "findPeakInteractive: theRectArray"
    #puts stdout "[a.info theRectArray]"
    #puts stdout "[a.dump theRectArray]"

    # if segmentation came up empty, the just fake something.
    # this prevents mysterious error '#9' 
    if { [a.cols theRectArray] == 0 } {
         a.make "<1 1 1 1>" 1 = theRectArray
    }

    # display the found peak as circumscribing rectangle(s)
    id.set.rect.array FINDPEAK_ID theRectArray

    # parse the rectangle and find the center from (x,y)_upper left and
    # width, height.  theRectArray elements are of the form:
    # < x y w h >.  Units of theXYV2 are row, column of the input array.
    a.v4tov2v2 theRectArray = theRectXY theRectWH

    set theNumRects [a.cols theRectArray]


    a.v2toxy theRectXY = theRectX theRectY
    a.v2toxy theRectWH = theRectW theRectH

    a.mul theRectW 0.5 = theRectHalfW
    a.mul theRectH 0.5 = theRectHalfH

    a.add theRectX theRectHalfW = thePeakCenterX
    a.add theRectY theRectHalfH = thePeakCenterY

    # theXYV2 is the V2 array of <x y> positions of the centers
    # of the peaks found by the segmentation algorithm.
    a.xytov2 thePeakCenterX thePeakCenterY = theXYV2

    # Wait for User to click "OK" after choosing a peak
    # position in the ID window ...
    dialog "Select peak in Wavefront window"

    # clear the callback request (mouse down event handler)
    id.set.callback FINDPEAK_ID " "

    # transfer user selected x,y values of peak position to
    # output parameter of this procedure.

    a.make 0.0 1 = theUserSelectPeakXA
    a.make 0.0 1 = theUserSelectPeakYA

    a.repele $gUserSelectPeakX theUserSelectPeakXA 0 = theUserSelectPeakXA
    a.repele $gUserSelectPeakY theUserSelectPeakYA 0 = theUserSelectPeakYA
    a.xytov2 theUserSelectPeakXA theUserSelectPeakYA = theXYV2

}

#---------------------------------------------------------------------------
# mouseDownEvent
#
# Event handler for the mouseDown event.  Allows user to select a point
# on the active image display.  The X,Y coordinates of the point are
# stored in global variables, and a box is drawn around the selected
# position.  Coordinates are stored in floating point, row, column units.
#
# See wavescope manual entry id.set.callback
#
# parameters:  inID     image display ID
#              inEvent  1 = mouse moved
#                       2 = mouse down
#                       3 = mouse up
#              inX      X coord of event (column, floating point)
#              inY      Y coord of event (row, floating point)
#              inT      Time of event (floating point)
#              inKBD    Keyboard state (mouse mask bits)
#                       1 = button 1
#                       2 = button 2
#                       4 = shift key down
#                       8 = ctrl key down
#
# uses global variables:
#
#             FINDPEAK_ID               Image display ID of window
#             gUserSelectPeakX          floating point, column number of
#                                       user selected position
#             gUserSelectPeakY          floating point, row number of
#                                       user selected position
#
# called by: findPeakInteractive (mouseDown event handler)
#
# 05/17/2005
#---------------------------------------------------------------------------
proc mouseDownEvent { inID inEvent inX inY inT inKBD } {

  global FINDPEAK_ID

  global double gUserSelectPeakX
  global double gUserSelectPeakY


  # If Mouse Down Event ...
  if { $inEvent == 2 } {

       #DEBUG
       #puts stdout "mouseDownEvent: position x=$inX  y=$inY"

       # place a rectangle centered over the mouse image
       set theXL [expr $inX-1]
       set theYL [expr $inY-1]
       set theW 2
       set theH 2
       set theV4Element "<$theXL $theYL $theW $theH>"
       a.make $theV4Element = theRectV4

       #DEBUG
       #puts stdout "mouseDownEvent: $theV4Element"

       id.set.rect.array FINDPEAK_ID theRectV4

       # store user selected x,y coords in global variable
       # for transfer to return parameter of findPeakInteractive
       set gUserSelectPeakX $inX
       set gUserSelectPeakY $inY
  }

}



#---------------------------------------------------------------------------
# calibrateFirstTestActuator
#
# Step 1/3 in semi-auto training procedure.  Calibrate a test actuator
# position with the wavescope.  Poke the test actuator, allow user to
# select peak position on wavescope image display.
#
# called by: displaySemiAutoTrainingPanel
#
#
# 5/19/2005
#---------------------------------------------------------------------------
proc calibrateFirstTestActuator { } \
{
    global gFirstTestActuatorRow
    global gFirstTestActuatorCol
    global gFirstTestActuatorPositionV4
    global FINDPEAK_ID

    global wlCalibrate stagePos Grad


    #DEBUG
    #dialog "Debug Pause Here"

    if { $wlCalibrate(doneInit) != "Yes" } {
	dialog "Please Calibrate WaveScope."
	return
    }
    stage.calibrate.absolute $stagePos(BestRefSpots)

    # set image display for the findpeak window, used in
    # findPeakInteractive procedure.  Initialize ID window
    # and place it on the display.
    id.new FINDPEAK_ID
    id.set.title FINDPEAK_ID "Wavefront. East is Up; North is Right."
    id.set.wh FINDPEAK_ID 350 350
    id.set.xy FINDPEAK_ID 50 100



    # columns are "i" values, rows are "j" values in wavescope software
    calibrateTestActuator gFirstTestActuatorRow \
                          gFirstTestActuatorCol \
                          gFirstTestActuatorPositionV4

    puts stdout "CalibrateFirstTestActuator:"
    puts stdout "[a.dump gFirstTestActuatorPositionV4]"

    
    a.make "<-1 2>" = theXYV2
    getV4GradientEqZeroPosition Grad theXYV2


    id.exit FINDPEAK_ID


}


#---------------------------------------------------------------------------
# calibrateSecondTestActuator
#
# Step 2/3 in semi-auto training procedure.  Calibrate a test actuator
# position with the wavescope.  Poke the test actuator, allow user to
# select peak position on wavescope image display.
#
# called by: displaySemiAutoTrainingPanel
#
#
# 5/19/2005
#---------------------------------------------------------------------------
proc calibrateSecondTestActuator { } \
{
    global gSecondTestActuatorRow
    global gSecondTestActuatorCol
    global gSecondTestActuatorPositionV4
    global FINDPEAK_ID

    global wlCalibrate stagePos


    #DEBUG
    #dialog "Debug Pause Here"

    if { $wlCalibrate(doneInit) != "Yes" } {
	dialog "Please Calibrate WaveScope."
	return
    }
    stage.calibrate.absolute $stagePos(BestRefSpots)

    # set image display for the findpeak window, used in
    # findPeakInteractive procedure.  Initialize ID window
    # and place it on the display.
    id.new FINDPEAK_ID
    id.set.title FINDPEAK_ID "Wavefront. East is Up; North is Right."
    id.set.wh FINDPEAK_ID 350 350
    id.set.xy FINDPEAK_ID 100 100


    # columns are "i" values, rows are "j" values in wavescope software
    calibrateTestActuator gSecondTestActuatorRow \
                          gSecondTestActuatorCol \
                          gSecondTestActuatorPositionV4

    puts stdout "CalibrateSecondTestActuator:"
    puts stdout "[a.dump gSecondTestActuatorPositionV4]"

    id.exit FINDPEAK_ID


}




#---------------------------------------------------------------------------
# calibrateTestActuator
#
# Calibrate a test actuator position with the wavescope.  Poke the test
# actuator, allow user to select peak position on wavescope image display.
#
#
# input parameters:
#
#       inI, inJ                    Column, Row of test actuator
#
# output parameters:
#
#       outActuatorPositionV4       v4 array containing the user selected
#                                   actuator positon corresponding to
#                                   actuator i,j in the format:  < i j x y >
#                                   x,y are floating point, column/row nums.
#                                   x,y are in "wavefront pixel" coordinates.
#                                   See registerCoordsForModalControl proc.
#
# called by: calibrateFirstTestActuator
#
#
# 5/19/2005
#---------------------------------------------------------------------------

proc calibrateTestActuator { inI inJ outActuatorPositionV4 } \
{

    global gModalControlNumberOfActuatorsPerBin
    global gModalControlNumberOfBinnedActuators
    global gActuatorPositionV4
    global gNAPerSide

    global Grad gvd CurDrv Drvs Grds MAX_ACT maskArray pokeFraction
    global wlCalibrate YACT_LINE_LENGTH XACT_LINE_LENGTH


    upvar $outActuatorPositionV4 theActuatorPositionV4
    upvar $inI theI
    upvar $inJ theJ
    

    # Display gradients while we work.
    #
    #vd.new gvd
    #vd.set.title gvd "Measured Gradient"
    #vd.set.xy gvd 50 50
    #vd.set.wh gvd 300 300


    #set, initialize array of actuator center positions
    a.make "<-1 2>" 1 1 = theActuatorPositionV2
    a.make "<-1 2>" 1 1 = theIJV2
    a.make "<-1 2>" 1 1 = theTempV2


    # make some arrays of zeros to use to fill matrices
    # when we reach dead actuators
    set nsubs [a.cols wlCalibrate(FinalCenters)]
    a.make 0 $MAX_ACT = zeros
    a.make "< 0 0 >" $nsubs = gzeros

    # Poke each actuator from 0..1, and calculate the gradient.
    #
    FlatDM
    a.copy CurDrv = CurDrv0

   # set the parameters for the binning of actuators based on
   # the number of actuators per bin.
   #
   # why is this a global variable?
   set gModalControlNumberOfActuatorsPerBin [expr $gNAPerSide * $gNAPerSide]

   # for N X N binning of actuators
   # theNumberOfActuatorsPerBin = N*N
   set theNumberOfActuatorsPerBin $gModalControlNumberOfActuatorsPerBin

   #DEBUG
   #puts stdout "theNumberOfActuatorsPerBin = $theNumberOfActuatorsPerBin"

   set theIBinWidth [expr int(sqrt($theNumberOfActuatorsPerBin))]
   set theJBinWidth [expr int(sqrt($theNumberOfActuatorsPerBin))]

   # assume square bins for computing the row, column ranges below
   set theN $theIBinWidth

   # set the relative row, column ranges for the NxN bin
   # this code will produce the following (e.g.)
   # # actuators   binning    Bx_lo   Bx_hi
   # -----------   -------    -----   -----
   #      4          2x2         0       1
   #      9          3x3        -1       1
   #     25          5x5        -2       2
   #    256         16x16       -7       8
   #    512         32x32       -15     16

   set theNisEven [expr int(1 - fmod($theN,2))]
   set Bi_lo [expr -1*int($theN/2) + $theNisEven]
   set Bi_hi [expr int($theN/2)]
   set Bj_lo [expr -1*int($theN/2) + $theNisEven]
   set Bj_hi [expr int($theN/2)]

   # why need this here? plk 6/7/2005
   #set gModalControlNumberOfBinnedActuators 1

   set i $theI
   set j $theJ


   # array for storing preliminary desired deflection data
   a.make 0 $MAX_ACT = CD

   # set Grad array.  This step may not be necessary for computations
   # below, but Grad must be defined on first pass through the
   # for loops
   #vd.new Grad
   update
   calcGrad 10
   #vd.set.array gvd Grad

   #DEBUG
   puts stdout "calibrateTestActuator: Binned Actuator: i=$i j=$j"

   # loop over actuators in each bin.  Limits are determined by
   # the type of binning, defined above.
   for { set Bi $Bi_lo } { $Bi <= $Bi_hi } { incr Bi } {
        for { set Bj $Bj_lo } { $Bj <= $Bj_hi} { incr Bj } {


                #incr gModalControlNumberOfBinnedActuators

                # absolute i,j values of the current actuator
                set Bi_abs [expr $Bi + $i]
                set Bj_abs [expr $Bj + $j]

                # Harold Dysons integer index number of the actuator
                set theHDActuatorIndex \
                     [expr $Bi_abs*$XACT_LINE_LENGTH +$Bj_abs]

                # if current actuator is within the active area
                # of the array ...
                if { $Bi_abs >= 0 && $Bi_abs < $XACT_LINE_LENGTH } {
                   if { $Bj_abs >= 0 && $Bj_abs < $YACT_LINE_LENGTH } {

                        # ...and if the actuator is not masked ...
                        if { [ a.extele maskArray $theHDActuatorIndex ] == 1 } {

                             # ...set the corresponding element of
                             # the CD (curvature drive) array to the
                             # value $pokeFraction.  This actuator
                             # will then have a voltage applied to
                             # it (below).

                             # DEBUG
                             #puts stdout \
                             #   "\t Bi=$Bi Bj=$Bj Index $theHDActuatorIndex"

                             # ... then update CD array
                             a.repele $pokeFraction CD $theHDActuatorIndex = CD


                        } else {
                             # ...else the actutor is masked

                             #DEBUG
                             #puts "Skipping masked actuator: $j x $i"

                             # why set CD array to zero below?
                             # this line commented out.
                             # plk 12/17/2004
                             #a.copy zeros = CD

                             a.v2v2tov4 wlCalibrate(FinalCenters) gzeros = Grad
                        }
                   }
                }
        }
   }

   a.add CD CurDrv0 = CurDrv


   # ... update the GUI display
   SetGUIActs $CurDrv

   # ... convert CurDrv to voltage
   ftov $CurDrv uuu


   # ... send voltages to the hardware
   dm.send uuu
   update

   # calculate gradient by grabbing 10 images; result
   # is stored in global variable Grad
   calcGrad 10


   # find the x,y coordinates of the influence function
   # peak centers.  Grad is an array of v4 vectors
   # (x,y, dphi/dx, dphi/dy) containing wavefront data
   getWFReconInflFuncPeakPosition Grad theXYv2


   # insert 500 ms wait time here for membrane to settle.
   # set voltages to zero.  Wait for membrane to settle once more.
   #after 500
   #setzero
   #after 500

   #vd.set.array gvd Grad


   # store current binned actuator i,j values
   # as v2 array, for combinining into global
   # v4 array ...
   a.make 0.0 1 = theIA
   a.make 0.0 1 = theJA

   a.repele $i theIA 0 = theIA
   a.repele $j theJA 0 = theJA
   a.xytov2 theIA theJA = theIJV2

   # DEBUG
   #puts stdout "[a.info theIJV2]"
   #puts stdout "[a.info theXYv2]"

   # populate the gActuatorPositionV4 array current row element
   # with the x,y positions of the current actuator.

   a.copy CD = Drvs
   a.copy Grad = Grds

   a.v2v2tov4 theIJV2 theXYv2 = theActuatorPositionV4


   update


   a.make 0 $MAX_ACT = CurDrv


   set gvd 0

   # set all electrodes to zero before returning
   setzero

}




#---------------------------------------------------------------------------
# calibrateSemiAutoDMForModalControl
#
# Step 3/3 in semi-auto calibration procedure.  Given calibrated test actuator
# positions, compute the positions of all of the binned actuators from a
# linear model.  Store the actuator positions in global array
# gActuatorPositionV4 to complete the training.
#
# called by: displaySemiAutoTrainingPanel
#
# COMPLETE.  DEBUGGED WITH testStub procedure.  Verified with wavescope.
#
# NOTE:  Calibration test actuator positions must have different row,
#        column values in order for this calibration to work properly.
#
# NOTE:  Actuator positions transformed from wavefront pixel coordinates
#        to image pixel coordinates.  See registerCoordsForModalControl
#
# 6/23/2005
#---------------------------------------------------------------------------
proc calibrateSemiAutoDMForModalControl { } \
{
   global gFirstTestActuatorPositionV4
   global gSecondTestActuatorPositionV4
   global gModalControlNumberOfActuatorsPerBin
   global gActuatorPositionV4
   global gActuatorPosition_ImagPixV4
   global gWavPixToImagPixColXConvFactA
   global gWavPixToImagPixRowYConvFactA
   global gRegisterCoordsForModalControlFlag
   global gCalibrateDMForModalControlFlag

   global XACT_LINE_LENGTH
   global YACT_LINE_LENGTH



   if { $gRegisterCoordsForModalControlFlag != 1 } {
	dialog "Please Register Coordinates."
	return
   }



   # compute "slope" constants for deriving all actuator positions
   # based upon calibration data.
   a.sub gSecondTestActuatorPositionV4 gFirstTestActuatorPositionV4 = theDeltaV4


   # conversion factors "slope" and "intercept"
   # for translating(i,j) --> (x,y)
   #
   # x = f(i) = mf * i + bf
   # y = g(j) = mg * j + bg
   #
   # m's, b's found from calibrated actuator positions:
   # 1:  < i1 j1 x1 y1 >    2: < i2 j2 x2 y2 >
   #
   # mf = (x2 - x1)/(i2 - i1)  bf = x1 - Mf*i1
   # mg = (y2 - y1)/(j2 - j1)  bg = y1 - Mg*j1

   a.v4tov2v2 theDeltaV4 = theDijV2 theDxyV2
   a.v2toxy theDijV2 = theDi theDj
   a.v2toxy theDxyV2 = theDx theDy

   #DEBUG
   # swapped j and i
   a.div theDx theDj = theMf
   a.div theDy theDi = theMg

   a.v4tov2v2 gFirstTestActuatorPositionV4 = theFijV2 theFxyV2
   a.v2toxy theFijV2 = theFi theFj
   a.v2toxy theFxyV2 = theFx theFy

   #DEBUG
   # swapped j and i
   a.mul theMf theFj = theTemp1
   a.mul theMg theFi = theTemp2

   a.sub theFx theTemp1 = theBf
   a.sub theFy theTemp2 = theBg




   # for N X N binning of actuators
   # theNumberOfActuatorsPerBin = N*N
   set theNumberOfActuatorsPerBin $gModalControlNumberOfActuatorsPerBin

   #DEBUG
   #puts stdout "theNumberOfActuatorsPerBin = $theNumberOfActuatorsPerBin"

   set theIBinWidth [expr int(sqrt($theNumberOfActuatorsPerBin))]
   set theJBinWidth [expr int(sqrt($theNumberOfActuatorsPerBin))]



   # determine i,j, x, y values for each actuator, based upon
   # semi-auto training results.

   set theBinnedActuatorNumber 1

   #DEBUG
   #puts "calibrateSemiAutoDMForModalControl: theIBinWidth = $theIBinWidth"
   #puts "calibrateSemiAutoDMForModalControl: theJBinWidth = $theJBinWidth"
   #puts "calibrateSemiAutoDMForModalControl: XACT_LINE_LENGTH = $XACT_LINE_LENGTH"
   #puts "calibrateSemiAutoDMForModalControl: YACT_LINE_LENGTH = $YACT_LINE_LENGTH"


   # loop over the actuators in the array, modulo binning
   # i,j determines actuator at the bin center (odd binning) or
   # the actuator to the immediate "lower left" of bin center (even binning).
   for { set i 0 } { $i < $XACT_LINE_LENGTH } { incr i $theIBinWidth } {
        for { set j 0 } { $j < $YACT_LINE_LENGTH } { incr j $theJBinWidth } {

                # promote i,j to wavescope arrays.
                a.make $i 1 = theiA
                a.make $j 1 = thejA

                #DEBUG
                #puts "theiA = [a.dump theiA]"
                #puts "thejA = [a.dump thejA]"

                # compute x,y coords of binned-actuator center
                # from calibration data, conversion params (above)

                #DEBUG
                # swapped iA and jA
                a.mul theMf thejA = theTempi
                a.mul theMg theiA = theTempj


                # X,Y are in "wavefront pixel" coordinates.
                # See below.
                a.add theTempi theBf = theX
                a.add theTempj theBg = theY

                # convert X,Y from "wavefront pixel" coordinates
                # to "image pixel" coordinates.  See procedure
                # registerCoordsForModalControl above.
                a.mul theX gWavPixToImagPixColXConvFactA = theX_ImagPix
                a.mul theY gWavPixToImagPixRowYConvFactA = theY_ImagPix


                # promote current binned actuator coords. to v4
                a.xytov2 theiA thejA = theIJV2
                a.xytov2 theX theY = theXYV2
                a.xytov2 theX_ImagPix theY_ImagPix = theXY_ImagPixV2

                a.v2v2tov4 theIJV2 theXYV2 = theNextV4
                a.v2v2tov4 theIJV2 theXY_ImagPixV2 = theNext_ImagPixV4

                # DEBUG
                #puts "theNextV4 = [a.dump theNextV4]"
                #puts "theNext_ImagPixV4 = [a.dump theNext_ImagPixV4]"

                
                # populate the gActuatorPositionV4 array current row element
                # with the x,y positions of the current actuator.
                if { $theBinnedActuatorNumber == 1 }\
                {
                   a.copy theNextV4 = gActuatorPositionV4
                   a.copy theNext_ImagPixV4 = gActuatorPosition_ImagPixV4

                } else \
                {
                   a.catrow gActuatorPositionV4 theNextV4 = gActuatorPositionV4
                   a.catrow gActuatorPosition_ImagPixV4 \
                            theNext_ImagPixV4 \
                            = gActuatorPosition_ImagPixV4

                }

                incr theBinnedActuatorNumber

        }
   }

   #DEBUG
   puts stdout "calibrateSemiAutoDMForModalControl: completed"

   set gCalibrateDMForModalControlFlag 1

}





#---------------------------------------------------------------------------
# testStub
#
# Test procedure for calibrateSemiAutoDMForModalControl
#
# executing calibrateSemiAutoDMForModalControl after this
# procedure should generate gActuatorPositionV4 array
# as follows, where each element corresponds to one
# binned actuator, with coordinates indicated as
# < i j  x  y >:
#
# < 0 0 0.5 0.5>
# < 0 2 0.5 2.5>
# < 0 4 0.5 4.5>
# <   etc.     >
#
# Before executing this procedure, global variables must be declared.
#
# called by:  wish shell (wavescope expert mode)
#
#---------------------------------------------------------------------------
proc testStub { } \
{
   global gActuatorPositionV4
   global gFirstTestActuatorPositionV4
   global gSecondTestActuatorPositionV4
   global gModalControlNumberOfActuatorsPerBin

   global XACT_LINE_LENGTH
   global YACT_LINE_LENGTH

   a.make "<1 5 1.5 5.5>" = gFirstTestActuatorPositionV4
   a.make "<2 4 2.5 4.5>" = gSecondTestActuatorPositionV4
   set gModalControlNumberOfActuatorsPerBin 4
   set XACT_LINE_LENGTH  6
   set YACT_LINE_LENGTH  6


}






#---------------------------------------------------------------------------
# displayActuatorGridAndWavefront
#
# displays the current actuator grid superimposed on an image of the
# wavefront taken with the wavescope device.  Used to validate the
# computed actuator positions from the semi-auto training method.
#
# called by: displayValidateTrainingPanel
#
# 6/6/2005
#---------------------------------------------------------------------------
proc displayActuatorGridAndWavefront { } \
{
    global ACTUATORGRIDANDWAVEFRONT_ID
    global gActuatorPositionV4

    global wlCalibrate stagePos Grad


    #DEBUG
    #dialog "Debug Pause Here"

    if { $wlCalibrate(doneInit) != "Yes" } {
	dialog "Please Calibrate WaveScope."
	return
    }
    stage.calibrate.absolute $stagePos(BestRefSpots)

    # set image display window, parameters
    id.new ACTUATORGRIDANDWAVEFRONT_ID
    id.set.title ACTUATORGRIDANDWAVEFRONT_ID "Wavefront. East is Up.  North is Right."
    id.set.wh ACTUATORGRIDANDWAVEFRONT_ID 350 350
    id.set.xy ACTUATORGRIDANDWAVEFRONT_ID 100 100



    # display a wavefront for comparison.
    if { $wlCalibrate(doneInit) != "Yes" } {
	dialog "Please Calibrate WaveScope."
	return
    } else {

        #==============================================
        # Get gradient data from wavescope, reconstruct
        # wavefront and display on console.
        #==============================================

        updateActuatorGridAndWavefrontDisplay

        #==============================================
        # extract, display current actuator positions
        #==============================================

        a.v4tov2v2 $gActuatorPositionV4 = theIJV2 theXYV2

        set theRectWidth 0.2
        set theRectHeight $theRectWidth
        set theHalfWidth [expr $theRectWidth/2 ]
        set theHalfHeight [expr $theRectHeight/2 ]


        
        a.copy theXYV2 = theSubTermV2
        a.v2toxy theSubTermV2 = theSubX theSubY
        a.set theSubX $theHalfWidth = theSubX
        a.set theSubY $theHalfHeight = theSubY
        a.xytov2 theSubX theSubY = theSubTermV2

        a.sub theXYV2 theSubTermV2 = theXYLowerLeftV2

        a.copy theXYV2 = theWHV2
        a.v2toxy theWHV2 = theW theH
        a.set theW $theRectWidth = theW
        a.set theH $theRectHeight = theH
        a.xytov2 theW theH = theWHV2
        a.v2v2tov4 theXYLowerLeftV2 theWHV2 = theGridRectV4
        id.set.rect.array ACTUATORGRIDANDWAVEFRONT_ID theGridRectV4



        #DEBUG
        # place a rectangle on the image display
        # set theXL 30
        # set theYL 0
        # set theW 1
        # set theH 1
        # set theV4Element "<$theXL $theYL $theW $theH>"
        # a.make $theV4Element = theRectV4
        # id.set.rect.array ACTUATORGRIDANDWAVEFRONT_ID theRectV4


        #DEBUG
        puts stdout "[a.dump theGridRectV4]"
    }

    #id.exit ACTUATORGRIDANDWAVEFRONT_ID


}





#---------------------------------------------------------------------------
# pokeBinnedActuator                   NOT CURRENTLY IN USE
#
# Applies a voltage to a specified binned actuator.
#
# called by:
#
# COMPLETED.  NEEDS DEBUGGING
#
# 6/23/2005
#---------------------------------------------------------------------------
proc pokeBinnedActuator { inI inJ } \
{

    global gModalControlNumberOfActuatorsPerBin
    global gActuatorPositionV4
    global gNAPerSide
    global ACTUATORGRIDANDWAVEFRONT_ID

    global Grad gvd CurDrv Drvs Grds MAX_ACT maskArray pokeFraction
    global wlCalibrate YACT_LINE_LENGTH XACT_LINE_LENGTH stagePos


    upvar $inI theI
    upvar $inJ theJ
    
    #DEBUG
    puts stdout "pokeBinnedActuator:  inI = $inI"
    

    # make some arrays of zeros to use to fill matrices
    # when we reach dead actuators
    set nsubs [a.cols wlCalibrate(FinalCenters)]
    a.make 0 $MAX_ACT = zeros
    a.make "< 0 0 >" $nsubs = gzeros

    # Poke each actuator from 0..1, and calculate the gradient.
    #
    # FlatDM
    a.copy CurDrv = CurDrv0


   # for N X N binning of actuators
   # theNumberOfActuatorsPerBin = N*N
   set theNumberOfActuatorsPerBin [expr $gNAPerSide * $gNAPerSide]

   #DEBUG
   #puts stdout "theNumberOfActuatorsPerBin = $theNumberOfActuatorsPerBin"

   set theIBinWidth [expr int(sqrt($theNumberOfActuatorsPerBin))]
   set theJBinWidth [expr int(sqrt($theNumberOfActuatorsPerBin))]

   # assume square bins for computing the row, column ranges below
   set theN $theIBinWidth

   # set the relative row, column ranges for the NxN bin
   # this code will produce the following (e.g.)
   # # actuators   binning    Bx_lo   Bx_hi
   # -----------   -------    -----   -----
   #      4          2x2         0       1
   #      9          3x3        -1       1
   #     25          5x5        -2       2
   #    256         16x16       -7       8
   #    512         32x32       -15     16

   set theNisEven [expr int(1 - fmod($theN,2))]
   set Bi_lo [expr -1*int($theN/2) + $theNisEven]
   set Bi_hi [expr int($theN/2)]
   set Bj_lo [expr -1*int($theN/2) + $theNisEven]
   set Bj_hi [expr int($theN/2)]



   set i $theI
   set j $theJ


   # array for storing preliminary desired deflection data
   a.make 0 $MAX_ACT = CD


   #DEBUG
   puts stdout "pokeBinnedActuator: i=$i j=$j"

   # loop over actuators in each bin.  Limits are determined by
   # the type of binning, defined above.
   for { set Bi $Bi_lo } { $Bi <= $Bi_hi } { incr Bi } {
        for { set Bj $Bj_lo } { $Bj <= $Bj_hi} { incr Bj } {


                set Bi_abs [expr $Bi + $i]
                set Bj_abs [expr $Bj + $j]

                # Harold Dysons integer index number of the actuator
                set theHDActuatorIndex \
                     [expr $Bi_abs*$XACT_LINE_LENGTH +$Bj_abs]

                # if current actuator is within the active area
                # of the array ...
                if { $Bi_abs >= 0 && $Bi_abs < $XACT_LINE_LENGTH } {
                   if { $Bj_abs >= 0 && $Bj_abs < $YACT_LINE_LENGTH } {

                        # ...and if the actuator is not masked ...
                        if { [ a.extele maskArray $theHDActuatorIndex ] == 1 } {

                             # ...set the corresponding element of
                             # the CD (curvature drive) array to the
                             # value $pokeFraction.  This actuator
                             # will then have a voltage applied to
                             # it (below).


                             # ... then update CD array
                             a.repele $pokeFraction CD $theHDActuatorIndex = CD


                        } else {
                             # ...else the actutor is masked

                             #DEBUG
                             #puts "Skipping masked actuator: $j x $i"

                             # why set CD array to zero below?
                             # this line commented out.
                             # plk 12/17/2004
                             #a.copy zeros = CD

                             a.v2v2tov4 wlCalibrate(FinalCenters) gzeros = Grad
                        }
                   }
                }
        }
   }

   # ignore previous entries in CurDrv
   # ( i.e. ignore CurDrv0 )
   #a.add CD CurDrv0 = CurDrv

   a.copy CD = CurDrv

   # ... update the GUI display
   #SetGUIActs $CurDrv

   # ... convert CurDrv to voltage
   ftov $CurDrv uuu


   # ... send voltages to the hardware
   dm.send uuu
   update


   updateActuatorGridAndWavefrontDisplay


}


#---------------------------------------------------------------------------
# updateActuatorGridAndWavefrontDisplay
#
# Get gradient data from wavescope, reconstruct
# wavefront and display on console.
#
# called by:  pokeBinnedActuator
#
#
#
# 6/7/2005
#---------------------------------------------------------------------------
proc updateActuatorGridAndWavefrontDisplay { } \
{
  global ACTUATORGRIDANDWAVEFRONT_ID
  global wlCalibrate stagePos Grad



  # grab 10 wavefronts, for display...avg. gradients
  # stored in global variable Grad
  calcGrad 10

  stage.calibrate.absolute $stagePos(BestRefSpots)
  a.v4tov2v2 $Grad = theXYPosV2 theGradV2

  # create a regular 2D output gradient array and weight mask
  alg.conv.pg.arrays $Grad $wlCalibrate(Params) = theGxGyV2 theMaskArray

  # reconstruct the wavefront from gradient, mask data.  Output is
  # 2D array of floating point values.
  alg.recon.fast theGxGyV2 theMaskArray = theWavefrontSurfaceF

  id.set.array ACTUATORGRIDANDWAVEFRONT_ID theWavefrontSurfaceF

}







#---------------------------------------------------------------------------
# proc calibrateDMForModalControl        PROCEDURE NOT CURRENTLY IN USE
#
# Manual DM Training procedure.  "Poke" each actuator, ask user to identify
# the peak position on the wavescope image display, store the peak positions
# of each actuator in global V4 array.
#
# called by:  displayModalControlPanel
#---------------------------------------------------------------------------
proc calibrateDMForModalControl {} {

    global FINDPEAK_ID
    global gCalibrateDMForModalControlFlag

    global loopType wlCalibrate stagePos



    #DEBUG
    #dialog "Debug Pause Here"

    if { $wlCalibrate(doneInit) != "Yes" } {
	dialog "Please Calibrate WaveScope."
	return
    }
    stage.calibrate.absolute $stagePos(BestRefSpots)

    # set image display for the findpeak window, used in
    # findPeakInteractive procedure.  Initialize ID window
    # and place it on the display.
    id.new FINDPEAK_ID
    id.set.title FINDPEAK_ID "Wavefront. East is Up"
    id.set.wh FINDPEAK_ID 350 350
    id.set.xy FINDPEAK_ID 400 100

    pokeBinnedActuators_CalibrateModalControl
    set gCalibrateDMForModalControlFlag 1

    id.exit FINDPEAK_ID
}




#------------------------------------------------------------------------
# pokeBinnedActuators_CalibrateModalControl
#
# Pokes each actuator bin, according to a prescribed binning scheme
# and records the gradients (no noise).  This procedure populates the
# Grds array, which contains wavefront gradient information corresponding
# to each "poke" of a (possibly binned) electrode influence function.
#
# For each "poke" of device, this procedure calculates the x,y position
# of the minimum of the wavefront, and stores this position as the
# coordinates of the binned electrode.
#
# Based on pokeBinnedActuators_quiet{}
#
# These global variables must be set before calling procedure:
#
#       gNumberOfActuatorsPerBin
#
# Output of this procedure:
#
#       Grds                    array of v4 wavefront gradients; one row
#                               per electrode influence function
#
#       gActuatorPositionV4     array of v4 actuator center x,y positions
#                               determined from poke procedure.
#                               array elements are < i j x y > where
#                               i,j is the electrode array row, column
#                               of the binned actuator center.
#
#
# Called by:  calibrateDMForModalControl
#
#
# plk 05/12/2005
#------------------------------------------------------------------------
proc pokeBinnedActuators_CalibrateModalControl { } {

    global gNAPerSide
    global gModalControlNumberOfActuatorsPerBin
    global gActuatorPositionV4

    global Grad gvd CurDrv Drvs Grds MAX_ACT maskArray pokeFraction
    global wlCalibrate YACT_LINE_LENGTH XACT_LINE_LENGTH



    # Display gradients while we work.
    #
    vd.new gvd
    vd.set.title gvd "Measured Gradient"
    vd.set.xy gvd 50 50
    vd.set.wh gvd 300 300


    #set, initialize array of actuator center positions
    a.make "<-1 2>" 1 1 = theActuatorPositionV2
    a.make "<-1 2>" 1 1 = theIJV2
    a.make "<-1 2>" 1 1 = theTempV2


    # make some arrays of zeros to use to fill matrices
    # when we reach dead actuators
    set nsubs [a.cols wlCalibrate(FinalCenters)]
    a.make 0 $MAX_ACT = zeros
    a.make "< 0 0 >" $nsubs = gzeros

    # Poke each actuator from 0..1, and calculate the gradient.
    #
    FlatDM
    a.copy CurDrv = CurDrv0

   # set the parameters for the binning of actuators based on
   # the number of actuators per bin.
   #
   # why is this a global variable?
   set gModalControlNumberOfActuatorsPerBin [expr $gNAPerSide * $gNAPerSide]

   # for N X N binning of actuators
   # theNumberOfActuatorsPerBin = N*N
   set theNumberOfActuatorsPerBin $gModalControlNumberOfActuatorsPerBin

   #DEBUG
   puts stdout "theNumberOfActuatorsPerBin = $theNumberOfActuatorsPerBin"

   set theIBinWidth [expr int(sqrt($theNumberOfActuatorsPerBin))]
   set theJBinWidth [expr int(sqrt($theNumberOfActuatorsPerBin))]

   # assume square bins for computing the row, column ranges below
   set theN $theIBinWidth

   # set the relative row, column ranges for the NxN bin
   # this code will produce the following (e.g.)
   # # actuators   binning    Bx_lo   Bx_hi
   # -----------   -------    -----   -----
   #      4          2x2         0       1
   #      9          3x3        -1       1
   #     25          5x5        -2       2
   #    256         16x16       -7       8
   #    512         32x32       -15     16

   set theNisEven [expr int(1 - fmod($theN,2))]
   set Bi_lo [expr -1*int($theN/2) + $theNisEven]
   set Bi_hi [expr int($theN/2)]
   set Bj_lo [expr -1*int($theN/2) + $theNisEven]
   set Bj_hi [expr int($theN/2)]


   set theNumberOfBinnedActuators 1


   # loop over the actuators in the array, modulo binning
   # i,j determines actuator at the bin center (odd binning) or
   # the actuator to the immediate "lower left" of bin center (even binning).
   for { set i 0 } { $i < $XACT_LINE_LENGTH } { incr i $theIBinWidth } {
        for { set j 0 } { $j < $YACT_LINE_LENGTH } { incr j $theJBinWidth } {

             # array for storing preliminary desired deflection data
             a.make 0 $MAX_ACT = CD

             # set Grad array.  This step may not be necessary for computations
             # below, but Grad must be defined on first pass through the
             # for loops
             vd.new Grad
             update
             calcGrad 10
             vd.set.array gvd Grad

             #DEBUG
             puts stdout "pokeBinnedActuators_TrainModalControl: Binned Actuator: i=$i j=$j"

             # loop over actuators in each bin.  Limits are determined by
             # the type of binning, defined above.
             for { set Bi $Bi_lo } { $Bi <= $Bi_hi } { incr Bi } {
                  for { set Bj $Bj_lo } { $Bj <= $Bj_hi} { incr Bj } {

                       # absolute i,j values of the current actuator
                       set Bi_abs [expr $Bi + $i]
                       set Bj_abs [expr $Bj + $j]

                       # Harold Dysons integer index number of the actuator
                       set theHDActuatorIndex \
                                [expr $Bi_abs*$XACT_LINE_LENGTH +$Bj_abs]

                       # if current actuator is within the active area
                       # of the array ...
                       if { $Bi_abs >= 0 && $Bi_abs < $XACT_LINE_LENGTH } {
                            if { $Bj_abs >= 0 && $Bj_abs < $YACT_LINE_LENGTH } {

                                 # ...and if the actuator is not masked ...
                                 if { [ a.extele maskArray $theHDActuatorIndex ] == 1 } {

                                      # ...set the corresponding element of
                                      # the CD (curvature drive) array to the
                                      # value $pokeFraction.  This actuator
                                      # will then have a voltage applied to
                                      # it (below).

                                      # DEBUG
                                      #puts stdout \
                                      #   "\t Bi=$Bi Bj=$Bj Index $theHDActuatorIndex"

                                      # ... then update CD array
                                      a.repele $pokeFraction CD $theHDActuatorIndex = CD


                                 } else {
                                      # ...else the actutor is masked

                                      #DEBUG
                                      #puts "Skipping masked actuator: $j x $i"

                                      # why set CD array to zero below?
                                      # this line commented out.
                                      # plk 12/17/2004
                                      #a.copy zeros = CD

                                      a.v2v2tov4 wlCalibrate(FinalCenters) gzeros = Grad
                                 }
                            }
                       }
                  }
             }

             a.add CD CurDrv0 = CurDrv


             # ... update the GUI display
             SetGUIActs $CurDrv

             # ... convert CurDrv to voltage
             ftov $CurDrv uuu


             # ... send voltages to the hardware
             dm.send uuu
             update

             # calculate gradient by grabbing 10 images; result
             # is stored in global variable Grad
             calcGrad 10


             # find the x,y coordinates of the influence function
             # peak centers.  Grad is an array of v4 vectors
             # (x,y, dphi/dx, dphi/dy) containing wavefront data
             getWFReconInflFuncPeakPosition Grad theXYv2


             # insert 500 ms wait time here for membrane to settle.
             # set voltages to zero.  Wait for membrane to settle once more.
             after 500
             setzero
             after 500

             vd.set.array gvd Grad


             # store current binned actuator i,j values
             # as v2 array, for combinining into global
             # v4 array ...
             a.make 0.0 1 = theIA
             a.make 0.0 1 = theJA

             a.repele $i theIA 0 = theIA
             a.repele $j theJA 0 = theJA
             a.xytov2 theIA theJA = theIJV2

             # DEBUG
             puts stdout "[a.info theIJV2]"
             puts stdout "[a.info theXYv2]"

             # populate the gActuatorPositionV4 array current row element
             # with the x,y positions of the current actuator.
             if { $theNumberOfBinnedActuators == 1 }\
             {
                  a.copy CD = Drvs
                  a.copy Grad = Grds

                  a.v2v2tov4 theIJV2 theXYv2 = gActuatorPositionV4

             } else \
             {
                  a.catrow Drvs CD = Drvs
                  a.catrow Grds Grad = Grds
                  a.v2v2tov4 theIJV2 theXYv2 = theTempV4
                  a.catrow gActuatorPositionV4 theTempV4 = gActuatorPositionV4
             }

             incr theNumberOfBinnedActuators

             update
        }
   }

   a.make 0 $MAX_ACT = CurDrv

   # alternately, compute actuator positions here.  Operate on Grds
   # array one row at a time and compute x,y position of each row.
   # However, if done here, there will be no opportunity for visual
   # feedback on the CRT display.

   # Uncomment these next two lines to save the
   # calculated drive signal and gradients to disk.
   #
   a.saveasc Drvs Drvs
   a.saveasc Grds Grds

   set gvd 0

}







#---------------------------------------------------------------------------
# getV4GradientEqZeroPosition
#
# Finds the minimum of the absolute value of the gradient of a v4 (gradient)
# array, and returns the x,y coordinates of this minimum
#
# input parameter:    inGrad      column vector of v4 elements where
#                                 each element is of the form
#                                 < x , y, dphi/dx , dphi/dy >
#
#
#
# output parameter:  outXYV2      v2 array specifying the x,y coordinates
#                                 of the position where
#                                 abs( (dphi/dx)^2 + (dphi/dy)^2 )
#                                 is a minimum.
#
#   NOTE:  output parameter does not need to be defined before executing
#          this procedure.
#
# called by: pokeBinnedActuators_TrainModalControl
#
# PROCEDURE COMPLETED BUT NEEDS TESTING/DEBUGGING
# plk 5/12/2005
#---------------------------------------------------------------------------
proc getV4GradientEqZeroPosition { inGradV4 outXYV2 } {

   upvar $inGradV4 theGradV4
   upvar $outXYV2 theXYV2

   a.v4tov2v2 $theGradV4 = theXYPosV2 theGradV2

   set theTestNorm 0

   a.min theGradV2 = theMinNorm
   a.v2toxy theMinNorm = theMNX theMNY
   a.mul theMNX theMNX = theMNX2
   a.mul theMNY theMNY = theMNY2
   a.add theMNX2 theMNY2 = theMN2
   a.sqrt theMN2 = theMinNorm

   set theCurrentElementIndex 0
   set theMinElementIndex 0


   # NOTE:  procedure assumes that input array is a column vector
   # here.  If input array is a row vector then replace a.cols with
   # a.rows below (only one replacement reqd.)
   a.cols theGradV4 = theNumA
   set theNumElements [a.dump theNumA]

   #DEBUG
   #puts "theMinNorm = [a.dump $theMinNorm]"

   # search Grad array for index value of element with minimum
   # Euclidean norm
   for { set i 0 } { $i < $theNumElements } { incr i } {


        a.extele theGradV2 $i = theTestElementV2
        a.v2toxy theTestElementV2 = theXTest theYTest
        a.mul theXTest theXTest = theX2Test
        a.mul theYTest theYTest = theY2Test
        a.add theX2Test theY2Test = theNorm2Test
        a.sqrt theNorm2Test = theTestNorm


        #DEBUG
        #puts stdout "theTestNorm = [a.dump $theTestNorm]"


        if { [a.dump theTestNorm] == [a.dump theMinNorm] } {

                set theMinElementIndex $theCurrentElementIndex

                # DEBUG
                #puts stdout "theMinElementIndex = $theMinElementIndex"

                break
        }
        incr theCurrentElementIndex
   }

   # extract the position of the corresponding minimum of the
   # gradient from the position array.  Gradient and XY positions
   # have the same indexing because they came from the same V4 array
   a.extele theXYPosV2 $theMinElementIndex = theXYV2

   #DEBUG
   puts stdout "getV4GradientEqZeroPosition:"
   puts stdout "[a.dump theXYV2]"

}
