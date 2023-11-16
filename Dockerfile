# clamav offical package is for x86_64 or i386.
FROM --platform=linux/x86_64 amazonlinux:2023

# Set up working directories
RUN mkdir -p /opt/app
RUN mkdir -p /opt/app/build
RUN mkdir -p /opt/app/bin/

# Install packages
RUN yum update -y

# python 3.11
RUN mkdir -p /home
WORKDIR /home
RUN yum install -y cpio yum-utils zip unzip less \
    openssl openssl-devel wget tar xz gcc make zlib-devel
RUN wget -c https://www.python.org/ftp/python/3.11.6/Python-3.11.6.tar.xz
RUN tar -Jxvf Python-3.11.6.tar.xz
WORKDIR /home/Python-3.11.6
RUN ./configure --enable-optimizations --with-ensurepip
RUN make
RUN make install

# Copy in the lambda source
WORKDIR /opt/app
COPY ./*.py /opt/app/
COPY requirements.txt /opt/app/requirements.txt

# This had --no-cache-dir, tracing through multiple tickets led to a problem in wheel
RUN pip3 install -r requirements.txt
RUN rm -rf /root/.cache/pip

# Download libraries we need to run in lambda
WORKDIR /tmp
RUN wget https://www.clamav.net/downloads/production/clamav-1.0.4.linux.x86_64.rpm
RUN rpm2cpio clamav-1.0.4.linux.x86_64.rpm | cpio -idmv

# Copy over the binaries and libraries
RUN cp -rp /tmp/usr/local/bin/clamscan /tmp/usr/local/bin/freshclam /tmp/usr/local/lib64/* /opt/app/bin/

# Fix the freshclam.conf settings
RUN echo "DatabaseMirror database.clamav.net" > /opt/app/bin/freshclam.conf
RUN echo "CompressLocalDatabase yes" >> /opt/app/bin/freshclam.conf

# Create the zip file
WORKDIR /opt/app
RUN zip -r9 --exclude="*test*" /opt/app/build/lambda.zip *.py bin

WORKDIR /usr/local/lib/python3.11/site-packages
RUN zip -r9 /opt/app/build/lambda.zip *

WORKDIR /opt/app
