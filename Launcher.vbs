Set objArgs = WScript.Arguments
Set objFSO = CreateObject("Scripting.FileSystemObject")
strDir = objFSO.GetParentFolderName(WScript.ScriptFullName)

If objArgs.Count > 0 Then
    strScript = objArgs(0)
Else
    strScript = strDir & "\Monitor.ps1"
End If

Set objShell = CreateObject("WScript.Shell")
objShell.Run "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -NoProfile -File """ & strScript & """", 0, False
