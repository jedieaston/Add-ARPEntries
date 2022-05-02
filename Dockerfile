# On Windows 10? Change the image to mcr.microsoft.com/windows:20H2
FROM mcr.microsoft.com/windows/server:ltsc2022 as wingettest
USER ContainerAdministrator
WORKDIR C:\\wingetdev\\
# Make sure Edge won't change the ARP table at runtime.
ADD ["EdgeBlocker.cmd", "EdgeBlocker.cmd"]
RUN cmd /c EdgeBlocker.cmd /B
RUN powershell -Command "Set-Service edgeupdate -Status stopped -StartupType disabled ; Set-Service edgeupdatem -Status stopped -StartupType disabled"

ADD [ "https://aka.ms/vs/16/release/vc_redist.x64.exe", "C:\\" ]
RUN C:\vc_redist.x64.exe /install /passive /norestart /log C:\TEMP\vc_redist.log
ADD ["https://github.com/jedieaston/winget-build/releases/latest/download/wingetdev.zip", "C:\\"]
RUN powershell -Command "Expand-Archive -LiteralPath C:\wingetdev.zip -DestinationPath C:\wingetdev\ -Force ; mv C:\\wingetdev\\AppInstallerCLI\\* C:\\wingetdev\\"
ADD ["Bootstrap.ps1", "Bootstrap.ps1"]
RUN wingetdev.exe settings --Enable LocalManifestFiles 
ENTRYPOINT ["powershell", "-File", "Bootstrap.ps1"]