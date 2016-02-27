//----------------------------------------------------------------------------
// ZOffsetZernikePolynomial.h                      C++ Header file
//
//----------------------------------------------------------------------------
#ifndef ZOFFSETZERNIKEPOLYNOMIAL_H
#define ZOFFSETZERNIKEPOLYNOMIAL_H

#include "ZernikePolynomial.h"

class ZOffsetZernikePolynomial : public ZernikePolynomial
{
  private:

        double ZOffset_um;

  public:

  ZOffsetZernikePolynomial();
  ~ZOffsetZernikePolynomial();


  void   SetOffset(double inOffset_um) {ZOffset_um = inOffset_um;}

  double Evaluate(const double inR);
  double Evaluate(const double inR, const double inTheta);



};


extern ZOffsetZernikePolynomial *theZOffsetZernike;

#endif
 