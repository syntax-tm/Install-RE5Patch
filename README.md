# Install-RE5Patch

To run the PowerShell script from Command Prompt copy and paste the following:

```bat
@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "[System.Net.ServicePointManager]::SecurityProtocol = 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://tinyurl.com/RE5PatchInstall'))"
```

The [tinyurl](https://tinyurl.com) is a shorted link to `https://gist.githubusercontent.com/syntax-tm/ae66f0d68dc6604e79a200632a4cc821/raw/bb00e18d5ee2b4c4666ef6f580028f187d7a901e/Install-RE5Patch.ps1`. It's just meant to be more readable.

If you want to make changes to or inspect the install script you can view/download the `Install-RE5Patch.ps1` PowerShell script.

If you run into any issues you can contact me on Steam [here](https://steamcommunity.com/id/Gundwn).
