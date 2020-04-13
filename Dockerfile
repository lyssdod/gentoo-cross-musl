FROM busybox

ARG ARCH="unknown"
ARG KERNEL="unknown"
ARG VENDOR="unknown"

# check if $ARCH has been set and fail early
RUN if [ "$ARCH" == "unknown" ]; then echo " !!!! ERROR: please provide desired ARCH build argument"; exit 1; fi
RUN if [ "$KERNEL" == "unknown" ]; then echo " #### Latest available kernel headers will be chosen"; fi
RUN if [ "$VENDOR" == "unknown" ]; then ehco " #### 'unknown' toolchain vendor will be chosen"; fi

# name the portage image
FROM gentoo/portage:latest as portage

# image is based on stage3-amd64
FROM gentoo/stage3-amd64-nomultilib:latest

# define args again
ARG ARCH
ARG KERNEL
ARG VENDOR

# copy the entire portage volume in
COPY --from=portage /var/db/repos/gentoo /var/db/repos/gentoo

COPY overlay/ /

# tweak some configs
RUN echo " #### Creating cross environment for $ARCH" \
    && echo ' #### Setting up initial configs...' \
    && echo 'FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox"' >> /etc/portage/make.conf \
    && chown -R portage:portage /usr/local/portage-crossdev

# separate step to enable caching
RUN echo ' #### Installing base packages...' \
    && emerge -q bc vim eix distcc layman squashfs-tools crossdev gentoolkit \
    && rm -rf /var/cache/distfiles/*

# crossdev time!
RUN echo ' #### Running crossdev ...' && /usr/bin/crossdev-wrapper

# continue
RUN echo ' #### Finishing configuration...' \
    && layman -S && layman -a musl && layman -D musl \
    && ln -s /var/db/repos/gentoo /usr/portage \
    && echo 'PORTDIR_OVERLAY="/var/lib/layman/musl /var/db/repos/gentoo"' >> /usr/$ARCH-$VENDOR-linux-musl/etc/portage/make.conf \
    && rm /usr/$ARCH-$VENDOR-linux-musl/etc/portage/make.profile \
    && ln -s /var/db/repos/gentoo/profiles/default/linux/musl /usr/$ARCH-$VENDOR-linux-musl/etc/portage/make.profile \
    && eix-update \
    && echo ' #### Done!'
