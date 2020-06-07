FROM nixos/nix:2.3.4

ENV NIXOS_VERSION 20.03
WORKDIR /tmp/interkosmos
RUN apk update
ADD . /tmp/interkosmos/

RUN chmod a+x /tmp/interkosmos/*/*.sh
RUN nix-channel --add https://nixos.org/channels/nixos-${NIXOS_VERSION} nixos

ENTRYPOINT [ "/tmp/interkosmos/entrypoint.sh" ]
