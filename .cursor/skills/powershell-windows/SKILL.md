---
name: powershell-windows
description: "PowerShell scripting rules for Windows environment. Use when running shell commands, Docker operations, or HTTP requests on Windows PowerShell."
---

# PowerShell Windows — Scripting Rules

Essential rules for correct PowerShell usage on Windows. Follow these rules to avoid common errors when executing shell commands.

## Core Principles

### 1. Command Separation
- **Wrong**: `cd "path" && command` (bash syntax)
- **Correct**: `cd "path"; command` (PowerShell syntax)

### 2. Path Quoting
- **Always use double quotes** for paths with spaces:
  ```powershell
  cd "D:\My Projects\MyApp"
  ```

### 3. Script Execution
- For .bat/.cmd files:
  ```powershell
  ./gradlew clean build
  .\gradlew.bat clean build
  ```

### 4. Docker Commands
- Specify full path to docker-compose files:
  ```powershell
  docker-compose -f "D:\My Projects\app\docker-compose.yml" up -d
  ```

### 5. HTTP Requests
- **Wrong**: `curl -s http://localhost:9090/status`
- **Correct**:
  ```powershell
  Invoke-WebRequest -Uri "http://localhost:9090/status" -UseBasicParsing
  ```

### 6. Waiting/Delays
- **Wrong**: `timeout 10`
- **Correct**:
  ```powershell
  Start-Sleep -Seconds 10
  ```

### 7. JSON Handling
- JSON parsing:
  ```powershell
  $response = Invoke-WebRequest -Uri "http://localhost:9090/status" -UseBasicParsing
  $json = $response.Content | ConvertFrom-Json
  $json | ConvertTo-Json -Depth 3
  ```

### 8. Process Checking
- Process search:
  ```powershell
  Get-Process -Name "java" -ErrorAction SilentlyContinue
  ```

### 9. Docker Operations
- Stop containers:
  ```powershell
  docker-compose -f "path\to\file.yml" down
  ```
- Build images:
  ```powershell
  docker-compose -f "path\to\file.yml" build --no-cache
  ```

### 10. Error Handling
- Ignore errors:
  ```powershell
  Get-Process -Name "java" -ErrorAction SilentlyContinue
  ```

## Common Errors and Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `&& is not recognized` | Using bash syntax | Replace `&&` with `;` |
| `curl not found` | curl not installed on Windows | Use `Invoke-WebRequest` |
| `timeout not found` | timeout not supported | Use `Start-Sleep` |
| `Path not found` | Missing quotes on spaced path | Wrap path in double quotes |

## Correct Command Examples

```powershell
# Change directory and execute command
cd "D:\My Projects\MyApp"; ./gradlew clean build -x test

# Wait and make HTTP request
Start-Sleep -Seconds 10; Invoke-WebRequest -Uri "http://localhost:9090/status" -UseBasicParsing

# Docker operations
docker-compose -f "D:\My Projects\MyApp\docker-compose.yml" down
docker-compose -f "D:\My Projects\MyApp\docker-compose.yml" build --no-cache
docker-compose -f "D:\My Projects\MyApp\docker-compose.yml" up -d

# Check server status
$response = Invoke-WebRequest -Uri "http://localhost:9090/status" -UseBasicParsing
$json = $response.Content | ConvertFrom-Json
Write-Host "Transport: $($json.mcp.transport)"
```

These rules are critically important for proper operation in Windows PowerShell environment.
