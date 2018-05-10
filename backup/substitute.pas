unit substitute;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls;

type

  { TForm2 }

  TForm2 = class(TForm)
    btnOk: TButton;
    btnCancel: TButton;
    EdPrice: TEdit;
    Edit2: TEdit;
    Edit3: TEdit;
    edQty: TEdit;
    Edit5: TEdit;
    Edit6: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Panel1: TPanel;
    procedure btnCancelClick(Sender: TObject);
    procedure btnOkClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
  private

  public

  end;

var
  Form2: TForm2;

implementation

uses ProtoMpMain;

{$R *.lfm}

{ TForm2 }

procedure TForm2.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  CloseAction := caFree;
end;

procedure TForm2.FormCreate(Sender: TObject);
begin
  Left := Mouse.CursorPos.X;
  Top  := Mouse.CursorPos.Y - Form2.Height div 2;
end;

procedure TForm2.btnOkClick(Sender: TObject);
var
  p_RecordCount, p_RecNo: Integer;
  p_Price, p_OldPrice, p_percent, p_diff: Real;
  p_TextPrice, p_qty: String;
  p_PostFund, p_DeleteItems: Boolean;
  p_iqty, p_diffqty, p_OldQty: Integer;
  p_fundDate, p_fundTime, p_dod, p_reference: String;
begin
  p_percent := g_SubstitutionVarianceMultiplier;
  p_iqty    := 0;
  p_Price   := StrToFloatDef(EdPrice.Text, 0);

  with Form1.SdfItems do begin
     p_postfund  := FieldValues['postfund'];
     p_fundDate  := FieldValues['fundDate'];
     p_fundTime  := FieldValues['fundTime'];
     p_dod       := FieldValues['dod'];
     p_OldQty    := StrToIntDef(FieldValues['qty'], 0);
  end;

  if p_Price = 0 then begin
     ShowMessage('Please Provide Item Price!');
     Exit;
  end;

  with Form1.SdfItems do begin
     p_iqty := StrToIntDef(edQty.Text, 0);
     if p_iqty > StrToIntDef(FieldValues['qty'],1) then begin
        ShowMessage('Substitution Quantity Exceeded!');
        Exit;
     end;
     if p_iqty <= 0  then begin
        ShowMessage('Invalid Substitution Quantity!');
        Exit;
     end;
  end;

  p_TextPrice := Form1.SdfItems.FieldValues['price'];
  p_OldPrice  := StrToFloatDef(p_TextPrice, 0);
  p_diff      := p_OldPrice * p_percent;
  p_PostFund  := Form1.SdfItems.FieldValues['postFund'];

  if p_price > (p_OldPrice + p_diff) then begin
     ShowMessage('Substitution Price Exceeded!');
     Exit;
  end;

  if p_price < g_MinimumLeaseAmount then begin
     ShowMessage('Price is Below Minimum Lease Amount!');
     Exit;
  end;

  with Form1.SdfItems do begin
    p_diffqty :=  StrToIntDef(FieldValues['qty'],1) - p_iqty;

    Edit;
    p_RecNo := RecNo;
    if StrToIntDef(FieldValues['qty'],1) = p_iqty then
       if not Empty(FieldValues['dod']) then
          FieldValues['status'] := 'Returned'
       else
         FieldValues['status'] := 'Cancelled';

    if p_diffqty <> 0 then begin
       FieldValues['qty']   := IntToStr(p_diffqty);
       FieldValues['total'] := FormatFloat('######0.00', p_OldPrice * p_diffqty);
    end;
    Post;
    if p_price <> p_OldPrice then
       LogJournal('Substituted', IntToStr(p_OldQty - p_diffqty), -(p_OldQty - p_diffqty) * p_OldPrice);
  end;
  Decision;

//AddTrigger('001 Stop & Void Payment Schedule');
  if p_price <> p_OldPrice then
     AddTrigger('001 Generate New Payment Schedule');

  if p_price = p_OldPrice then
     AddTrigger('001 Record Same Price Item Change');

  AddTrigger('001 Notify(email, sms) Customer of Change');

  with Form1.SdfLeases do begin;
    if p_price <> p_OldPrice then begin
       p_reference := FieldValues['lease'];
       if g_OpenLease = '' then begin
          Append;
          g_OpenLease           := IntToStr(RecordCount+1);
          FieldValues['lease']  := IntToStr(RecordCount+1);
          FieldValues['status'] := 'Incomplete';
          Post;
          p_DeleteItems := True;
          CopyFile(g_path_of_data + 'items1.csv', g_path_of_data + 'items' + FieldValues['lease'] + '.csv', False, True);
       end
       else begin
           // Find the Open Lease //
           with Form1.SDFLeases do begin
               while not Eof do begin
                 if FieldValues['lease'] = g_OpenLease then
                    Break;
                 Next;
               end;
           end;
       end;
    end;
    Form1.SdfItems.Append;
    Form1.SdfItems.FieldValues['lease']     := p_reference;
    Form1.SdfItems.FieldValues['item']      := IntToStr(Form1.SdfItems.RecordCount + 1);
    Form1.SdfItems.FieldValues['status']    := 'Substituted';
    if p_price <> p_OldPrice then
       Form1.SdfItems.FieldValues['reference'] := IntToStr(RecordCount);
    Form1.SdfItems.FieldValues['qty']       := IntToStr(p_iqty);
    Form1.SdfItems.FieldValues['price']     := FormatFloat('######0.00', p_Price);
    Form1.SdfItems.FieldValues['total']     := FormatFloat('######0.00', p_Price * p_iqty);
    Form1.SdfItems.FieldValues['postfund']  := False;
    Form1.SdfItems.FieldValues['fundDate']  := ' ';
    Form1.SdfItems.FieldValues['fundTime']  := ' ';
    Form1.SdfItems.FieldValues['dod']       := NotEmpty(p_dod);
    Form1.SdfItems.FieldValues['batch']     := ' ';
    Form1.SdfItems.Post;
    if p_price = p_OldPrice then begin
       Form2.Close;
       Exit;
    end;
    Form1.DBGridLeasesCellClick(Nil);
  end;

  Form1.MemoTrigger.Clear;
  AddTrigger('006 Create New Lease');
  AddTrigger('006 Notify(email, sms) Customer to Sign New Lease');

  if p_DeleteItems then begin
     Truncate(Form1.SdfItems);
     p_DeleteItems := False;
  end;

  with Form1.SdfItems do begin
    p_RecordCount := RecordCount + 1;
    Append;
    FieldValues['lease']     := Form1.SdfLeases.FieldValues['lease'];
    FieldValues['item']      := IntToStr(p_RecordCount);
    FieldValues['status']    := 'Open';
    FieldValues['qty']       := IntToStr(p_iqty);
    FieldValues['price']     := FormatFloat('######0.00', p_Price);
    FieldValues['total']     := FormatFloat('######0.00', p_Price * p_iqty);
    FieldValues['postfund']  := False;
    FieldValues['fundDate']  := ' ';
    FieldValues['fundTime']  := ' ';
    FieldValues['dod']       := NotEmpty(p_dod);
    FieldValues['batch']     := ' ';
    FieldValues['reference'] := p_reference;
    Post;
  end;
  Close;
end;

procedure TForm2.btnCancelClick(Sender: TObject);
begin
  Close;
end;

end.

