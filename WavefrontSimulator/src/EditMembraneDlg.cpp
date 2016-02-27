//---------------------------------------------------------------------
#include <vcl.h>
#pragma hdrstop

#include "EditMembraneDlg.h"
//--------------------------------------------------------------------- 
#pragma resource "*.dfm"
TEditMembraneDialog *EditMembraneDialog;
//---------------------------------------------------------------------
__fastcall TEditMembraneDialog::TEditMembraneDialog(TComponent* AOwner)
	: TForm(AOwner)
{
}
//---------------------------------------------------------------------


//---------------------------------------------------------------------
// Execute()
//
// Executes the Dialog box, and sets component data values to their
// user-updated values, if the user clicks "OK."   Frees the dialog
// box after the user closes it.
//
// called by:  TWavefrontGUIForm::EditMembraneExecute(TObject *Sender)
//
//---------------------------------------------------------------------
bool __fastcall TEditMembraneDialog::Execute()
{
   EditMembraneDialog = new TEditMembraneDialog(Application);
   bool Result;

   try
   {
      EditMembraneDialog->MembraneStressEditBox->Text =
         WavefrontGUIForm->theMembraneStress_MPa;
      EditMembraneDialog->MembraneThicknessEditBox->Text =
         WavefrontGUIForm->theMembraneThickness_um;
      EditMembraneDialog->MembraneGapDistanceEditBox->Text =
         WavefrontGUIForm->theMembraneGapDistance_um;

      EditMembraneDialog->MembraneTopElectrode_VEditBox->Text =
         WavefrontGUIForm->theMembraneTopElectrode_V;

      EditMembraneDialog->MembraneTopElectrodeGapDistanceEditBox->Text =
         WavefrontGUIForm->theMembraneTopElectrodeDistance_um;

      Result = (EditMembraneDialog->ShowModal() == IDOK );

      WavefrontGUIForm->theMembraneStress_MPa        =
         EditMembraneDialog->MembraneStressEditBox->Text.ToDouble();
      WavefrontGUIForm->theMembraneThickness_um =
         EditMembraneDialog->MembraneThicknessEditBox->Text.ToDouble();
      WavefrontGUIForm->theMembraneGapDistance_um  =
         EditMembraneDialog->MembraneGapDistanceEditBox->Text.ToDouble();
      WavefrontGUIForm->theMembraneTopElectrode_V =
         EditMembraneDialog->MembraneTopElectrode_VEditBox->Text.ToDouble();
      WavefrontGUIForm->theMembraneTopElectrodeDistance_um =
         EditMembraneDialog->MembraneTopElectrodeGapDistanceEditBox->
         Text.ToDouble();

   }
   catch(...)
   {
      Result = false;
   }
   EditMembraneDialog->Free();

   return Result;
}

