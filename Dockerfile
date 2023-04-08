FROM ubuntu:jammy AS crkit-media-base
ENV DEBIAN_FRONTEND="noninteractive"

# A word about HTTP_PROXY
# On systems that need to access a proxy to download packages, the build
# should be called with a build-arg that passes in the proxy to use.
#  A symptom that this is needed is that apt-get cannot access packages.
# This is not needed if building on a system that does not  use a proxy.
#
# To set the proxy variable from the build environment:
# docker build --build-arg HTTP_PROXY .
#

LABEL maintainer="warfield@crl.med.harvard.edu"
LABEL vendor="Computational Radiology Laboratory"

# Update the ubuntu.
RUN apt-get -y update && \
    apt-get -y upgrade

# FIX THE MISSING LOCALE in ubuntu
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y locales \
    && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && dpkg-reconfigure --frontend=noninteractive locales \
    && update-locale LANG=en_US.UTF-8

ENV LANG=en_US.UTF-8 
ENV LC_ALL=en_US.UTF-8

# Install the prerequisite software
RUN apt-get install -y build-essential \
                       apt-utils \
                       vim \
                       nano \
                       zlib1g-dev \
                       libncurses5-dev \
                       libgdbm-dev \
                       libnss3-dev \
                       libssl-dev \
                       libreadline-dev \
                       libffi-dev \
                       wget \
                       git \
                       perl \
                       python3-dev \
                       python3-pip \
                       libproj-dev \
                       gperf bison flex \
                       unzip zip \
                       cmake \
                       libgoogle-glog-dev libgflags-dev \
                       libatlas-base-dev \
                       libeigen3-dev \
                       libsuitesparse-dev \
                       libtbb2 libtbb2-dev \
                       libfreetype6-dev \
                       libfontconfig-dev \
                       libdouble-conversion-dev \
                       liblz4-dev liblzma-dev \
                       libnetcdf-dev libnetcdf-cxx-legacy-dev \
                       libogg-dev \
                       libtheora-dev \
                       libpng-dev \
                       libjpeg-dev \
                       libtiff-dev \
                       libjsoncpp-dev \
                       libexpat1-dev \
                       libglew-dev \
                       libhdf5-dev \
                       libxt-dev libxml2-dev \
                       libxcb-xinerama0 \
                       libxcb-xinerama0-dev \
                       libsqlite3-dev \
                       libswscale-dev \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install SimpleITK numpy flywheel-sdk

# Number of threads to use for build (--build-arg THREADS=8)
ARG THREADS

# Let's install packages in /opt as the default location.
# Now get ready to check out, build, and install key software.
WORKDIR /usr/src

# Sometimes git clone can fail due to a lack of buffer space.
# This fixes that problem.
ENV export GIT_HTTP_MAX_REQUEST_BUFFER=100M

RUN mkdir vtksrc && cd vtksrc && \
    git clone --single-branch --branch v9.2.2 https://gitlab.kitware.com/vtk/vtk.git && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=/opt/vtk \
      -DCMAKE_BUILD_TYPE:STRING=Release \
      -DBUILD_SHARED_LIBS:BOOL=ON \
      -DCMAKE_INSTALL_RPATH="${CMAKE_INSTALL_PREFIX}/lib" \
          -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE \
          -DVTK_BUILD_DOCUMENTATION=OFF \
          -DVTK_BUILD_TESTING=OFF \
          -DVTK_BUILD_EXAMPLES=OFF \
          -DBUILD_USER_DEFINED_LIBS:BOOL=OFF \
          -DVTK_LEGACY_REMOVE=ON \
          -DVTK_ANDROID_BUILD=OFF \
          -DVTK_IOS_BUILD=OFF \
          -DVTK_EXTRA_COMPILER_WARNINGS=OFF \
          -DVTK_GROUP_ENABLE_Views=NO \
          -DVTK_GROUP_ENABLE_Web=NO \
          -DVTK_GROUP_ENABLE_Imaging=NO \
          -DVTK_GROUP_ENABLE_Qt=DONT_WANT \
          -DVTK_GROUP_ENABLE_Rendering=DONT_WANT \
          -DVTK_PYTHON_VERSION=3 \
          -DVTK_ENABLE_WRAPPING=ON \
          -DVTK_WRAP_PYTHON=ON \
          -DVTK_WRAP_JAVA=OFF \
          -DVTK_USE_LARGE_DATA=OFF \
    ../vtk && \
    make -j 4 && make install && \
    cd /usr/src && \
    rm -rf /usr/src/vtksrc

ENV VTK_INSTALL_DIR=/opt/vtk
ENV VTK_DIR=${VTK_INSTALL_DIR}/lib/cmake/vtk-9.2

# ----- Start another clean build without all of the build dependencies
# This makes a smaller docker image.
FROM ubuntu:jammy AS crkit-vtk

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 python3-pip vim nano && \
    apt-get clean && rm -rf /var/lib/apt/lists/* 


# Copy from the build version and re-add necessary dependencies.
# copy only relevant directories with binaries and .so files for crkit
COPY --from=crkit-base /opt/vtk /opt/vtk

# reset ENV variables that are relevant in the new image
ENV VTK_INSTALL_DIR=/opt/vtk
ENV VTK_DIR=${VTK_INSTALL_DIR}/lib/cmake/vtk-9.2

# DEFAULT entrypoint can be changed with --entrypoint
# ENTRYPOINT ["/bin/sh", "-c", "bash"]

# DEFAULT CMD provides a list of binaries.
ENV msg="\nList of available binaries in /opt/vtk/bin\n"
CMD echo $msg; find /opt/vtk/bin -type f -name "*"; echo $msg

# Assume user data volume to be mounted at /data
#   docker run --volume=/path/to/data:/data
WORKDIR /data

