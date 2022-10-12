# On Windows 10? Change the image to mcr.microsoft.com/windows:20H2
FROM mcr.microsoft.com/windows/server:ltsc2022 as wingettest
USER ContainerAdministrator
WORKDIR C:\\wingetdev

# add files to working directory
ADD Bootstrap.ps1 .
ADD https://aka.ms/vs/16/release/vc_redist.x64.exe .
ADD https://github.com/jedieaston/winget-build/releases/latest/download/wingetdev.zip .

# Install vc_redist, enable local manifests in wingetdev
SHELL [ "powershell", "-Command" ]
RUN Expand-Archive -LiteralPath .\wingetdev.zip -DestinationPath . -Force ; Move-Item .\AppInstallerCLI\* .
RUN .\vc_redist.x64.exe /install /passive /norestart /log .\vc_redist.log
RUN .\wingetdev.exe settings --enable LocalManifestFiles

# Make sure Edge won't change the ARP table at runtime.
# RUN .\wingetdev.exe install -s winget Microsoft.Edge
RUN New-Item -Path HKLM:\\SOFTWARE\\Microsoft\\EdgeUpdate -Force
RUN New-ItemProperty -Path HKLM:\\SOFTWARE\\Microsoft\\EdgeUpdate -Name DoNotUpdateToEdgeWithChromium -Value 1 -PropertyType DWord -Force
RUN Set-Service -Name edgeupdate -Status Stopped -StartupType Disabled # stop edgeupdate service
RUN Set-Service -Name edgeupdatem -Status Stopped -StartupType Disabled # stop edgeupdatem service
RUN Remove-Item -Force -Recurse 'C:\\Program Files (x86)\\Microsoft\\EdgeUpdate\\'

ENTRYPOINT ["powershell", "-File", "Bootstrap.ps1"]
