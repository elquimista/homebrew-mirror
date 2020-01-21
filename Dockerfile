FROM ruby:2.7.0-buster
LABEL maintainer="el que m'est"

ARG GID
ARG UID
ARG HOME=/home/mobydick

ENV DEBIAN_FRONTEND=noninteractive
USER root

RUN apt-get update && apt-get install -y \
    sudo && \
    # Clear apt caches
    rm -rf /var/lib/apt/lists/*

# Create a group & user (or update names if already exist)
RUN if [ -z "`getent group $GID`" ]; then \
      groupadd -g $GID cetacean; \
    else \
      groupmod -n cetacean `getent group $GID | cut -d: -f1`; \
    fi && \
    if [ -z "`getent passwd $UID`" ]; then \
      useradd -u $UID -g cetacean -s /bin/bash mobydick; \
    else \
      usermod -l mobydick -g $GID -d $HOME -m `getent passwd $UID | cut -d: -f1`; \
    fi && \
    # Add user mobydick to sudoers list
    echo "mobydick ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/mobydick && \
    chmod 0440 /etc/sudoers.d/mobydick && \
    # Allow non-root user to use `ping`
    chmod 4755 $(which ping)

WORKDIR $HOME
RUN chown mobydick:cetacean $HOME
WORKDIR $HOME/app
RUN chown mobydick:cetacean $HOME/app
USER mobydick

COPY --chown=mobydick:cetacean . ./
RUN bundle install

CMD ["bash"]
