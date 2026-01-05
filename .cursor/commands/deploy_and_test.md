# installation
**IMPORTANT** if file infobasesettings.md does not exists - create it with following info:
1) Ask connection for infobase. In this example 'C:\Users\filippov.o\Documents\InfoBase12' 
2) Ask infobase publish URL. In this file it http://localhost/TestForms/ru/ 


# setings usage
1) In commands below replace infobase connection with read from infobasesettings.md. Don't forget to use /S for server infobase and /F for file
2) replace 'http://localhost/TestForms/ru/' url to url read from infobasesettings.md. If URL not set - just skip testing
3) E:\Temp\Update.log - just put update log whereever it comfortable
4) E:\newformsgen - replace it with current project root directory


# testing and deployment
## to update infobase before testing use following commands:
**Step 1 - Load config to base:**

```powershell
& 'C:\Program Files\1cv8\8.3.23.1997\bin\1cv8.exe' DESIGNER /F 'C:\Users\filippov.o\Documents\InfoBase12' /DisableStartupMessages /LoadConfigFromFiles E:\newformsgen /Out E:\Temp\Update.log
```

Read `E:\Temp\Update.log` to confirm success.

Wait 5-10 seconds

**Step 2 - Update database structure:**

```powershell
& 'C:\Program Files\1cv8\8.3.23.1997\bin\1cv8.exe' DESIGNER /F 'C:\Users\filippov.o\Documents\InfoBase12' /DisableStartupMessages /UpdateDBCfg -Dynamic+ -SessionTerminate force /Out E:\Temp\Update.log
```

Read `E:\Temp\Update.log` to confirm success.

## to test infobase use following URL and rules:

http://localhost/TestForms/ru/
**IMPORTANT** ALWAYS USE **human-like typing** simulation with **DELAY** to fill values during testing
you can use TAB to select form field