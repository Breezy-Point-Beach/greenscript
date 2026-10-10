Attribute VB_Name = "GreenScript"
' GreenScript.bas - VBA primitives for driving a BlueZone session from
' BlueZone VBA or Excel/Access VBA.
'
' Copyright 2026 Breezy Point Beach, LLC
' Licensed under the MIT License
'
' This module is the VBA counterpart to the PowerShell cmdlets in
' ../powershell/. It exposes a thin wrapper around BZWhll.WhllObj plus an
' approval-gated SendKey and a JSONL audit log.
'
' Install
'   BlueZone VBA:  Session menu > Macros > Visual Basic Editor >
'                  File > Import File... > select this .bas.
'   Excel VBA:     Alt+F11 > File > Import File... > select this .bas.
'
' Example
'   Dim s As Object
'   Set s = GsConnect("")                          ' active session
'   Debug.Print GsRead(s, 1, 1, 80)                ' first row, 80 chars
'   GsSend s, "WAQ<Enter>", True                   ' with approval prompt
'   Dim ok As Boolean
'   ok = GsWait(s, "Work a Quote", 1, 1, 10)
'   GsDisconnect s

Option Explicit

' --- forbidden keys ---------------------------------------------------------
Private Const GS_FORBIDDEN As String = "<F3>|<F5>|<SF6>"

' --- public API -------------------------------------------------------------

' GsConnect: returns a dictionary-like Object with Tag, Rows, Cols, Host.
Public Function GsConnect(Optional ByVal sessionName As String = "", _
                          Optional ByVal rows As Long = 24, _
                          Optional ByVal cols As Long = 80) As Object
    Dim host As Object, s As Object
    Set host = CreateObject("BZWhll.WhllObj")
    host.Connect sessionName
    Set s = CreateObject("Scripting.Dictionary")
    s.Add "Tag", IIf(Len(sessionName) = 0, "<active>", sessionName)
    s.Add "Rows", rows
    s.Add "Cols", cols
    s.Add "Host", host
    GsAudit s, "connect", "sessionName=" & sessionName & " rows=" & rows & " cols=" & cols, "", True, ""
    Set GsConnect = s
End Function

Public Sub GsDisconnect(ByVal s As Object)
    On Error Resume Next
    s("Host").Disconnect
    On Error GoTo 0
    GsAudit s, "disconnect", "", "", True, ""
End Sub

' GsRead: returns the characters at (row, col) for 'length' chars.
Public Function GsRead(ByVal s As Object, ByVal row As Long, _
                       Optional ByVal col As Long = 1, _
                       Optional ByVal length As Long = 0) As String
    Dim buf As String, L As Long
    L = length
    If L <= 0 Then L = s("Cols") - (col - 1)
    buf = Space(L)
    s("Host").ReadScreen buf, L, row, col
    If Len(buf) > L Then buf = Left$(buf, L)
    GsRead = buf
    GsAudit s, "read", "row=" & row & " col=" & col & " length=" & L, _
            "chars=" & Len(buf), True, ""
End Function

' GsReadAll: returns all rows joined by vbCrLf.
Public Function GsReadAll(ByVal s As Object) As String
    Dim out As String, r As Long
    For r = 1 To s("Rows")
        out = out & GsRead(s, r) & vbCrLf
    Next r
    GsReadAll = out
End Function

' GsCursor: returns row and col in two ByRef parameters.
Public Sub GsCursor(ByVal s As Object, ByRef row As Long, ByRef col As Long)
    row = 0: col = 0
    s("Host").GetCursor row, col
    GsAudit s, "cursor", "", "row=" & row & " col=" & col, True, ""
End Sub

