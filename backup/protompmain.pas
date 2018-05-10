unit ProtoMpMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SdfData, db, FileUtil, Forms, Controls, Graphics, Dialogs,
  StdCtrls, ExtCtrls, DBGrids, Menus, ExtDlgs, Substitute, Delivery, DateUtils;

type

  { TForm1 }

  TForm1 = class(TForm)
    btnClose: TButton;
    btnRefresh: TButton;
    btnDecision: TButton;
    btnFund: TButton;
    btnReset: TButton;
    btnDelete: TButton;
    btnQty: TButton;
    btnDeleteLease: TButton;
    btnApplyTriggers: TButton;
    btnSignLease: TButton;
    Calendar: TCalendarDialog;
    DBGridItems1: TDBGrid;
    DSJournal: TDataSource;
    DBGridLeases: TDBGrid;
    DSLeases: TDataSource;
    DSItems: TDataSource;
    DBGridItems: TDBGrid;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    GBJournal: TGroupBox;
    GBTriggers: TGroupBox;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    lblCurrentBatch: TLabel;
    lblExchange: TLabel;
    MemoTrigger: TMemo;
    MenuDeliverAll: TMenuItem;
    MenuItem1: TMenuItem;
    MenuOpen: TMenuItem;
    MenuDelivered: TMenuItem;
    MenuBackordered: TMenuItem;
    MenuReturned: TMenuItem;
    MenuSubstitute: TMenuItem;
    MenuCancelled: TMenuItem;
    MenuItem7: TMenuItem;
    MenuItem8: TMenuItem;
    Panel1: TPanel;
    Panel2: TPanel;
    Panel3: TPanel;
    PanelApplyTriggers: TPanel;
    PanelTop: TPanel;
    PopMenu: TPopupMenu;
    SdfJournal: TSdfDataSet;
    SdfLeases: TSdfDataSet;
    SdfItems: TSdfDataSet;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    Splitter3: TSplitter;
    procedure btnApplyTriggersClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure btnDecisionClick(Sender: TObject);
    procedure btnDeleteClick(Sender: TObject);
    procedure btnDeleteLeaseClick(Sender: TObject);
    procedure btnFundClick(Sender: TObject);
    procedure btnQtyClick(Sender: TObject);
    procedure btnRefreshClick(Sender: TObject);
    procedure btnResetClick(Sender: TObject);
    procedure btnSignLeaseClick(Sender: TObject);
    procedure DBGridItemsDblClick(Sender: TObject);
    procedure DBGridItemsMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure DBGridLeasesCellClick(Column: TColumn);
    procedure FormCreate(Sender: TObject);
    procedure MenuBackorderedClick(Sender: TObject);
    procedure MenuCancelledClick(Sender: TObject);
    procedure MenuDeliverAllClick(Sender: TObject);
    procedure MenuDeliveredClick(Sender: TObject);
    procedure MenuItem1Click(Sender: TObject);
    procedure MenuReturnedClick(Sender: TObject);
    procedure MenuOpenClick(Sender: TObject);
    procedure MenuSubstituteClick(Sender: TObject);
  private

  public

  end;

var
  Form1: TForm1;

  g_path_of_data: String = '/protodata/';
  g_OpenLease: String;
  g_MinimumLeaseAmount: Real = 55.00;
  g_SubstitutionVarianceMultiplier: Real = 0.15;
  g_TestEmployeeCode: String = '0001';

  // Erick's Path g_path_of_data: String = '/Users/Erick.Hernandez/Desktop/erick_h/Companies/F3EA/Brands/SkyFinancial/LeaseStatusPrototype/ProtoMP/';
  // Roman's Path g_path_of_data: String = 'C:\Users\Roman.Teller\Desktop\Cabinet\APROJECTS\ASF\ProtoMP\';

  procedure OpenItems;
  procedure Decision;
  procedure SetLeaseStatus(Stat: String);
  procedure LogJournal(aAction, aQty: String; aMount: Real);
  procedure SumJournal;
  procedure Truncate(DS: TSdfDataSet);
  procedure SaveTriggers;
  procedure AddTrigger(Str: String);

  function Empty(Str: String): Boolean;
  function FloatToDollar(Amt: Real): String;
  function NotEmpty(Str: String): String;
  function StrIn(Str, InStr: String): Boolean;
  function Allreturned: Boolean;

implementation

{$R *.lfm}

{ TForm1 }

function Allreturned: Boolean;
var
  p_AllReturned: Boolean;
begin
  p_AllReturned := True;
  with Form1 do begin
     SdfItems.First;
     while not SdfItems.Eof do begin
        if (SdfItems.FieldValues['status'] <> 'Returned') and (SdfItems.FieldValues['status'] <> 'Cancelled') and (SdfItems.FieldValues['status'] <> 'Substituted') then begin
           p_AllReturned := False;
           Break;
        end;
        SdfItems.Next;
     end;
  end;
  Result := p_AllReturned;
