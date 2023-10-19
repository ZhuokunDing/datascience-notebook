FROM nvidia/cuda:11.8.0-devel-ubuntu20.04
LABEL mantainer="Zhuokun Ding <zhuokund@bcm.edu>, Stelios Papadopoulos <spapadop@bcm.edu>, Christos Papadopoulos <cpapadop@bcm.edu>"
# The following dockerfile is based on jupyter/docker-stacks: https://github.com/jupyter/docker-stacks

# Fix: https://github.com/hadolint/hadolint/wiki/DL4006
# Fix: https://github.com/koalaman/shellcheck/wiki/SC3014
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

ENV DEBIAN_FRONTEND noninteractive
# # Add profiling library support
ENV LD_LIBRARY_PATH /usr/local/cuda/extras/CUPTI/lib64:${LD_LIBRARY_PATH}

RUN apt-get update --yes && \
    # - apt-get upgrade is run to patch known vulnerabilities in apt-get packages as
    #   the ubuntu base image is rebuilt too seldom sometimes (less than once a month)
    apt-get upgrade --yes && \
    apt-get install --yes --no-install-recommends \
    # - bzip2 is necessary to extract the micromamba executable.
    bzip2 \
    ca-certificates \
    locales \
    sudo \
    # - tini is installed as a helpful container entrypoint that reaps zombie
    #   processes and such of the actual executable we want to start, see
    #   https://github.com/krallin/tini#why-tini for details.
    tini \
    # - pandoc is used to convert notebooks to html files
    #   it's not present in aarch64 ubuntu image, so we install it here
    pandoc \
    wget \
    # Common useful utilities
    nano-tiny \
    tzdata \
    unzip \
    vim-tiny \
    # git-over-ssh
    openssh-client \
    # less is needed to run help in R
    # see: https://github.com/jupyter/docker-stacks/issues/1588
    less \
    # nbconvert dependencies
    # https://nbconvert.readthedocs.io/en/latest/install.html#installing-tex
    texlive-xetex \
    texlive-fonts-recommended \
    texlive-plain-generic \
    # Enable clipboard on Linux host systems
    xclip \
    # R pre-requisites
    fonts-dejavu \
    gfortran \
    gcc && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

# Configure environment
ENV CONDA_DIR=/opt/conda \
    SHELL=/bin/bash \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8
ENV PATH="${CONDA_DIR}/bin:${PATH}"
ENV HOME="/"

# Enable prompt color in the skeleton .bashrc before creating the default NB_USER
# hadolint ignore=SC2016
RUN sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' /etc/skel/.bashrc && \
   # Add call to conda init script see https://stackoverflow.com/a/58081608/4413446
   echo 'eval "$(command conda shell.bash hook 2> /dev/null)"' >> /etc/skel/.bashrc

# Pin python version here
ARG PYTHON_VERSION=3.10

# Download and install Micromamba, and initialize Conda prefix.
#   <https://github.com/mamba-org/mamba#micromamba>
#   Similar projects using Micromamba:
#     - Micromamba-Docker: <https://github.com/mamba-org/micromamba-docker>
#     - repo2docker: <https://github.com/jupyterhub/repo2docker>
# Install Python, Mamba and jupyter_core
# Cleanup temporary files and remove Micromamba
# Correct permissions
# Do all this in a single RUN command to avoid duplicating all of the
# files across image layers when the permissions change
COPY initial-condarc "${CONDA_DIR}/.condarc"
WORKDIR /tmp
RUN set -x && \
    arch=$(uname -m) && \
    if [ "${arch}" = "x86_64" ]; then \
        # Should be simpler, see <https://github.com/mamba-org/mamba/issues/1437>
        arch="64"; \
    fi && \
    wget -qO /tmp/micromamba.tar.bz2 \
        "https://micromamba.snakepit.net/api/micromamba/linux-${arch}/latest" && \
    tar -xvjf /tmp/micromamba.tar.bz2 --strip-components=1 bin/micromamba && \
    rm /tmp/micromamba.tar.bz2 && \
    PYTHON_SPECIFIER="python=${PYTHON_VERSION}" && \
    # Bootstrap mamba and install conda available packages
    ./micromamba install \
        --root-prefix="${CONDA_DIR}" \
        --prefix="${CONDA_DIR}" \
        --yes \
        "${PYTHON_SPECIFIER}" \
        'mamba' &&\
    rm micromamba && \
    # Pin major.minor version of python
    mamba list python | grep '^python ' | tr -s ' ' | cut -d ' ' -f 1,2 >> "${CONDA_DIR}/conda-meta/pinned" && \
    # Pin libblas
    echo 'libblas=*=*mkl' >> "${CONDA_DIR}/conda-meta/pinned" && \
    mamba install --yes \
        'git' \
        'pip' \
        'python-lsp-server' \
        'r-languageserver' \
        'numpy' \
        'libblas=*=*mkl'\
        'cython' \
        'dask' \
        'dill' \
        'h5py' \
        'ipympl'\
        'ipywidgets' \
        'matplotlib-base' \
        'numba' \
        'numexpr' \
        'openpyxl' \
        'pandas' \
        'patsy' \
        'protobuf' \
        'pytables' \
        'scikit-image' \
        'scikit-learn' \
        'scipy' \
        'seaborn' \
        'sqlalchemy' \
        'statsmodels' \
        'widgetsnbextension'\
        # R
        'r-base' \
        'r-caret' \
        'r-crayon' \
        'r-devtools' \
        'r-e1071' \
        'r-forecast' \
        'r-hexbin' \
        'r-htmltools' \
        'r-htmlwidgets' \
        'r-irkernel' \
        'r-nycflights13' \
        'r-randomforest' \
        'r-rcurl' \
        'r-rmarkdown' \
        'r-rodbc' \
        'r-rsqlite' \
        'r-shiny' \
        'r-tidyverse' \
        'r-tidymodels' \
        'rpy2' \
        'unixodbc' \
        # holoviz
        'holoviews' \
        'bokeh' \
        'panel' \
        'hvplot' \
        'datashader' \
        'param' \
        'colorcet' \
        # useful packages
        'pytest' \
        'pytest-cov' \
        'simplejson' \
        'networkx' \
        'pylint' \
        'tqdm' && \
    mamba install --yes  -c conda-forge jupyterlab~=4.0
    # pytorch
RUN mamba install --yes pytorch torchvision torchaudio pytorch-cuda=11.8 -c pytorch -c nvidia
RUN mamba update ffmpeg && \
    mamba clean --all -f -y && \
    jupyter lab clean


# Currently need to have both jupyter_notebook_config and jupyter_server_config to support classic and lab
COPY jupyter_server_config.py /etc/jupyter/
# Add R mimetype option to specify how the plot returns from R to the browser
COPY Rprofile.site /opt/conda/lib/R/etc/

# Import matplotlib the first time to build the font cache.
ENV XDG_CACHE_HOME="${HOME}/.cache/"
RUN MPLBACKEND=Agg python -c "import matplotlib.pyplot"
# Configure container startup
ENTRYPOINT ["tini", "-g", "--"]

WORKDIR "${HOME}"