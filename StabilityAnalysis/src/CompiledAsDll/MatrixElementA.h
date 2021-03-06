//---------------------------------------------------------------------------
// MatrixElementA.h                                  C Program file
//
// methods for a MatrixElementA class implementation.
//
// called by:
// plk 03/08/2005
//---------------------------------------------------------------------------
#ifndef MATRIXELEMENTA_H
#define MATRIXELEMENTA_H

int gMatrixAActiveRow;
int gMatrixAActiveCol;

//double RealMatrixElementA(int inJRow, int inJCol);
double RealMatrixElementA();

double AIntegrandRF(double inR);
double WeightFn(double inR);

void dump(double (*inFunc)(double),double inRL,double inRH, double inNum);
#endif