end;

function StrIn(Str, InStr: String): Boolean;
begin
  Result := POS(Str, InStr) > 0;
end;

procedure AddTrigger(Str: String);
begin
   Form1.MemoTrigger.Append(FormatDateTime('yyyy-mm-dd hh:mm:ss', now) + ' :: ' + Str);
   SaveTriggers;
   Form1.PanelApplyTriggers.Visible := True;
end;

procedure SaveTriggers;
var
   p_lease: String;
begin
   with Form1 do begin
      p_lease := SdfLeases.FieldValues['lease'];
      MemoTrigger.Lines.SaveToFile(g_path_of_data + 'Trigger' + p_lease + '.dat');
   end;
end;

procedure Truncate(DS: TSdfDataSet);
begin
  with DS do begin
     First;
     while not Eof do begin
        while not Eof do begin
           Delete;
           Next;
        end;
        First;
     end;
  end;
end;

procedure SumJournal;
begin
   LogJournal('','',0);
end;

procedure LogJournal(aAction, aQty: String; aMount: Real);
var
  p_tot: Real;
  p_batch: String;
begin
  p_batch := Form1.lblCurrentBatch.Caption;
  with Form1.SdfJournal do begin
     First;
     p_tot := 0;
     while not Eof do begin
        p_tot := p_tot + StrToFloatDef(FieldValues['amount'], 0);
        Next;
     end;
     Form1.lblExchange.Caption := FloatToDollar(p_tot);

     if Empty(Form1.SdfItems.FieldValues['fundDate']) then
        Exit;

     if not Empty(aAction) then begin
        Append;
        FieldValues['lease']  := Form1.SdfLeases.FieldValues['lease'];
        FieldValues['item']   := Form1.SdfItems.FieldValues['item'];
        FieldValues['action'] := aAction;
        FieldValues['qty']    := aQty;
        FieldValues['emp']    := g_TestEmployeeCode;
        FieldValues['date']   := FormatDateTime('mm/dd/yyyy', now);
        FieldValues['time']   := FormatDateTime('hh:mm:ss', now);
        FieldValues['amount'] := FloatToDollar(aMount);
        FieldValues['batch']  := p_batch;
        Post;
     end;

     First;
     p_tot := 0;
     while not Eof do begin
        p_tot := p_tot + StrToFloatDef(FieldValues['amount'], 0);
        Next;
     end;
     Form1.lblExchange.Caption := FloatToDollar(p_tot);
  end;
end;

function NotEmpty(Str: String): String;
begin
  if Empty(Str) then
     Result := ' '
  else
     Result := Str;
end;

function FloatToDollar(Amt: Real): String;
begin
  Result := FormatFloat('######0.00', Amt);
end;

function Empty(Str: String): Boolean;
begin
  result := Length(Trim(Str)) = 0;
end;

procedure SetLeaseStatus(Stat: String);
begin
  with Form1 do begin
    SdfLeases.Edit;
    SdfLeases.FieldValues['status'] := stat + '     ';
    SdfLeases.Post;
  end;
end;

procedure OpenItems;
var
  p_lease: String;
  p_new: Boolean;
begin
  with Form1 do begin
     p_lease := SdfLeases.FieldValues['lease'];

     SdfJournal.Close;
     SdfJournal.FileName := g_path_of_data + 'journal' + p_lease + '.csv';
     SdfJournal.Open;

     SdfItems.Close;
     p_new := False;
     if not FileExists(g_path_of_data + 'items' + p_lease + '.csv') then begin
        CopyFile(g_path_of_data + 'items.csv', g_path_of_data + 'items' + p_lease + '.csv', False, True);
        p_new := true;
     end;

     SdfItems.FileName := g_path_of_data + 'items' + p_lease + '.csv';
     SdfItems.Open;
     if p_new then begin
        while not SdfItems.Eof do begin
           SdfItems.Edit;
           SdfItems.FieldValues['lease'] := p_lease;
           SdfItems.Post;
           SdfItems.Next;
        end;
        SdfItems.First;
     end;

     MemoTrigger.Clear;
     if FileExists(g_path_of_data + 'Trigger' + p_lease + '.dat') then
        MemoTrigger.Lines.LoadFromFile(g_path_of_data + 'Trigger' + p_lease + '.dat');
  end;
end;

procedure TForm1.btnCloseClick(Sender: TObject);
begin
  Form1.Close;
end;

procedure TForm1.btnApplyTriggersClick(Sender: TObject);
var
  p_i: Integer;
  p_line: String;
  p_ScheduleExists, p_RefundExists, p_NotifyExists, p_StopScheduleExists: Integer;
