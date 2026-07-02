' NeuroSeg Pro v4.0.0 Silent Application Launcher
' Eliminates command prompt windows while properly configuring Python virtual environment paths in LocalAppData

Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

' Determine application root directory
AppDir = fso.GetParentFolderName(WScript.ScriptFullName)
WshShell.CurrentDirectory = AppDir

LocalAppDataDir = WshShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\NeuroSegPro"
ActivePathFile = LocalAppDataDir & "\active_venv.path"

VenvDir = LocalAppDataDir & "\.venv"
If fso.FileExists(ActivePathFile) Then
    Set ts = fso.OpenTextFile(ActivePathFile, 1)
    If Not ts.AtEndOfStream Then
        CustomPath = Trim(ts.ReadLine())
        If CustomPath <> "" And fso.FolderExists(CustomPath) Then
            VenvDir = CustomPath
        End If
    End If
    ts.Close
End If

PythonwExe = VenvDir & "\Scripts\pythonw.exe"
TokenFile = LocalAppDataDir & "\.runtime_verified"

' Check if runtime components exist and completed verification
If Not fso.FileExists(PythonwExe) Or Not fso.FileExists(TokenFile) Then
    MsgText = "NeuroSeg Pro runtime setup did not finish successfully or components are missing." & vbCrLf & vbCrLf & _
              "Would you like to launch the automated Repair Tool now?"
    Ans = MsgBox(MsgText, vbYesNo + vbExclamation, "NeuroSeg Pro Runtime Incomplete")
    If Ans = vbYes Then
        RepairCmd = "powershell.exe -ExecutionPolicy Bypass -NoProfile -File """ & AppDir & "\install.ps1"" -Repair"
        WshShell.Run RepairCmd, 1, False
    End If
    WScript.Quit 0
End If

' Configure environment variables
WshShell.Environment("PROCESS")("PYTHONPATH") = AppDir
WshShell.Environment("PROCESS")("KMP_DUPLICATE_LIB_OK") = "TRUE"
WshShell.Environment("PROCESS")("TF_ENABLE_ONEDNN_OPTS") = "0"
WshShell.Environment("PROCESS")("PATH") = VenvDir & "\Scripts;" & VenvDir & "\Lib\site-packages\PyQt5\Qt5\bin;" & WshShell.Environment("PROCESS")("PATH")

' Check if arguments were passed (e.g., file association launch)
ArgsStr = ""
If WScript.Arguments.Count > 0 Then
    For i = 0 To WScript.Arguments.Count - 1
        ArgsStr = ArgsStr & " """ & WScript.Arguments(i) & """"
    Next
End If

' Launch pythonw executable silently (window style 0 = hidden console)
MainScript = """" & AppDir & "\app\main.py"""
WshShell.Run """" & PythonwExe & """ " & MainScript & ArgsStr, 0, False
