# Install-RE5Patch

## Features

- Will download the latest community patch from [sb-online](htttp://www.sb-online.org/maluc/index.php?did=bh5fixes)
- Supports any install location (not just the default)
  - Checks the registry first and will search the default Steam install location and then check any library paths
- Creates a backup of all files that are going to be replaced
- Logging
- Cleans up the downloaded and extracted files automatically

## Instructions

1. <a href="https://gist.githubusercontent.com/syntax-tm/ae66f0d68dc6604e79a200632a4cc821/raw/Install-RE5Patch.ps1" download>Click to Download</a>
2. Right-click and select '`Save As...`'
3. Change the '`Save as type`' to '`All Files (*.*)`'
4. Open the file in `Windows Explorer`
5. Right-click the file and select '`Run With Powershell`'

## Unblocking File

If you're unable to run the script, you probably have security settings blocking it. To unblock the file, you can follow these steps:

1. Browse to the file using `Windows Explorer`
2. Right-click the file and select Properties
3. On the `General` tab, under `Security`, click the `Unblock` checkbox
4. Click `OK`

### Unblocking File (via Powershell)

If you want to unblock it via `Powershell` you can use the Unblock-File cmdlet.

```powershell
Unblock-File 'Install-RE5Patch.ps1'
```

Alternatively, you can also set the `ExecutionPolicy` to '`Bypass`' for the current session.

```powershell
Set-ExecutionPolicy Bypass -Scope Process
.\Install-RE5Patch.ps1
```

## Help

If you run into any issues you can contact me on Steam [here](https://steamcommunity.com/id/Gundwn).