begin
  g_OpenLease := '';
  with SdfLeases do begin
     Edit;
     FieldValues['post']   := '       ';
     Post;
  end;

  p_line := MemoTrigger.Lines[MemoTrigger.Lines.Count - 1];
  if Empty(p_line) or (StrIn('Session Saved', p_line)) then
     Exit;

  p_ScheduleExists     := 0;
  p_RefundExists       := 0;
  p_NotifyExists       := 0;
  p_StopScheduleExists := 0;

  p_i := MemoTrigger.Lines.Count - 1;
  while p_i >= 0 do begin
     p_line := MemoTrigger.Lines[p_i];

     if StrIn('Session Saved', p_line) then
        Break;

     if StrIn('Payment Schedule', p_line) then begin
        if p_ScheduleExists > 0 then begin
           MemoTrigger.Lines.Delete(p_i);
           p_i := p_i - 1;
           Continue;
        end;
        Inc(p_ScheduleExists);
     end

     else if StrIn('Stop', p_line) then begin
        if p_StopScheduleExists > 0 then begin
           MemoTrigger.Lines.Delete(p_i);
           p_i := p_i - 1;
           Continue;
        end;
        Inc(p_StopScheduleExists);
     end

     else if StrIn('Refund', p_line) then begin
        if p_RefundExists > 0 then begin
           MemoTrigger.Lines.Delete(p_i);
           p_i := p_i - 1;
           Continue;
        end;
        Inc(p_RefundExists);
     end

     else if StrIn('Notify', p_line) then begin
        if p_NotifyExists > 0 then begin
           MemoTrigger.Lines.Delete(p_i);
           p_i := p_i - 1;
           Continue;
        end;
        Inc(p_NotifyExists);
     end;
     p_i := p_i - 1;
  end;

  AddTrigger('Session Saved');
end;

procedure TForm1.btnDecisionClick(Sender: TObject);
begin
  Decision;
end;

procedure TForm1.btnDeleteClick(Sender: TObject);
begin
  if not SdfItems.EOF then
     SdfItems.Delete;
end;

procedure TForm1.btnDeleteLeaseClick(Sender: TObject);
begin
  if not Form1.SdfLeases.EOF then
     Form1.SdfLeases.Delete;

  Truncate(SdfJournal);
end;

procedure TForm1.btnFundClick(Sender: TObject);
var
  p_batch: String;
begin
  if SdfLeases.FieldValues['status'] = 'Void' then begin
     ShowMessage('May Not Fund a Voided Lease!');
     Exit;
  end;

  p_batch := lblCurrentbatch.Caption;
  with SdfItems do begin
     First;
     while not Eof do begin
        if (SdfItems.FieldValues['status'] = 'Returned') or (SdfItems.FieldValues['status'] = 'Cancelled') or (SdfItems.FieldValues['status'] = 'Substituted') then begin
           Next;
           Continue;
        end;
        if SdfItems.FieldValues['status'] <> 'Delivered' then begin
           ShowMessage('Cannot be Funded!');
           Exit;
        end;
        Next;
     end;
  end;
  SdfLeases.Edit;
  SdfLeases.FieldValues['status'] := 'Funded';
  SdfLeases.Post;

  with SdfItems do begin
     First;
     while not Eof do begin
        if (FieldValues['status'] = 'Returned') or (FieldValues['status'] = 'Cancelled') or (FieldValues['status'] = 'Substituted') then begin
           Edit;
           FieldValues['postfund'] := True;
           Post;
           Next;
           Continue;
        end;
        if Empty(FieldValues['fundDate']) then begin
           Edit;
           FieldValues['fundDate'] := FormatDateTime('mm/dd/yyyy', now);
           FieldValues['fundTime'] := FormatDateTime('hh:mm:ss', now);
           FieldValues['postfund'] := True;
           FieldValues['batch']    := p_batch;
           Post;
           LogJournal(FieldValues['status'], FieldValues['qty'], StrToFloatDef(FieldValues['total'], 0));
        end;
        Next;
     end;
     First;
  end;

  p_batch := IntToStr(StrToIntDef(p_batch, 0) + 1);
  Form1.lblCurrentbatch.Caption := p_batch;
  Decision;
end;

procedure TForm1.btnQtyClick(Sender: TObject);
var
  p_qty: String;
  p_iqty: Integer;
  p_itemPrice: Real;
begin
   with Form1.SdfItems do begin
      InputQuery('Enter', 'Item ' + IntToStr(RecNo) + ' Quantity', False, p_qty);
      p_iqty      := StrToIntDef(p_qty, 0);
      p_itemPrice := StrToFloat(FieldValues['price']) / StrToFloat(FieldValues['qty']);
      if p_iqty = 0 then
         Exit;
      Edit;
      FieldValues['qty']   := IntToStr(p_iqty);
      FieldValues['total'] := FloatToDollar(p_itemPrice * p_iqty);
      Post;
   end;
