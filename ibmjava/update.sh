#!/bin/bash
#
# (C) Copyright IBM Corporation 2016, 2019
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
set -eo pipefail

# Dockerfiles to be generated
version="8"
package="jre sdk sfj"
tools="maven"
arches="i386 ppc64le s390 s390x x86_64"
osver="ubuntu alpine rhel ubi ubi-min"

# sha256sum for the various versions, packages and arches
# Version 8 sums [DO NO EDIT THIS LINE]
declare -A jre_8_sums=(
	[version]="1.8.0_sr6fp25"
	[i386]="4778c7f8a899544ab7ace0777c909b25c9bfcb1ced326fac7dd7feface308e5e"
	[ppc64le]="cc69a3c2baadcaf23fa0dd3d334d98406a1df0e5a0899ea16b7185807adb6f66"
	[s390]="2d15b35966d94c86227f32f90e9fe2ffdea76e1c355cb12276097318dfdf2841"
	[s390x]="683164578e9c4b0e6a3b6d2c56fc4b68f4a07f0c4183b522cdae4dbca8f4e092"
	[x86_64]="c613955f0130f9e637806f71660c6308e37e2e9abd8456e8216bc7de9eb9ea54"
)

declare -A sdk_8_sums=(
	[version]="1.8.0_sr6fp25"
	[i386]="aedc0bf42ad9dac10e789c8fb8984250d338cbe111683c75c3b5b87f36a9f40a"
	[ppc64le]="f0db52030e38d18d087138c7eea628975af034e381afda101b35d568e0a81230"
	[s390]="fb4cfdab31d39f060d32a9aa349ae4bd5e12e76164ab938d476e6fe864af7776"
	[s390x]="9357f54317ad62ea4223edcb2d0ca44dbdc153877b6ef077f21fbf462b8288f5"
	[x86_64]="066ce6f0b3fe7f9c84e41b4e63f36e83928f7166f7805633741b95dbfd4a1871"
)

declare -A sfj_8_sums=(
	[version]="1.8.0_sr6fp25"
	[i386]="30b441dfe3b7aed59b79d8691254ffe55a94f5f63252e391acce5eacacd78b54"
	[ppc64le]="949e84ece359b09412a6a43b78fcc91b1bf605321db6e9bb19cfc7eb727eb270"
	[s390]="ff1b146367ae61869e342fb6b73c40ad966f199f854bb301ede6d06743f20b14"
	[s390x]="6893eb2913f25c593e4a9d8249e53f0287b4b210f22b331a9eebd6927fcec286"
	[x86_64]="3188a3690c66210b1c2e40cd7dd30f09fd2ed359a37097ff252f28f13035678e"
)

# Version 9 sums [DO NO EDIT THIS LINE]
declare -A sdk_9_sums=(
	[version]="1.9.0_ea2"
	[i386]="5add39cc5ca56b97cf8ce71b9e1a15d19d36864aaed1e0296f50355ba3f34bd5"
	[ppc64le]="3c0dda9f449a667d12fe5f59a1ec059a90a9dc483fd35eef5ff53dd8b096cdf5"
	[s390]="8d06af57d8236839f5c403c12dcf4c89e22dd91716a4d26b85c8d92f6d1e2e8b"
	[s390x]="6e823afa1df83e364381f827f4244bfe29b0ddd58ef0203eb60df9b8c0d123af"
	[x86_64]="0fe3712b54a93695cf4948d9ae171bf5cef038c0e41b364b4e9eb7cb80a60688"
)

# Generate the common license and copyright header
print_legal() {
	cat > $1 <<-EOI
	# (C) Copyright IBM Corporation 2016, 2019
	#
	# ------------------------------------------------------------------------------
	#               NOTE: THIS DOCKERFILE IS GENERATED VIA "update.sh"
	#
	#                       PLEASE DO NOT EDIT IT DIRECTLY.
	# ------------------------------------------------------------------------------
	#
	# Licensed under the Apache License, Version 2.0 (the "License");
	# you may not use this file except in compliance with the License.
	# You may obtain a copy of the License at
	#
	#      http://www.apache.org/licenses/LICENSE-2.0
	#
	# Unless required by applicable law or agreed to in writing, software
	# distributed under the License is distributed on an "AS IS" BASIS,
	# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	# See the License for the specific language governing permissions and
	# limitations under the License.
	#

	EOI
}