' GsSend: sends keys. If requestApproval is True, prompts via MsgBox (modal).
' If the keys contain any forbidden token, the prompt is forced regardless.
Public Function GsSend(ByVal s As Object, ByVal keys As String, _
                       Optional ByVal requestApproval As Boolean = True) As Boolean
    Dim mustPrompt As Boolean, hit As String
    hit = ContainsForbidden(keys)
    mustPrompt = requestApproval Or (Len(hit) > 0)

    If mustPrompt Then
        Dim msg As String
        msg = "Send to session " & s("Tag") & ":" & vbCrLf & vbCrLf & _
              "    " & keys & vbCrLf & vbCrLf
        If Len(hit) > 0 Then
            msg = msg & "WARNING: contains " & hit & " which may be destructive." & vbCrLf & vbCrLf
        End If
        msg = msg & "Proceed?"
        If MsgBox(msg, vbYesNo + vbQuestion + IIf(Len(hit) > 0, vbDefaultButton2, vbDefaultButton1), _
                 "GreenScript - Confirm SendKey") <> vbYes Then
            GsAudit s, "send", "keys=" & keys & " forbidden=" & hit, _
                    "canceled=true", True, ""
            GsSend = False
            Exit Function
        End If
    End If

    s("Host").SendKey keys
    GsAudit s, "send", "keys=" & keys & " forbidden=" & hit, _
            "sent=true", True, ""
    GsSend = True
End Function

' GsWait: returns True if text appears at (row, col) within timeoutSeconds.
Public Function GsWait(ByVal s As Object, ByVal text As String, _
                       ByVal row As Long, ByVal col As Long, _
                       Optional ByVal timeoutSeconds As Long = 10) As Boolean
    Dim code As Long
    code = s("Host").WaitForText(text, row, col, timeoutSeconds)
    GsWait = (code = 0)
    GsAudit s, "wait", "text=" & text & " row=" & row & " col=" & col & _
            " timeoutSeconds=" & timeoutSeconds, _
            "found=" & GsWait & " code=" & code, True, ""
End Function

' --- audit log --------------------------------------------------------------

Private Sub GsAudit(ByVal s As Object, ByVal action As String, _
                    ByVal args As String, ByVal result As String, _
                    ByVal ok As Boolean, ByVal errMsg As String)
    Dim fso As Object, ts As Object, line As String
    Dim path As String, dir As String, tag As String

    tag = "<none>"
    If Not s Is Nothing Then
        If s.Exists("Tag") Then tag = CStr(s("Tag"))
    End If

    dir = Environ$("LOCALAPPDATA") & "\GreenScript\logs"
    Set fso = CreateObject("Scripting.FileSystemObject")
    If Not fso.FolderExists(dir) Then
        On Error Resume Next
        fso.CreateFolder Environ$("LOCALAPPDATA") & "\GreenScript"
        fso.CreateFolder dir
        On Error GoTo 0
    End If
    path = dir & "\greenscript-" & Format(Now, "yyyymmdd") & ".jsonl"

    ' Minimal JSON by hand; escape backslash and double-quote only.
    ' Local time (no Z suffix): VBA has no in-box UTC without Win32 calls.
    ' The backslash escapes the literal T in a VBA format string.
    line = "{""ts"":""" & Format(Now, "yyyy-mm-dd\Thh:nn:ss") & """" & _
           ",""session"":""" & JEsc(tag) & """" & _
           ",""action"":""" & JEsc(action) & """" & _
           ",""args"":""" & JEsc(args) & """" & _
           ",""result"":""" & JEsc(result) & """" & _
           ",""ok"":" & LCase(CStr(ok)) & _
           ",""user"":""" & JEsc(Environ$("USERNAME")) & """" & _
           ",""host"":""" & JEsc(Environ$("COMPUTERNAME")) & """"
    If Len(errMsg) > 0 Then line = line & ",""err"":""" & JEsc(errMsg) & """"
    line = line & "}"

    On Error Resume Next
    Set ts = fso.OpenTextFile(path, 8, True) ' ForAppending, create if missing
    ts.WriteLine line
    ts.Close
    On Error GoTo 0
End Sub

Private Function JEsc(ByVal v As String) As String
    JEsc = Replace(Replace(v, "\", "\\"), """", "\""")
End Function

Private Function ContainsForbidden(ByVal keys As String) As String
    Dim parts() As String, i As Long, found As String
    parts = Split(GS_FORBIDDEN, "|")
    For i = LBound(parts) To UBound(parts)
        If InStr(1, keys, parts(i), vbTextCompare) > 0 Then
            If Len(found) > 0 Then found = found & ","
            found = found & parts(i)
        End If
    Next i
    ContainsForbidden = found
End Function