end;

procedure TForm1.btnRefreshClick(Sender: TObject);
begin
  SdfLeases.Close;
  SdfLeases.Open;
  OpenItems;
  ShowMessage('Refreshed!');
end;

procedure TForm1.btnResetClick(Sender: TObject);
begin
  with Form1 do begin
    SdfItems.First;
    while not SdfItems.Eof do begin
      SdfItems.Edit;
      SdfItems.FieldValues['lease']     := SdfLeases.FieldValues['lease'];
      SdfItems.FieldValues['item']      := IntToStr(SdfItems.RecNo);
      SdfItems.FieldValues['status']    := 'Open';
      SdfItems.FieldValues['dod']       := ' ';
      SdfItems.FieldValues['postfund']  := 'False';
      SdfItems.FieldValues['fundDate']  := ' ';
      SdfItems.FieldValues['fundTime']  := ' ';
      SdfItems.FieldValues['qty']       := '1';
      SdfItems.FieldValues['price']     := FloatToDollar(SdfItems.RecNo * 100);
      SdfItems.FieldValues['total']     := FloatToDollar(SdfItems.RecNo * 100);
      SdfItems.FieldValues['batch']     := ' ';
      SdfItems.FieldValues['reference'] := ' ';
      SdfItems.Post;
      SdfItems.Next;
    end;
    SdfItems.First;

    Truncate(SdfJournal);

    SdfLeases.Edit;
    SdfLeases.FieldValues['status'] := 'Open       ';
    SdfLeases.FieldValues['post']   := '       ';
    SdfLeases.Post;

    MemoTrigger.Clear;
    SaveTriggers;
  end;
  SumJournal;
end;

procedure TForm1.btnSignLeaseClick(Sender: TObject);
begin
  if SdfLeases.FieldValues['status'] <> 'Incomplete' then begin
     ShowMessage('Lease Already Signed!');
  end;
  with SdfLeases do begin
     Edit;
     FieldValues['status'] := 'Open';
     Post;
  end;
end;

procedure TForm1.DBGridItemsDblClick(Sender: TObject);
var
  p_reference: String;
begin
  p_reference := SdfItems.FieldValues['reference'];
  if Empty(p_reference) then
     Exit;

  with SdfLeases do begin
    First;
    while not Eof do begin
       if FieldValues['lease'] = p_reference then begin
          DBGridLeasesCellClick(Nil);
          Break;
       end;
       Next;
    end;
  end;
end;

procedure TForm1.DBGridItemsMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
     Exit;
  PopMenu.Items.Find('Open').Visible      := True;
  PopMenu.Items.Find('Deliver').Visible   := True;
  PopMenu.Items.Find('Backorder').Visible := True;
  PopMenu.Items.Find('Return').Visible    := True;
  PopMenu.Items.Find('Cancel').Visible    := True;

  if SdfItems.FieldValues['status'] = 'Substituted' then begin
     ShowMessage('Substituted Items May Not Be Modified!');
     Exit;
  end;

  if SdfLeases.FieldValues['status'] = 'Incomplete' then begin
     ShowMessage('Until Lease is Signed, Items May Not Be Modified!');
     Exit;
  end;

  if Empty(SdfItems.FieldValues['dod']) then begin
     PopMenu.Items.Find('Substitute').Visible  := True;
     PopMenu.Items.Find('Substitute w/ Return').Visible := False;
  end
  else begin
    PopMenu.Items.Find('Substitute w/ Return').Visible := True;
    PopMenu.Items.Find('Substitute').Visible  := False;
  end;

  if SdfItems.FieldValues['status'] = 'Cancelled' then begin
     ShowMessage('Cancelled Items May Not Be Modified!');
     Exit;
  end
  else if SdfItems.FieldValues['status'] = 'Delivered' then begin
     PopMenu.Items.Find('Open').Visible      := False;
     PopMenu.Items.Find('Deliver').Visible   := False;
     PopMenu.Items.Find('Backorder').Visible := False;
     PopMenu.Items.Find('Cancel').Visible    := False;
  end
  else if SdfItems.FieldValues['status'] = 'Returned' then begin
     ShowMessage('Returned Items May Not Be Modified!');
     Exit;
  end
  else if SdfItems.FieldValues['status'] = 'Backordered' then begin
     PopMenu.Items.Find('Open').Visible      := False;
     PopMenu.Items.Find('Backorder').Visible := False;
     PopMenu.Items.Find('Return').Visible    := False;
  end
  else if SdfItems.FieldValues['status'] = 'Open' then begin
     PopMenu.Items.Find('Open').Visible      := False;
     PopMenu.Items.Find('Return').Visible    := False;
  end
  else if SdfItems.FieldValues['status'] = 'Substitute' then begin
     PopMenu.Items.Find('Deliver').Visible   := False;
     PopMenu.Items.Find('Backorder').Visible := False;
     PopMenu.Items.Find('Return').Visible    := False;
  end;
  PopMenu.PopUp(Mouse.CursorPos.X , Mouse.CursorPos.Y);
