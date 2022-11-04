Sub Resize()
     window.resizeTo 1500,1000
End Sub

Sub Test()
     Dim sCmd, iResult, sResultData, sTargets, sPorts, sResultsTxtFile,oFile
     'Collect value from input form
     sTargets = document.getElementByID("targets").Value
     sPorts = document.getElementByID("ports").Value
     'Check user has inputed data
     If sTargets = "" Or sPorts = "" Then
          MsgBox "Please enter something in the input form"
          Exit Sub
     End If
                    
     'Set command to call PowerShell script
     sCmd = "powershell.exe -File UDPPortTest.ps1 -targets "&Chr(39)&sTargets&Chr(39)&"-ports "&Chr(39)&sPorts&Chr(39)
                    
     'Call PowerShell script
     Set oShell = CreateObject("Wscript.Shell")
     iResult = oShell.Run(sCmd, 0, true)
                    
     'Collect result from PowerShell (via clipboard)
     sResultsTxtFile = "tmp/out.txt"
     Set oFSO = CreateObject("Scripting.FileSystemObject")
     if(oFSO.FileExists(sResultsTxtFile)) then
          Set oFile = oFSO.OpenTextFile(sResultsTxtFile, 1)
          Do Until oFile.AtEndOfStream
               sResultData = sResultData & oFile.ReadLine
          Loop
          oFile.Close
          RemoveFile(sResultsTxtFile)
     end if

     document.getElementByID("result_id").innerHTML = "<textarea readonly rows="&Quote&"5"&Quote&"cols="&Quote&"1000"&Quote&" class="&Quote&"resultTextArea"&Quote&">"&sResultData&"</textarea>"

End Sub

Sub RemoveFile(filepath)
     dim filesys 
     Set filesys = CreateObject("Scripting.FileSystemObject")
     If filesys.FileExists(filepath) Then 
          filesys.DeleteFile filepath
     End If
End Sub