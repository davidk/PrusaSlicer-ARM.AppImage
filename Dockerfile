# Dockerfile for automated, contained builds. 
# Requires the installation of Docker or Podman.
#
# Usage (replace podman for docker as needed): 
# $ git clone https://github.com/davidk/PrusaSlicer-ARM.AppImage
# $ podman build -t psbuilder . 
# $ podman run -it -v $PWD:/ps:z psbuilder
# AppImage files should be written to your directory
FROM docker.io/balenalib/raspberrypi4-64

RUN apt-get update && apt-get install -y wget git

WORKDIR /ps

CMD ["./build.sh","automated"]