end;

procedure TForm1.DBGridLeasesCellClick(Column: TColumn);
begin
  OpenItems;
  SumJournal;
  GBTriggers.Caption := 'Lease ' + Form1.SdfLeases.FieldValues['lease'] + ' Trigger Events';
  GBJournal.Caption  := 'Lease ' + Form1.SdfLeases.FieldValues['lease'] + ' Funding Journal';
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Width := 1200;
  SdfLeases.FileName := g_path_of_data + 'leases.csv';
  SdfLeases.Open;

  OpenItems;
  SumJournal;

  Label1.Caption := 'Data Path: ' + g_path_of_data;
  Label4.Caption := 'Exec Path: ' + GetCurrentDir;
end;

procedure TForm1.MenuBackorderedClick(Sender: TObject);
var
  p_OldQty, p_iqty, p_Diff: Integer;
  p_status, p_qty: String;
  p_itemPrice: Real;
  p_postfund, p_fundDate, p_fundTime, p_dod: String;
begin
  with SdfItems do begin
     p_iqty      := 0;
     p_diff      := 0;
     p_status    := FieldValues['status'];
     p_OldQty    := StrToIntDef(FieldValues['qty'], 1);
     p_ItemPrice := StrToFloat(FieldValues['price']);
     p_postfund  := FieldValues['postfund'];
     p_fundDate  := FieldValues['fundDate'];
     p_fundTime  := FieldValues['fundTime'];
     p_dod       := FieldValues['dod'];

     if p_OldQty > 1 then begin
        InputQuery('Enter', 'Item ' + IntToStr(RecNo) + ' Backorder Quantity', False, p_qty);
        p_iqty := StrToIntDef(p_qty, 0);
        p_diff := p_OldQty - p_iqty;
     end;

     Edit;
     if p_diff = 0 then begin
        FieldValues['status'] := 'Backordered';
     end
     else begin
       FieldValues['qty']    := IntToStr(p_OldQty - p_iqty);
       FieldValues['total']  := FloatToDollar(p_ItemPrice * (p_OldQty - p_iqty));
     end;
     Post;

     if p_diff > 0 then begin
        Append;
        FieldValues['status']   := 'Backordered';
        FieldValues['qty']      := IntToStr(p_iqty);
        FieldValues['postfund'] := p_postfund;
        FieldValues['fundDate'] := NotEmpty(p_fundDate);
        FieldValues['fundTime'] := NotEmpty(p_fundTime);
        FieldValues['lease']    := SdfLeases.FieldValues['lease'];
        FieldValues['item']     := IntToStr(RecordCount + 1);
        FieldValues['price']    := FloatToDollar(p_ItemPrice);
        FieldValues['total']    := FloatToDollar(p_ItemPrice * p_iqty);
        FieldValues['dod']      := NotEmpty(p_dod);
        FieldValues['batch']    := ' ';
        Post;
     end;
  end;
  Decision;
end;

procedure TForm1.MenuCancelledClick(Sender: TObject);
var
  p_OldQty, p_iqty, p_Diff: Integer;
  p_status, p_qty: String;
  p_itemPrice: Real;
  p_postfund, p_fundDate, p_fundTime, p_dod: String;
