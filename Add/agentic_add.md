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