# MetallData tutorial image: metalldata built at a pinned ref (plain
# cmake + make) + a Python venv with llnl-clippy and Jupyter. Used by both the devcontainer and
# the published GHCR release image.

ARG BASE_IMAGE=mcr.microsoft.com/devcontainers/cpp:dev-ubuntu-24.04

FROM ${BASE_IMAGE}

ARG METALLDATA_REPO=https://github.com/MetallData/metalldata.git
ARG METALLDATA_REF
ARG BUILD_JOBS=4

RUN test -n "${METALLDATA_REF}" || (echo "METALLDATA_REF build-arg is required" && exit 1)

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       gcc-13 g++-13 openmpi-bin libopenmpi-dev git ca-certificates \
       python3 python3-venv python3-pip \
    && rm -rf /var/lib/apt/lists/*

ENV CC=gcc-13 CXX=g++-13

WORKDIR /src
RUN git init metalldata \
    && cd metalldata \
    && git remote add origin "${METALLDATA_REPO}" \
    && git fetch --depth 1 origin "${METALLDATA_REF}" \
    && git checkout --detach FETCH_HEAD

RUN cmake -S /src/metalldata -B /src/build \
       -DCMAKE_BUILD_TYPE=Release \
    && cmake --build /src/build -j${BUILD_JOBS}

COPY requirements.txt /tmp/requirements.txt
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir -r /tmp/requirements.txt \
    && chown -R vscode:vscode /opt/venv

ENV PATH=/opt/venv/bin:${PATH} \
    CLIPPY_BACKEND_PATH=/src/build/src/clippy \
    CLIPPY_CMD_PREFIX="mpirun -n 2" \
    OMPI_MCA_rmaps_base_oversubscribe=1 \
    MG_WORKDIR=/tmp/mg

USER vscode
WORKDIR /home/vscode/tutorial
COPY --chown=vscode:vscode notebooks ./notebooks
# Ship real .ipynb notebooks; the MyST .md files are only the source format.
RUN cd notebooks && jupytext --to ipynb *.md && rm *.md
COPY --chown=vscode:vscode data ./data
ENV TUTORIAL_DATA=/home/vscode/tutorial/data

EXPOSE 8888
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--notebook-dir=/home/vscode/tutorial"]