begin
  with SdfItems do begin
     if (FieldValues['status'] <> 'Backordered') and (FieldValues['status'] <> 'Open') then begin
        ShowMessage('Applies Only to Backordered Items!');
        Exit;
     end;
     p_iqty      := 0;
     p_diff      := 0;
     p_status    := FieldValues['status'];
     p_OldQty    := StrToIntDef(FieldValues['qty'], 1);
     p_ItemPrice := StrToFloat(FieldValues['price']);
     p_postfund  := FieldValues['postfund'];
     p_fundDate  := FieldValues['fundDate'];
     p_fundTime  := FieldValues['fundTime'];
     p_dod       := FieldValues['dod'];

     if p_OldQty > 1 then begin
        InputQuery('Enter', 'Item ' + IntToStr(RecNo) + ' Cancelled Quantity', False, p_qty);
        p_iqty := StrToIntDef(p_qty, 0);
        p_diff := p_OldQty - p_iqty;
     end;

     Edit;
     if p_diff = 0 then begin
        FieldValues['status'] := 'Cancelled';
     end
     else begin
       FieldValues['qty']    := IntToStr(p_OldQty - p_iqty);
       FieldValues['total']  := FloatToDollar(p_ItemPrice * (p_OldQty - p_iqty));
     end;
     Post;

     if p_diff > 0 then begin
        Append;
        FieldValues['status']   := 'Cancelled';
        FieldValues['dod']      := ' ';
        FieldValues['qty']      := IntToStr(p_iqty);
        FieldValues['postfund'] := p_postfund;
        FieldValues['fundDate'] := NotEmpty(p_fundDate);
        FieldValues['fundTime'] := NotEmpty(p_fundTime);
        FieldValues['lease']    := SdfLeases.FieldValues['lease'];
        FieldValues['item']     := IntToStr(RecordCount + 1);
        FieldValues['price']    := FloatToDollar(p_ItemPrice);
        FieldValues['total']    := FloatToDollar(p_ItemPrice * p_iqty);
        FieldValues['dod']      := NotEmpty(p_dod);
        FieldValues['batch']    := ' ';
        Post;
     end;
  end;
  Decision;
  if SdfLeases.FieldValues['status'] = 'Void' then begin
     AddTrigger('002 Notify(email, sms) Customer of Cancelled Lease');
     AddTrigger('002 Stop Payment Schedule');
     AddTrigger('002 Issue Refund to Customer');
  end
  else begin
     AddTrigger('003 Generate New Payment Schedule');
     AddTrigger('003 Notify(email, sms) Customer of Change');
     AddTrigger('003 Issue Refund to Customer');
  end;
end;

procedure TForm1.MenuDeliverAllClick(Sender: TObject);
var
  p_date: TDateTime;
  p_days: Integer;
begin
  with SdfItems do begin
     Calendar.Date := now;
     if Calendar.Execute then begin
        p_date := Calendar.Date;
        First;
        while not Eof do begin
           if FieldValues['status'] <> 'Delivered' then begin
              Edit;
              if p_date > now then begin
                 ShowMessage('May Not Set a Delivery Date in the Future!');
                 Exit;
              end;

              p_days := DaysBetween(p_date, now);
              if p_days > 5 then begin
                 ShowMessage('May Not Set a Delivery Date Prior to Origination Date!');
                 Exit;
              end;
              FieldValues['dod'] := FormatDateTime('mm/dd/yyyy', p_date);
              FieldValues['status'] := 'Delivered';
              FieldValues['batch']  := ' ';
              Post;
              LogJournal('Delivered', FieldValues['qty'], StrToFloatDef(FieldValues['total'], 0));
           end;
           Next;
        end;
     end;
  end;
  Decision;
end;

procedure TForm1.MenuDeliveredClick(Sender: TObject);
var
  p_date: TDateTime;
  p_qty, p_status: String;
  p_iqty, p_diff, p_test: Integer;
  p_itemPrice: Real;
  p_days: Integer;
begin
  with SdfItems do begin
     if FieldValues['status'] = 'Delivered' then
        Exit;

     p_status    := FieldValues['status'];
     p_ItemPrice := StrToFloat(FieldValues['price']);
     p_iqty      := 1;
     p_diff      := 0;

     if FieldValues['qty'] <> '1' then begin
        InputQuery('Enter', 'Qty Delivered of Item ' + IntToStr(RecNo), False, p_qty);
        p_iqty := StrToIntDef(p_qty, 0);
        if p_iqty <= 0 then
           Exit;
        if p_iqty > StrToIntDef(FieldValues['qty'],0) then begin
           ShowMessage('Delivered Qty Exceeed Item Qty!');
           Exit;
        end;
     end;

     p_test := StrToIntDef(FieldValues['qty'],0);
     if p_test <> p_iqty then begin
        p_diff := StrToIntDef(FieldValues['qty'],0) - p_iqty;
     end;

     Calendar.Date := now;
     if Calendar.Execute then begin
        Edit;
        p_date := Calendar.Date;
        if p_date > now then begin
           ShowMessage('May Not Set a Delivery Date in the Future!');
           Exit;
        end;

        p_days := DaysBetween(p_date, now);
        if p_days > 5 then begin
           ShowMessage('May Not Set a Delivery Date Prior to Origination Date!');
           Exit;
        end;

        FieldValues['dod']    := FormatDateTime('mm/dd/yyyy', p_date);
        FieldValues['status'] := 'Delivered';
        FieldValues['qty']    := IntToStr(p_iqty);
        FieldValues['price']  := FloatToDollar(p_ItemPrice);
        FieldValues['total']  := FloatToDollar(p_ItemPrice * p_iqty);
        FieldValues['batch']  := ' ';
        Post;
        LogJournal('Delivered', IntToStr(p_iqty),p_ItemPrice * p_iqty);

        if p_diff > 0 then begin
           Append;
           FieldValues['status']   := p_status;
           FieldValues['dod']      := ' ';
           FieldValues['qty']      := IntToStr(p_diff);
           FieldValues['fundDate'] := ' ';
           FieldValues['fundTime'] := ' ';
           FieldValues['lease']    := SdfLeases.FieldValues['lease'];
           FieldValues['item']     := IntToStr(RecordCount + 1);
           FieldValues['price']    := FloatToDollar(p_ItemPrice);
           FieldValues['total']    := FloatToDollar(p_ItemPrice * p_diff);
           FieldValues['postfund'] := False;
           FieldValues['batch']    := ' ';
           Post;
        end;
     end;
  end;
  Decision;
