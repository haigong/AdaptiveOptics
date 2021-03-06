//----------------------------------------------------------------------------
#include <vcl.h>
#pragma hdrstop

#include "ZCoeffTable.h"
#include "ZCoeffDataModule.h"
#include "AberratedWavefront.h"  // for NUMBEROFZERNIKES

//----------------------------------------------------------------------------
#pragma resource "*.dfm"
TZCoeffTableForm *ZCoeffTableForm;
//----------------------------------------------------------------------------
__fastcall TZCoeffTableForm::TZCoeffTableForm(TComponent *Owner)
	: TForm(Owner)
{
}


//---------------------------------------------------------------------------
// ReadDataFromFile()
//
// Reads in data from the Table into array for use with the
// Wavefront simulator.
//
// called by:  TZernikeCoeffDataModule::ZCoeffTableBeforeClose()
//             TZernikeCoeffDataModule::DataModuleCreate()
//
//---------------------------------------------------------------------------
void TZCoeffTableForm::ReadDataFromFile()
{

   int theNumRecords = ZernikeCoeffDataModule->ZCoeffTable->RecordCount;

   // Number of records in data file should be the same as
   // the number of data rows.
   // NUMBEROFZERNIKES is defined in AberratedWavefront.h
   if (theNumRecords != NUMBEROFZERNIKES)
   {
      WavefrontGUIForm->Memo1->Lines->Add("Error reading Zernikes file:");
      WavefrontGUIForm->Memo1->Lines->Add("Wrong number of data rows");
      return;
   }
   else
   {
      // rewind to make sure you're starting from the
      // beginning of the data file

      ZernikeCoeffDataModule->ZCoeffTable->First();
      for (int i=0;i<NUMBEROFZERNIKES;i++)
      {
        WavefrontGUIForm->theAberrationCoeff[i] =
           ZernikeCoeffDataModule->ZCoeffTable->FieldValues["COEFFICIEN"];
        ZernikeCoeffDataModule->ZCoeffTable->Next();

      }
      AnsiString theGoodNews;
      theGoodNews.sprintf("Entered %d Zernike coefficients from file:",
                theNumRecords);
      WavefrontGUIForm->Memo1->Lines->Add(theGoodNews);

      WavefrontGUIForm->Memo1->Lines->
                Add(ZernikeCoeffDataModule->ZCoeffTable->DatabaseName);
      WavefrontGUIForm->Memo1->Lines->
                Add(ZernikeCoeffDataModule->ZCoeffTable->TableName);
      WavefrontGUIForm->Memo1->Lines->Add(" ");

   }

   // rewind so that user is not looking at the
   // tail of the data set next time...
   ZernikeCoeffDataModule->ZCoeffTable->First();


}
