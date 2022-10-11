# On Windows 10? Change the image to mcr.microsoft.com/windows:20H2
FROM mcr.microsoft.com/windows/server:ltsc2022 as wingettest
USER ContainerAdministrator
WORKDIR C:\\wingetdev
ADD "https://aka.ms/vs/16/release/vc_redist.x64.exe" "C:\\"
ADD "https://github.com/jedieaston/winget-build/releases/latest/download/wingetdev.zip" "C:\\"
ADD "Bootstrap.ps1", "Bootstrap.ps1"
SHELL [ "powershell", "-Command" ]
RUN C:\vc_redist.x64.exe /install /passive /norestart /log C:\TEMP\vc_redist.log
RUN Expand-Archive -LiteralPath C:\\wingetdev.zip -DestinationPath .\ -Force ; mv C:\\wingetdev\\AppInstallerCLI\\* C:\\wingetdev
RUN .\wingetdev.exe settings --Enable LocalManifestFiles 
# Make sure Edge won't change the ARP table at runtime.
RUN wingetdev.exe install -s winget Microsoft.Edge
RUN New-Item -Path HKLM:\\SOFTWARE\\Microsoft\\EdgeUpdate -Force
RUN New-ItemProperty -Path HKLM:\\SOFTWARE\\Microsoft\\EdgeUpdate -Name DoNotUpdateToEdgeWithChromium -Value 1 -PropertyType DWord -Force
RUN Remove-Item -Force -Recurse 'C:\\Program Files (x86)\\Microsoft\\EdgeUpdate\\'
RUN Set-Service -Name edgeupdate -Status Stopped -StartupType Disabled # stop edgeupdate service
RUN Set-Service -Name edgeupdatem -Status Stopped -StartupType Disabled # stop edgeupdatem service
ENTRYPOINT ["powershell", "-File", "Bootstrap.ps1"]