end;

procedure TForm1.MenuItem1Click(Sender: TObject);
begin
  MenuSubstituteClick(Nil);
end;

procedure TForm1.MenuReturnedClick(Sender: TObject);
var
   p_OldQty, p_iqty, p_Diff: Integer;
   p_status, p_qty: String;
   p_itemPrice: Real;
   p_postfund, p_fundDate, p_fundTime, p_dod, p_batch: String;
begin
  with SdfItems do begin
     p_iqty      := 0;
     p_diff      := 0;
     p_status    := FieldValues['status'];
     p_OldQty    := StrToIntDef(FieldValues['qty'], 1);
     p_ItemPrice := StrToFloat(FieldValues['price']);
     p_postfund  := FieldValues['postfund'];
     p_fundDate  := FieldValues['fundDate'];
     p_fundTime  := FieldValues['fundTime'];
     p_dod       := FieldValues['dod'];
     p_batch     := FieldValues['batch'];

     if p_OldQty > 1 then begin
        InputQuery('Enter', 'Item ' + IntToStr(RecNo) + ' Return Quantity', False, p_qty);
        p_iqty := StrToIntDef(p_qty, 0);
        p_diff := p_OldQty - p_iqty;
     end;

     Edit;
     if p_diff = 0 then begin
        FieldValues['status'] := 'Returned';
        LogJournal('Returned', FieldValues['qty'], -1 * p_ItemPrice * (p_OldQty - p_iqty));
     end
     else begin
       FieldValues['qty']    := IntToStr(p_OldQty - p_iqty);
       FieldValues['total']  := FloatToDollar(p_ItemPrice * (p_OldQty - p_iqty));
     end;
     Post;

     if p_diff > 0 then begin
        Append;
        FieldValues['status']   := 'Returned';
        FieldValues['dod']      := ' ';
        FieldValues['qty']      := IntToStr(p_iqty);
        FieldValues['postfund'] := p_postfund;
        FieldValues['fundDate'] := NotEmpty(p_fundDate);
        FieldValues['fundTime'] := NotEmpty(p_fundTime);
        FieldValues['lease']    := SdfLeases.FieldValues['lease'];
        FieldValues['item']     := IntToStr(RecordCount + 1);
        FieldValues['price']    := FloatToDollar(p_ItemPrice);
        FieldValues['total']    := FloatToDollar(p_ItemPrice * p_iqty);
        FieldValues['dod']      := NotEmpty(p_dod);
        FieldValues['batch']    := p_batch;
        Post;
        LogJournal('Returned', IntToStr(p_iqty), -1 * p_ItemPrice * p_iqty);
     end;
  end;
  Decision;
  if StrIn('Void', SdfLeases.FieldValues['status']) then begin
     AddTrigger('004 Notify(email, sms) Customer of Returned Lease');
     AddTrigger('004 Stop Payment Schedule');
     AddTrigger('004 Issue Refund to Customer');
  end
  else begin
     AddTrigger('005 Generate New Payment Schedule');
     AddTrigger('005 Notify(email, sms) Customer of Change');
     AddTrigger('005 Issue Refund to Customer');
  end;
end;

procedure TForm1.MenuOpenClick(Sender: TObject);
begin
   with SdfItems do begin
      Edit;
      FieldValues['status'] := 'Open';
      Post;
   end;
   Decision;
end;

procedure TForm1.MenuSubstituteClick(Sender: TObject);
begin
   Application.CreateForm(TForm2, Form2);
   Form2.ShowModal;
   Decision;
end;

procedure Decision;
var
  p_LeaseStatus: String;
  p_AllDelivered, p_AllReturned, p_AllCancelled, p_PostFund, p_AllFunded: Boolean;
