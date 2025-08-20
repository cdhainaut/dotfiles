# Dockerfile
FROM ubuntu:24.04

ARG USER=dev
ARG UID=1000
ARG GID=1000

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    sudo curl git zsh ca-certificates \
    build-essential cmake pkg-config libssl-dev unzip \
  && rm -rf /var/lib/apt/lists/*

# User non-root
# RUN groupadd -g $GID $USER && \
#     useradd -m -u $UID -g $GID -s /bin/zsh $USER && \
#     echo "$USER ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/$USER

# --- Création utilisateur non-root (robuste si 1000 déjà pris) ---
ARG USER=dev
ARG UID=1000
ARG GID=1000

RUN set -eux; \
    # 1) Groupe: réutilise s'il y a déjà un groupe avec ce GID
    if getent group "$GID" >/dev/null; then \
      GROUP_NAME="$(getent group "$GID" | cut -d: -f1)"; \
    else \
      groupadd -g "$GID" "$USER"; \
      GROUP_NAME="$USER"; \
    fi; \
    # 2) Utilisateur: si l'UID est pris, crée l'utilisateur sans forcer l'UID
    if id -u "$USER" >/dev/null 2>&1; then \
      usermod -s /bin/zsh -g "$GROUP_NAME" "$USER"; \
    else \
      if getent passwd "$UID" >/dev/null; then \
        useradd -m -s /bin/zsh -g "$GROUP_NAME" "$USER"; \
      else \
        useradd -m -u "$UID" -s /bin/zsh -g "$GROUP_NAME" "$USER"; \
      fi; \
    fi; \
    echo "$USER ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/$USER; \
    chmod 0440 /etc/sudoers.d/$USER; \
    # 3) Dossiers $HOME + droits corrects
    install -d -m 700 /home/$USER/.local /home/$USER/.config; \
    install -d -m 755 /home/$USER/.local/share; \
    chown -R "$USER:$GROUP_NAME" /home/$USER

USER $USER
WORKDIR /home/$USER

# Installer chezmoi (binaire dans ~/.local/bin)
RUN sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin
ENV PATH="/home/$USER/.local/bin:${PATH}"

# Par défaut on attend que ton repo soit monté en volume
# et on applique en mode verbeux + headless
ENV HEADLESS=1
CMD ["bash", "-lc", "chezmoi apply --verbose"]
