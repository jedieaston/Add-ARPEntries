# Add-ARPEntries.ps1!


Want to be a good citizen of the [Windows Package Manager Community Repository](https://github.com/microsoft/winget-pkgs) and add Add and Remove Programs entries for all of your apps, but don't know where to start? This script will automatically get them for all of the installers listed in a manifest (unless they run on ARM64 :D) using the magic of [Windows Containers](https://docs.microsoft.com/en-us/virtualization/windowscontainers/about/)

## How to use
0. Do you have Docker Desktop installed (`winget install -s winget Docker.DockerDesktop`) and [configured for Windows Containers](https://docs.microsoft.com/en-us/virtualization/windowscontainers/quick-start/set-up-environment?tabs=Windows-10-and-11)? If not, come back after you do that.
1. Run `docker build . -t wingettest` in the root of the repository to build the container image (at some point I'll set up CI, but that day is not today).
2. To add ARP entries to a manifest, run `.\Add-ARPEntries.ps1 <path to manifest>`, and wait for it to finish. It's that easy (in the best case!)

(Note: many applications don't behave correctly when they are running in a headless Windows environment, much less a headless Windows environment sharing resources with real Windows. Most installers should work enough to get ARP entries, but in some cases you'll want to do this in a Sandbox or a real VM.)

## Notes
- ARM64 support for Windows Containers [doesn't exist](https://github.com/docker/for-win/issues/5013). Since winget throws a non-zero code when it can't find a matching installer for your system, the script skips over ARM64 installer entries.
- EdgeBlocker.cmd is used to disable Edge's autoupdater in the container image, since if it runs it can change the Add and Remove Programs table and mess with the diff.
- AppX/MSIX aren't supported yet, but they will be.
- winget.exe doesn't usually work in a container [at all](https://github.com/microsoft/winget-cli/issues/1474), so this container uses the nightlys from https://github.com/jedieaston/winget-build, which are just loose executables that can run in a container, or over SSH, or wherever. They are nightlies, so there's a possibility of instability, but there haven't been many issues lately.
