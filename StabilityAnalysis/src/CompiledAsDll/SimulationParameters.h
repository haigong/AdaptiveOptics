//---------------------------------------------------------------------------
// SimulationParameters.h
//
// Initialize simulation parameters:  global variables defined in
// Membrane.h, MatrixA.h, Eigenfunc.h
//
//---------------------------------------------------------------------------
#ifndef SIMULATIONPARAMETERS_H
#define SIMULATIONPARAMETERS_H


// the following variables are defined with extern
// keyword:  Technically, this should not be necessary,
// but for the following identifiers, it is.  Without
// extern keyword, there will be linkage problems galore.
// Bug in Borland 5.0 compiler?
//
// plk 3/18/2005

// Used in Membrane.c

extern double gMembraneStress_MPa;
extern double gMembraneThickness_um;
extern double gMembraneTension_NByM;      // tension = stress * thickness
extern double gMembraneRadius_mm;
extern double gVoltageT_V;    // Transp. electrode voltage
extern double gVoltageA_V;    // Array electrode voltage
extern double gDistT_um;      // Transp. electr -- membr. dist.
extern double gDistA_um;      // Electr. array -- membr. dist.
extern double gPeakDeformation_um;


// Used in MatrixA.c

extern double gEPS;  //fractional accuracy of integration


// Used in Eigenfunc.c

extern int gNumberOfEigenFunctions;


// Used in ElectrodeArray.c

// defining these variables as extern will cause linkage problems.
// Bug in Borland 5.0 compiler?
// plk 3/18/2005
float gElectrodeWidth_um;
float gElectrodeSpc_um;
int gNumElectrodes;

char gLogFileName[] = "LogFile.txt";

//double (*gMembraneShape)(double inR_MKS);

void InitSimParameters();


#endif
