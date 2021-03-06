unit uGLGameForm;

interface

uses
  dglOpenGL,
  dgCommonTypes,
  dgCamera,
  dgGlUtils,
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, Dialogs;

const
  XSize = 800;
  YSize = 600;

type
  TfrmGL2DTemplate = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    fDeviceContext      : HDC;
    fGLRenderingContext : HGLRC;
    fBGColor            : TColor4f;
    fActiveCamera       : TCamera;

    fDeltaTime : double;
    fFramesRendered     : integer;
    fFramesInLastSecond : integer;
    fLastSecondBegining : real;
    fFrameBeginTime: Int64;
    fFrameEndTime : Int64;
    fFrequency : Int64;

    procedure InitializeOpenGL;
    procedure InitializeCamera;
    procedure FinalizeOpenGL;

    procedure EraseBg(var Msg:TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure OnIdle(Sender: TObject; var Done: Boolean);

    procedure SetFullSreen;
    procedure AdjustFormToFullScreen(pWidth, pHeight: integer);
    procedure SceneLoop;
  protected
    procedure StartScene; virtual;
    procedure EndScene; virtual;
  public
    procedure DrawScene; virtual;

    procedure InitObjects; virtual;
    procedure FreeObjects; virtual;

    property BGColor: TColor4f read fBGColor write fBGColor;

    property DeltaTime: double read fDeltaTime;
    property FrameBeginTime: Int64 read fFrameBeginTime;

    property ActiveCamera : TCamera read fActiveCamera write fActiveCamera;

  end;

var
  frmGL2DTemplate: TfrmGL2DTemplate;

implementation

{$R *.dfm}

procedure TfrmGL2DTemplate.AdjustFormToFullScreen(pWidth, pHeight: integer);
begin
  Width  := pWidth;
  Height := pHeight;
  BorderStyle := bsNone;
  Left := 0;
  Top := 0;
  FormStyle := fsStayOnTop;
  Color := clBackground;
end;

procedure TfrmGL2DTemplate.SetFullSreen;
var
  lDMSettings : DEVMODE;
  i : integer;
begin
  if not(EnumDisplaySettings(nil, 0, lDMSettings)) then
    begin
      MessageBox(Handle, 'Could not enum display Settings', 'Error', MB_OK);
      PostQuitMessage(0);
    end;

  lDMSettings.dmPelsWidth  := XSize;
  lDMSettings.dmPelsHeight := YSize;
  lDMSettings.dmFields     := DM_PELSWIDTH or DM_PELSHEIGHT;

  i := ChangeDisplaySettings(lDMSettings, CDS_FULLSCREEN);
  if not(i=DISP_CHANGE_SUCCESSFUL) then
    begin
      MessageBox(NULL, 'Display mode not compatible', 'Error', MB_OK);
      PostQuitMessage(0);
    end
  else
    AdjustFormToFullScreen(XSize, YSize);
end;

procedure TfrmGL2DTemplate.DrawScene;
begin
  glMatrixMode(GL_MODELVIEW);
  glClearColor(fBGColor.Red, fBGColor.Green, fBGColor.Blue, fBGColor.Alpha);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
  glLoadIdentity;

//  TGlUtils.SquarePlane( ClientHeight-10 );

  {
  glColor3i(1,0,0);
  glBegin(GL_QUADS);
     // as primitivas s�o desenhadas no sentido anti-hor�rio
     glColor3f(1,0,0);  glVertex2i(10, 10);
     glColor3f(0,1,0);  glVertex2i(10, ClientHeight-10);
     glColor3f(0,0,1);  glVertex2i(ClientWidth-10, ClientHeight-10);
     glColor3f(1,1,1);  glVertex2i(ClientWidth-10, 10);
  glEnd;
  }

  glPointSize(5);
  glColor3i(1,1,1);
  glBegin(GL_POINTS);
    glVertex2i(0,0);
  glEnd;

end;

procedure TfrmGL2DTemplate.EndScene;
begin
  SwapBuffers(wglGetCurrentDC);
  Inc(fFramesRendered);

  QueryPerformanceCounter(fFrameEndTime);
  fDeltaTime := ( (fFrameBeginTime - fFrameEndTime) * 1000) / fFrequency;


  if ( (fFrameEndTime - fLastSecondBegining ) * 1000 / fFrequency ) > 1000 then
  begin
    fLastSecondBegining := fFrameEndTime;
    fFramesInLastSecond := fFramesRendered;
    fFramesRendered := 0;
    Caption := FormatFloat('FPS: #,000', fFramesInLastSecond);
  end;
end;

procedure TfrmGL2DTemplate.EraseBg(var Msg: TWMEraseBkgnd);
begin
  Msg.Result := 0;
end;

procedure TfrmGL2DTemplate.FinalizeOpenGL;
begin
  DeactivateRenderingContext;
  wglDeleteContext(fGLRenderingContext);
  ReleaseDC(fDeviceContext, fGLRenderingContext);
end;

procedure TfrmGL2DTemplate.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Application.OnIdle := nil;
  FinalizeOpenGL;
  FreeObjects;
end;

procedure TfrmGL2DTemplate.FormCreate(Sender: TObject);
begin
  //ajustando a janela
  BorderStyle := bsSingle;
  BorderIcons := [biSystemMenu];
  ClientWidth := XSize;
  ClientHeight := YSize;
  Position := poDesktopCenter;

  InitObjects;

  InitializeOpenGL;
  InitializeCamera;

  QueryPerformanceFrequency(fFrequency);
  QueryPerformanceCounter(fFrameBeginTime);
  fFrameEndTime := fFrameBeginTime;
  fLastSecondBegining := fFrameBeginTime;
  fFramesInLastSecond := 0;

  fBGColor.Red   := 0.3;
  fBGColor.Green := 0.3;
  fBGColor.Blue  := 0.3;
  fBGColor.Alpha := 0;

  Caption := 'FPS: Calculating...';
  Application.OnIdle := OnIdle;
end;

procedure TfrmGL2DTemplate.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if ssAlt in Shift then
    if key = VK_RETURN then SetFullSreen;

  case key of
    VK_UP : begin
                fActiveCamera.Zoom := fActiveCamera.Zoom + 0.01;
                fActiveCamera.Update;
              end;

    VK_DOWN : begin
                fActiveCamera.Zoom := fActiveCamera.Zoom - 0.01;
                fActiveCamera.Update;
              end;
  end;

end;

procedure TfrmGL2DTemplate.FreeObjects;
begin
  FreeAndNil(fActiveCamera);
end;

procedure TfrmGL2DTemplate.InitializeCamera;
begin
  fActiveCamera.Kind := pkOrthogonal;
  fActiveCamera.Position.SetValue(0, 0, 1);
  fActiveCamera.Target.SetValue(0,0,0);
  fActiveCamera.Params.ViewPort := Rect(0, 0, ClientWidth, ClientHeight);
  fActiveCamera.Up.SetValue(0,1,0);
  fActiveCamera.Update;
end;

procedure TfrmGL2DTemplate.InitializeOpenGL;
begin
  dglOpenGL.InitOpenGL;
  fDeviceContext := GetDC(Handle);
  fGLRenderingContext := CreateRenderingContext(fDeviceContext, [opDoubleBuffered], 32, 16, 0, 0, 0, 1);
  dglOpenGL.ActivateRenderingContext(fDeviceContext, fGLRenderingContext);

  glShadeModel(GL_SMOOTH);
  glEnable(GL_TEXTURE_2D);
  glEnable(GL_TEXTURE_BINDING_2D);
end;

procedure TfrmGL2DTemplate.InitObjects;
begin
  fActiveCamera := TCamera.Create;
end;

procedure TfrmGL2DTemplate.SceneLoop;
begin
  StartScene;
  DrawScene;
  EndScene;
end;

procedure TfrmGL2DTemplate.OnIdle(Sender: TObject; var Done: Boolean);
begin
  SceneLoop;
  done := false;
end;

procedure TfrmGL2DTemplate.StartScene;
begin
  QueryPerformanceCounter(fFrameBeginTime);

end;

end.
