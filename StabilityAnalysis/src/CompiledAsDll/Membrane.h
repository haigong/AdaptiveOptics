//---------------------------------------------------------------------------
// Membrane.h
//
//
// plk 03/07/2005
//---------------------------------------------------------------------------
#ifndef MEMBRANE_H
#define MEMBRANE_H


void Membrane();
void InitMembraneShapeCoeffs();
void SetMembraneShape_BesselJZero();
double ParabolicDeformation_MKS(double inR_MKS, double inArbitraryPhi);
double ExpansionInEFuncsDeformation_MKS(double inR_MKS, double inPhi_rad);
double Del2Expansion_MKS(double inR_MKS, double inPhi_Rad);
void TestMembraneExpansion(double inRL,double inRH, double inNum);
void TestMembraneShapeAtSelectedElectrodes();

#endif