# Print the supported Ubuntu OS
print_ubuntu_os() {
	cat >> $1 <<-EOI
	FROM ubuntu:18.04

	EOI
}

# Print the supported Alpine OS
print_alpine_os() {
	cat >> $1 <<-EOI
	FROM alpine:3.12

	EOI
}

# Print the supported RHEL OS
print_rhel_os() {
	cat >> $1 <<-EOI
	FROM registry.access.redhat.com/rhel7

	EOI
}

# Print the supported UBI Minimal OS
print_ubi-min_os() {
	cat >> $1 <<-EOI
	FROM registry.access.redhat.com/ubi8/ubi-minimal:8.2

	EOI
}

# Print the supported UBI Minimal OS
print_ubi_os() {
	cat >> $1 <<-EOI
	FROM registry.access.redhat.com/ubi8/ubi:8.2

	EOI
}

# Print the maintainer
print_maint() {
	cat >> $1 <<-EOI
	MAINTAINER Jayashree Gopi <jayasg12@in.ibm.com> (@jayasg12)
	EOI
}

# Select the ubuntu OS packages
print_ubuntu_pkg() {
	cat >> $1 <<'EOI'

RUN apt-get update \
    && apt-get install -y --no-install-recommends wget ca-certificates \
    && rm -rf /var/lib/apt/lists/*
EOI
}

# Select the alpine OS packages.
# Install GNU glibc as J9 needs it, install libgcc_s.so from gcc-libs.tar.xz (archlinux)
print_alpine_pkg() {
	cat >> $1 <<'EOI'

COPY sgerrand.rsa.pub /etc/apk/keys

RUN apk add --no-cache --virtual .build-deps curl binutils \
    && GLIBC_VER="2.30-r0" \
    && ALPINE_GLIBC_REPO="https://github.com/sgerrand/alpine-pkg-glibc/releases/download" \
    && GCC_LIBS_URL="https://archive.archlinux.org/packages/g/gcc-libs/gcc-libs-8.2.1%2B20180831-1-x86_64.pkg.tar.xz" \
    && GCC_LIBS_SHA256=e4b39fb1f5957c5aab5c2ce0c46e03d30426f3b94b9992b009d417ff2d56af4d \
    && curl -fLs https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub -o /tmp/sgerrand.rsa.pub \
    && cmp -s /etc/apk/keys/sgerrand.rsa.pub /tmp/sgerrand.rsa.pub \
    && curl -fLs ${ALPINE_GLIBC_REPO}/${GLIBC_VER}/glibc-${GLIBC_VER}.apk > /tmp/${GLIBC_VER}.apk \
    && apk add /tmp/${GLIBC_VER}.apk \
    && curl -fLs ${GCC_LIBS_URL} -o /tmp/gcc-libs.tar.xz \
    && echo "${GCC_LIBS_SHA256}  /tmp/gcc-libs.tar.xz" | sha256sum -c - \
    && mkdir /tmp/gcc \
    && tar -xf /tmp/gcc-libs.tar.xz -C /tmp/gcc \
    && mv /tmp/gcc/usr/lib/libgcc* /tmp/gcc/usr/lib/libstdc++* /usr/glibc-compat/lib \
    && strip /usr/glibc-compat/lib/libgcc_s.so.* /usr/glibc-compat/lib/libstdc++.so* \
    && apk del --purge .build-deps \
    && apk add --no-cache ca-certificates openssl \
    && rm -rf /tmp/${GLIBC_VER}.apk /tmp/gcc /tmp/gcc-libs.tar.xz /var/cache/apk/* /tmp/*.pub
EOI
}

# Select the rhel OS packages
print_rhel_pkg() {
	cat >> $1 <<'EOI'

RUN yum makecache fast \
    && yum update -y \
    && yum -y install openssl wget ca-certificates \
    && yum clean packages \
    && yum clean headers \
    && yum clean all \
    && rm -rf /var/cache/yum \
    && rm -rf /var/tmp/yum-*

EOI
}

# Select the ubi-min OS packages
print_ubi-min_pkg() {
	cat >> $1 <<'EOI'

RUN microdnf install openssl wget ca-certificates gzip tar \
    && microdnf update; microdnf clean all

EOI
}

# Select the ubi OS packages
print_ubi_pkg() {
	cat >> $1 <<'EOI'

RUN yum install -y wget openssl ca-certificates gzip tar \
    && yum update; yum clean all

EOI
}

# Print the Java version that is being installed here
print_env() {
	srcpkg=$2
	shasums="${srcpkg}"_"${ver}"_sums
	jverinfo=${shasums}[version]
	eval jver=\${$jverinfo}

	if [ "${os}" == "ubi-min" -o "${os}" == "ubi" ]; then
		cat >> $1 <<-EOI
LABEL org.opencontainers.image.authors="Jayashree Gopi <jayasg12@in.ibm.com>" \\
    name="IBM JAVA" \\
    vendor="IBM" \\
    version=${jver} \ 
    release=${ver} \\
    run="docker run --rm -ti <image_name:tag> /bin/bash" \\
    summary="Image for IBM JAVA with UBI as the base image" \\
    description="This image contains the IBM JAVA with Red Hat UBI as the base OS.  For more information on this image please see https://github.com/ibmruntimes/ci.docker/blob/master/README.md"
EOI
	fi
		cat >> $1 <<-EOI

ENV JAVA_VERSION ${jver}

EOI
}

# OS independent portion (Works for UBI, Alpine and Ubuntu)
# For Java 9 we use jlink to derive the JRE and the SFJ images.
print_java_install() {
	if [ "${os}" == "ubi" -o "${os}" == "ubi-min" ]; then
		cat >> $1 <<-EOI
       amd64|x86_64) \\
         ESUM='$(sarray=${shasums}[x86_64]; eval esum=\${$sarray}; echo ${esum})'; \\
         YML_FILE='${srcpkg}/linux/x86_64/index.yml'; \\
         ;; \\
       ppc64el|ppc64le) \\
         ESUM='$(sarray=${shasums}[ppc64le]; eval esum=\${$sarray}; echo ${esum})'; \\
         YML_FILE='${srcpkg}/linux/ppc64le/index.yml'; \\
         ;; \\
       s390x) \\
         ESUM='$(sarray=${shasums}[s390x]; eval esum=\${$sarray}; echo ${esum})'; \\
         YML_FILE='${srcpkg}/linux/s390x/index.yml'; \\
         ;; \\
       *) \\
         echo "Unsupported arch: \${ARCH}"; \\
         exit 1; \\
         ;; \\
    esac; \\
    BASE_URL="https://public.dhe.ibm.com/ibmdl/export/pub/systems/cloud/runtimes/java/meta/"; \\
EOI
	else
		cat >> $1 <<-EOI
       amd64|x86_64) \\
         ESUM='$(sarray=${shasums}[x86_64]; eval esum=\${$sarray}; echo ${esum})'; \\
         YML_FILE='${srcpkg}/linux/x86_64/index.yml'; \\
         ;; \\
       i386) \\
         ESUM='$(sarray=${shasums}[i386]; eval esum=\${$sarray}; echo ${esum})'; \\
         YML_FILE='${srcpkg}/linux/i386/index.yml'; \\
         ;; \\
       ppc64el|ppc64le) \\
         ESUM='$(sarray=${shasums}[ppc64le]; eval esum=\${$sarray}; echo ${esum})'; \\
         YML_FILE='${srcpkg}/linux/ppc64le/index.yml'; \\
         ;; \\
       s390) \\
         ESUM='$(sarray=${shasums}[s390]; eval esum=\${$sarray}; echo ${esum})'; \\
         YML_FILE='${srcpkg}/linux/s390/index.yml'; \\
         ;; \\
       s390x) \\
         ESUM='$(sarray=${shasums}[s390x]; eval esum=\${$sarray}; echo ${esum})'; \\
         YML_FILE='${srcpkg}/linux/s390x/index.yml'; \\
         ;; \\
       *) \\
         echo "Unsupported arch: \${ARCH}"; \\
         exit 1; \\
         ;; \\
    esac; \\
    BASE_URL="https://public.dhe.ibm.com/ibmdl/export/pub/systems/cloud/runtimes/java/meta/"; \\
EOI
	fi

	cat >> $1 <<'EOI'
    wget -q -U UA_IBM_JAVA_Docker -O /tmp/index.yml ${BASE_URL}/${YML_FILE}; \
    JAVA_URL=$(sed -n '/^'${JAVA_VERSION}:'/{n;s/\s*uri:\s//p}'< /tmp/index.yml); \
    wget -q -U UA_IBM_JAVA_Docker -O /tmp/ibm-java.bin ${JAVA_URL}; \
    echo "${ESUM}  /tmp/ibm-java.bin" | sha256sum -c -; \
    echo "INSTALLER_UI=silent" > /tmp/response.properties; \
    echo "USER_INSTALL_DIR=/opt/ibm/java" >> /tmp/response.properties; \
    echo "LICENSE_ACCEPTED=TRUE" >> /tmp/response.properties; \
    mkdir -p /opt/ibm; \
    chmod +x /tmp/ibm-java.bin; \
    /tmp/ibm-java.bin -i silent -f /tmp/response.properties; \
    rm -f /tmp/response.properties; \
    rm -f /tmp/index.yml; \
EOI
	if [ "${os}" == "ubi" -o "${os}" == "ubi-min" ]; then
		cat >> $1 <<'EOI'
    mkdir -p /licenses; \
    cp /opt/ibm/java/license_en.txt /licenses; \
    chown -R 1001:0 /opt/ibm/java; \
EOI
	fi
	if [ "${os}" == "ubi-min" ]; then
	        cat >> $1 <<'EOI'
    microdnf -y remove shadow-utils; \
    microdnf clean all; \
EOI
	fi

	# For Java 9 JRE, use jlink with the java.se.ee aggregator module.
	if [ "${ver}" == "9" ]; then
		if [ "${dstpkg}" == "jre" ]; then
			JCMD="rm -f /tmp/ibm-java.bin; \\
    cd /opt/ibm; \\
    ./java/bin/jlink -G --module-path ./java/jmods --add-modules java.se.ee --output jre; \\
    rm -rf java/*; \\
    mv jre java;"

		# For Java 9 SFJ, use jlink with sfj-exclude.txt.
		elif [ "${dstpkg}" == "sfj" ]; then
			JCMD="rm -f /tmp/ibm-java.bin; \\
    cd /opt/ibm; \\
    ./java/bin/jlink -G --module-path ./java/jmods --add-modules java.activation,java.base,java.compiler,java.datatransfer,java.desktop,java.instrument,java.logging,java.management,java.naming,java.prefs,java.rmi,java.security.jgss,java.security.sasl,java.sql,java.xml.crypto,java.xml,com.ibm.management --exclude-files=@/tmp/sfj-exclude.txt --output jre; \\
    rm -rf java/* /tmp/sfj-exclude.txt; \\
    mv jre java;"
		else
			JCMD="rm -f /tmp/ibm-java.bin;"
		fi

	# For other Java versions, nothing to be done.
	else
		JCMD="rm -f /tmp/ibm-java.bin;"
	fi

	cat >> $1 <<EOI
    ${JCMD}
EOI
}

# Print the main RUN command that installs Java on ubuntu.
print_ubuntu_java_install() {
	srcpkg=$2
	dstpkg=$3
	shasums="${srcpkg}"_"${ver}"_sums
	cat >> $1 <<'EOI'
RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "${ARCH}" in \
EOI
	print_java_install ${file} ${srcpkg} ${dstpkg};
}

# Print the main RUN command that installs Java on alpine.
print_alpine_java_install() {
	srcpkg=$2
	dstpkg=$3
	shasums="${srcpkg}"_"${ver}"_sums
	cat >> $1 <<'EOI'
RUN set -eux; \
    apk --no-cache add --virtual .build-deps wget; \
    ARCH="$(apk --print-arch)"; \
    case "${ARCH}" in \
EOI
	print_java_install ${file} ${srcpkg} ${dstpkg};
	sed '$s/$/ \\\n    apk del .build-deps;/' -i "$1"
}

# Print the main RUN command that installs Java on rhel.
print_rhel_java_install() {
	srcpkg=$2
	dstpkg=$3
	shasums="${srcpkg}"_"${ver}"_sums
	cat >> $1 <<'EOI'
RUN set -eux; \
    ARCH="$(arch)"; \
    case "${ARCH}" in \
EOI
	print_java_install ${file} ${srcpkg} ${dstpkg};
}

# Print the main RUN command that installs Java on ubi-min.
print_ubi-min_java_install() {
	srcpkg=$2
	dstpkg=$3
	shasums="${srcpkg}"_"${ver}"_sums
	cat >> $1 <<'EOI'
RUN set -eux; \
    microdnf -y install shadow-utils; \
    useradd -u 1001 -r -g 0 -s /usr/sbin/nologin default; \
    ARCH="$(uname -m)"; \
    case "${ARCH}" in \
EOI
	print_java_install ${file} ${srcpkg} ${dstpkg};
}

# Print the main RUN command that installs Java on ubi.
print_ubi_java_install() {
	srcpkg=$2
	dstpkg=$3
	shasums="${srcpkg}"_"${ver}"_sums
	cat >> $1 <<'EOI'
RUN set -eux; \
    useradd -u 1001 -r -g 0 -s /usr/sbin/nologin default; \
    ARCH="$(uname -m)"; \
    case "${ARCH}" in \
EOI
	print_java_install ${file} ${srcpkg} ${dstpkg};
}

print_java_env() {
	if [ "${pack}" == "sdk" ]; then
		if [ "${ver}" == "8" ]; then
			JHOME="/opt/ibm/java/jre"
			JPATH="/opt/ibm/java/bin"
		elif [ "${ver}" == "9" ]; then
			JHOME="/opt/ibm/java"
			JPATH="/opt/ibm/java/bin"
		fi
	else
		JHOME="/opt/ibm/java/jre"
		JPATH="/opt/ibm/java/jre/bin"
	fi
	TPATH="PATH=${JPATH}:\$PATH"

	cat >> $1 <<-EOI

ENV JAVA_HOME=${JHOME} \\
    ${TPATH} \\
    IBM_JAVA_OPTIONS="-XX:+UseContainerSupport"
EOI
}

print_exclude_file() {
	srcpkg=$2
	dstpkg=$3
	if [ "${ver}" == "9" -a "${dstpkg}" == "sfj" ]; then
		cp sfj-exclude.txt `dirname ${file}`
		cat >> $1 <<-EOI
COPY sfj-exclude.txt /tmp

EOI
	fi
}

#print to run the docker image with user other than root.
print_user() {
	cat >> $1 <<-EOI

USER 1001
EOI
}

generate_java() {
	if [ "${ver}" == "9" ]; then
		srcpkg="sdk";
	else
		srcpkg=${pack};
	fi
	dstpkg=${pack};
	print_env ${file} ${srcpkg};
	print_exclude_file ${file} ${srcpkg} ${dstpkg};
if [ "${os}" == "ubuntu" ]; then
		print_ubuntu_java_install ${file} ${srcpkg} ${dstpkg};
elif [ "${os}" == "alpine" ]; then
		print_alpine_java_install ${file} ${srcpkg} ${dstpkg};
elif [ "${os}" == "rhel" ]; then
		print_rhel_java_install ${file} ${srcpkg} ${dstpkg};
elif [ "${os}" == "ubi" ]; then
		print_ubi_java_install ${file} ${srcpkg} ${dstpkg};
elif [ "${os}" == "ubi-min" ]; then
		print_ubi-min_java_install ${file} ${srcpkg} ${dstpkg};
fi
	print_java_env ${file};
}

generate_ubuntu() {
	file=$1
	mkdir -p `dirname ${file}` 2>/dev/null
	echo -n "Writing ${file}..."
	print_legal ${file};
	print_ubuntu_os ${file};
	print_maint ${file};
	print_ubuntu_pkg ${file};
	generate_java ${file};
	echo "done"
}

generate_alpine() {
	file=$1
	mkdir -p `dirname ${file}` 2>/dev/null
	echo -n "Writing ${file}..."
	print_legal ${file};
	print_alpine_os ${file};
	print_maint ${file};
	print_alpine_pkg ${file};
	generate_java ${file};
	cp sgerrand.rsa.pub `dirname ${file}`
	echo "done"
}

generate_rhel() {
	file=$1
	mkdir -p `dirname ${file}` 2>/dev/null
	echo -n "Writing ${file}..."
	print_legal ${file};
	print_rhel_os ${file};
	print_maint ${file};
	print_rhel_pkg ${file};
	generate_java ${file};
	echo "done"
}

generate_ubi() {
	file=$1
	mkdir -p `dirname ${file}` 2>/dev/null
	echo -n "Writing ${file}..."
	print_legal ${file};
	print_ubi_os ${file};
	print_ubi_pkg ${file};
	generate_java ${file};
	print_user ${file};
	echo "done"
}

generate_ubi-min() {
	file=$1
	mkdir -p `dirname ${file}` 2>/dev/null
	echo -n "Writing ${file}..."
	print_legal ${file};
	print_ubi-min_os ${file};
	print_ubi-min_pkg ${file};
	generate_java ${file};
	print_user ${file};
	echo "done"
}

# Print the ibmjava image version
print_java() {
	cat >> $1 <<-EOI
	FROM ibmjava:${ver}-sdk

	EOI
}

#
print_maven() {
	cat >> $1 <<'EOI'

ARG MAVEN_VERSION=3.3.9

RUN mkdir -p /usr/share/maven \
    && BASE_URL="http://apache.osuosl.org/maven/maven-3" \
    && wget -q -O /tmp/maven.tar.gz $BASE_URL/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz \
    && tar -xzC /usr/share/maven --strip-components=1 -f /tmp/maven.tar.gz \
    && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

ENV MAVEN_HOME /usr/share/maven

CMD ["/usr/bin/mvn"]
EOI
}

generate_maven() {
	file=$1
	mkdir -p `dirname $file}` 2>/dev/null
	echo -n "Writing ${file}..."
	print_legal ${file};

	print_java ${file};
	print_maint ${file};
	print_maven ${file};
	echo "done"
}

# Iterate through all the Java versions for each of the supported packages,
# architectures and supported Operating Systems.
for ver in ${version}
do
	for pack in ${package}
	do
		for os in ${osver}
		do
			file=${ver}/${pack}/${os}/Dockerfile
			# Ubuntu is supported for everything
			if [ "${os}" == "ubuntu" ]; then
				generate_ubuntu ${file}
			elif [ "${os}" == "alpine" ]; then
				generate_alpine ${file}
			elif [ "${os}" == "rhel" ]; then
				generate_rhel ${file}
			elif [ "${os}" == "ubi" ]; then
				generate_ubi ${file}
			elif [ "${os}" == "ubi-min" ]; then
				generate_ubi-min ${file}
			fi
		done
	done
done

# Iterate through all the build tools.
for ver in ${version}
do
	for tool in ${tools}
	do
		file=${ver}/${tool}/Dockerfile
		generate_maven ${file}
	done
done