begin
  with Form1 do begin
    // Test For Open Status //
    SdfLeases.Edit;
    SdfLeases.FieldValues['post'] := '*';
    SdfLeases.Post;

    SdfItems.First;
    while not SdfItems.Eof do begin
       p_PostFund := SdfItems.FieldValues['postfund'];
       if (SdfItems.FieldValues['status'] = 'Open') and p_PostFund then begin //and (Empty(SdfItems.FieldValues['fundDate'])
          SetLeaseStatus('!Open');
          Exit;
       end;
       SdfItems.Next;
    end;

    SdfItems.First;
    while not SdfItems.Eof do begin
      if (SdfItems.FieldValues['status'] = 'Open') and (Empty(SdfItems.FieldValues['fundDate'])) then begin
         if SdfLeases.FieldValues['status'] <> 'Incomplete' then
            SetLeaseStatus('Open');
         Exit;
      end;
      SdfItems.Next;
    end;
    /////////////////////////////////////////////////////////////////////////////

    // Test For All Delievered Status //
    p_AllDelivered := True;
    SdfItems.First;
    while not SdfItems.Eof do begin
      if (SdfItems.FieldValues['status'] <> 'Delivered') and (SdfItems.FieldValues['status'] <> 'Cancelled') and (SdfItems.FieldValues['status'] <> 'Returned') and (SdfItems.FieldValues['status'] <> 'Substituted') then begin
         p_AllDelivered := False;
         Break;
      end;
      SdfItems.Next;
    end;

    SdfItems.First;
    p_LeaseStatus := SdfLeases.FieldValues['Status'];
    if p_AllDelivered and (p_LeaseStatus = 'Funded') then begin
       with SdfItems do begin
          while not Eof do begin
             if (not Empty(FieldValues['fundDate'])) and ((FieldValues['status'] = 'Returned') or (FieldValues['status'] = 'Substituted')) then begin
                SetLeaseStatus('!Funded');
                First;
                Break;
             end;
             Next;
          end;
          // Test For All Returned //
          if AllReturned then
             SetLeaseStatus('!Void');
       end;
       Exit;
    end;

    if p_AllDelivered then
       SetLeaseStatus('Pending');
    /////////////////////////////////////////////////////////////////////////////

    // Test For Backorders Status //
    while not SdfItems.Eof do begin
      if SdfItems.FieldValues['status'] = 'Backordered' then begin
         SetLeaseStatus('!Pending');
         Break;
      end;
      SdfItems.Next;
    end;
    /////////////////////////////////////////////////////////////////////////////

    // Test For Substitute //
    {
    SdfItems.First;
    while not SdfItems.Eof do begin
      if SdfItems.FieldValues['status'] = 'Substitute' then begin
         SetLeaseStatus('!Issue');
         Break;
      end;
      SdfItems.Next;
    end;
    }
    /////////////////////////////////////////////////////////////////////////////

    // Test For All Cancelled //
    // Funded //
    p_AllCancelled := True;
    SdfItems.First;
    while not SdfItems.Eof do begin
       if (SdfItems.FieldValues['status'] <> 'Cancelled') and (SdfItems.FieldValues['status'] <> 'Returned') then begin
          p_AllCancelled := False;
          Break;
       end;
       SdfItems.Next;
     end;
     if p_AllCancelled then begin
        with SdfItems do begin
           First;
           while not Eof do begin
              if not Empty(FieldValues['fundDate']) then begin
                 SetLeaseStatus('!Void');
                 Exit;
              end;
              Next;
           end;
        end;
        SetLeaseStatus('Void');
        Exit;
     end;
     /////////////////////////////////////////////////////////////////////////////

     // Test For Returned //
     // All Items Are Returned or Cancelled //

     SdfItems.First;
     p_AllFunded := True;
     while not SdfItems.Eof do begin
        if Empty(SdfItems.FieldValues['fundDate']) and (not SdfItems.FieldValues['postfund']) then begin
           p_AllFunded := False;
           Break;
        end;
        SdfItems.Next;
     end;

     SdfItems.First;
     if p_AllFunded then begin
        while not SdfItems.Eof do begin
           if (SdfItems.FieldValues['status'] = 'Returned') or (SdfItems.FieldValues['status'] = 'Cancelled') or (SdfItems.FieldValues['status'] = 'Open') or (SdfItems.FieldValues['status'] = 'Substituted') then begin
              SetLeaseStatus('!Funded');
              Break;
           end;
           SdfItems.Next;
        end;
     end
     else begin
        p_AllReturned := True;
        SdfItems.First;
        while not SdfItems.Eof do begin
           if (SdfItems.FieldValues['status'] <> 'Returned') and (SdfItems.FieldValues['status'] <> 'Cancelled') and (SdfItems.FieldValues['status'] <> 'Substituted') then begin
              p_AllReturned := False;
              Break;
           end;
           SdfItems.Next;
        end;
        if p_AllReturned then begin
           SetLeaseStatus('Void');
        end;
     end;
    /////////////////////////////////////////////////////////////////////////////
  end;
end;

end.

