#define MyAppName      "PokeTeamDex"
#define MyAppPublisher "Asante"
#define MyAppExeName   "poke_team_dex.exe"
#define MyAppDataDir   "com.asante.poke_team_dex"
#define MyAppURL       "https://github.com/KwasiAsante/poke_team_dex"
#define MyAppRegKey    "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\" + \
                       "{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}_is1"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#AppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues

; Re-use the previous install location if one exists, otherwise default
; to Program Files. The [Code] section overrides this at runtime.
DefaultDirName={autopf}\{#MyAppName}
UsePreviousAppDir=yes

DefaultGroupName={#MyAppName}
AllowNoIcons=yes

OutputDir={#OutputDir}
OutputBaseFilename={#OutputFilename}

Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
; Both shortcuts are ticked by default; users can untick before installing.
Name: "startmenu"; Description: "Create a &Start Menu shortcut";  GroupDescription: "Shortcuts:"; Flags: checkedonce
Name: "desktopicon"; Description: "Create a &Desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: checkedonce

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}";                            Filename: "{app}\{#MyAppExeName}"; Tasks: startmenu
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}";      Filename: "{uninstallexe}";        Tasks: startmenu
Name: "{autodesktop}\{#MyAppName}";                      Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; \
  Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; \
  Flags: nowait postinstall skipifsilent

; ── Pascal script ─────────────────────────────────────────────────────────

[Code]

{ ── Version helpers ─────────────────────────────────────────────────── }

{ Read a string value from the uninstall registry key.
  Checks HKLM first, then HKCU (for per-user installs). }
function ReadUninstallValue(const Name: String): String;
begin
  Result := '';
  if not RegQueryStringValue(HKLM64, '{#MyAppRegKey}', Name, Result) then
    RegQueryStringValue(HKCU, '{#MyAppRegKey}', Name, Result);
end;

function GetInstalledVersion: String;
begin
  Result := ReadUninstallValue('DisplayVersion');
end;

function GetInstalledLocation: String;
begin
  Result := ReadUninstallValue('InstallLocation');
end;

function GetUninstallString: String;
begin
  Result := ReadUninstallValue('UninstallString');
end;

{ Compare two dotted-version strings (e.g. "1.2.3").
  Returns:  1  if A > B
            0  if A = B
           -1  if A < B }
function CompareVersion(const A, B: String): Integer;
var
  PA, PB, NA, NB: Integer;
  SA, SB: String;
begin
  SA := A; SB := B;
  Result := 0;
  repeat
    PA := Pos('.', SA); PB := Pos('.', SB);

    if PA > 0 then begin NA := StrToIntDef(Copy(SA,1,PA-1),0); SA := Copy(SA,PA+1,MaxInt); end
    else            begin NA := StrToIntDef(SA,0);               SA := ''; end;

    if PB > 0 then begin NB := StrToIntDef(Copy(SB,1,PB-1),0); SB := Copy(SB,PB+1,MaxInt); end
    else            begin NB := StrToIntDef(SB,0);               SB := ''; end;

    if NA > NB then begin Result :=  1; Exit; end;
    if NA < NB then begin Result := -1; Exit; end;
  until (SA = '') and (SB = '');
end;

{ ── Setup initialisation ─────────────────────────────────────────────── }

{ Called before the wizard is shown.
  Handles all version-comparison scenarios and may abort setup. }
function InitializeSetup: Boolean;
var
  Installed, NewVer: String;
  Cmp: Integer;
begin
  Result    := True;
  NewVer    := '{#AppVersion}';
  Installed := GetInstalledVersion;

  if Installed = '' then
    Exit; { Fresh install — proceed normally }

  Cmp := CompareVersion(NewVer, Installed);

  if Cmp = 0 then
  begin
    { ── Same version ───────────────────────────────────────────────── }
    MsgBox(
      '{#MyAppName} ' + Installed + ' is already installed on this computer.' + #13#10 +
      'To reinstall, please uninstall the current version first.',
      mbInformation, MB_OK);
    Result := False;
  end
  else if Cmp > 0 then
  begin
    { ── Upgrading to a newer version ─────────────────────────────── }
    Result := MsgBox(
      '{#MyAppName} ' + Installed + ' is currently installed.' + #13#10 +
      'This will update it to version ' + NewVer + '.' + #13#10#13#10 +
      'Your settings and data will be preserved.' + #13#10#13#10 +
      'Continue with the update?',
      mbConfirmation, MB_YESNO or MB_DEFBUTTON1) = IDYES;
  end
  else
  begin
    { ── Downgrading to an older version ──────────────────────────── }
    Result := MsgBox(
      '{#MyAppName} ' + Installed + ' is currently installed.' + #13#10 +
      'You are about to install an older version (' + NewVer + ').' + #13#10#13#10 +
      'WARNING: To prevent compatibility issues this will:' + #13#10 +
      '  ' + #183 + '  Remove the current installation' + #13#10 +
      '  ' + #183 + '  Delete all app settings and local data' + #13#10#13#10 +
      'This cannot be undone. Do you want to continue?',
      mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES;
  end;
end;

{ Override the default install directory with the previous install location. }
function GetPreviousInstallDir(Default: String): String;
var
  Loc: String;
begin
  Loc := GetInstalledLocation;
  if (Loc <> '') and DirExists(Loc) then
    Result := Loc
  else
    Result := Default;
end;

{ ── Install step ─────────────────────────────────────────────────────── }

procedure WipeAppData;
var
  Path: String;
begin
  { %APPDATA% — Hive, SharedPreferences, Drift database }
  Path := ExpandConstant('{userappdata}\{#MyAppDataDir}');
  if DirExists(Path) then DelTree(Path, True, True, True);

  { %LOCALAPPDATA% — fallback location used by some path_provider versions }
  Path := ExpandConstant('{localappdata}\{#MyAppDataDir}');
  if DirExists(Path) then DelTree(Path, True, True, True);
end;

procedure SilentUninstall;
var
  UninstStr: String;
  P, Code:   Integer;
begin
  UninstStr := GetUninstallString;
  if UninstStr = '' then Exit;

  { Strip surrounding quotes, then isolate the exe path from any extra args }
  UninstStr := RemoveQuotes(Trim(UninstStr));
  P := Pos(' /', UninstStr);
  if P > 0 then UninstStr := TrimRight(Copy(UninstStr, 1, P - 1));

  if FileExists(UninstStr) then
    Exec(UninstStr, '/SILENT /NORESTART', '', SW_HIDE, ewWaitUntilTerminated, Code);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Installed, NewVer: String;
  Cmp: Integer;
begin
  if CurStep <> ssInstall then Exit;

  Installed := GetInstalledVersion;
  if Installed = '' then Exit; { Nothing installed — nothing to do }

  NewVer := '{#AppVersion}';
  Cmp    := CompareVersion(NewVer, Installed);

  if Cmp < 0 then
  begin
    { Downgrade: wipe user data BEFORE uninstalling the old version }
    WipeAppData;
  end;

  { For both upgrades and downgrades: silently remove the old installation
    so the new installer has a clean slate to write into. }
  SilentUninstall;
end;

{ ── Directory initialisation ─────────────────────────────────────────── }

procedure InitializeWizard;
begin
  { Point the install-dir page at the existing location if one is found }
  WizardForm.DirEdit.Text := GetPreviousInstallDir(ExpandConstant('{autopf}\{#MyAppName}'));
end;
