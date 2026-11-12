# MetallData Tutorial

Jupyter notebooks that demonstrate [CLIPPy](https://github.com/LLNL/clippy) with
[MetallGraph](https://github.com/MetallData/metalldata), a persistent,
distributed property graph.

| Notebook | Covers |
|---|---|
| [01-getting-started](notebooks/01-getting-started.md) | CLIPPy setup, building and querying a graph, a 50k-movie Wikidata graph, graph analytics, reopening a persistent graph |

## Quick start

The tutorial runs in a Docker container that includes metalldata, MPI, the
Python packages, and the data. The image is published for both x86-64 (amd64)
and ARM (arm64), and Docker picks the right one automatically.

### 1. Install Docker

- **Windows:** install [Docker Desktop](https://docs.docker.com/desktop/setup/install/windows-install/)
  and keep the default **WSL 2** backend. Start Docker Desktop before running
  the commands below.
- **macOS:** install [Docker Desktop](https://docs.docker.com/desktop/setup/install/mac-install/).
- **Linux:** install [Docker Engine](https://docs.docker.com/engine/install/)
  for your distribution. To run `docker` without `sudo`, follow the
  [post-install steps](https://docs.docker.com/engine/install/linux-postinstall/).

### 2. Start the tutorial

The commands below create a `work` folder in your current directory and mount
it into the container. The container is removed when it stops, so **save
anything you want to keep under `work/`**.

**Windows (PowerShell):**

```powershell
mkdir work -Force
docker run --rm -p 8888:8888 -v "${PWD}\work:/home/vscode/tutorial/work" ghcr.io/metalldata/metalldata-tutorial:latest
```

**macOS / Linux:**

```bash
mkdir -p work
docker run --rm -p 8888:8888 -v "$PWD/work:/home/vscode/tutorial/work" \
  ghcr.io/metalldata/metalldata-tutorial:latest
```

The first run downloads the image, which takes a few minutes.

### 3. Open the notebooks

Jupyter prints a link like `http://127.0.0.1:8888/lab?token=...`. Open it in
your browser, then open `notebooks/01-getting-started.ipynb`.

To stop the tutorial, press **Ctrl+C** in the terminal.

### Notes

- **Specific versions:** to pin a version, replace `latest` with a release tag
  such as `v0.1.0`. See [Releases](https://github.com/MetallData/metalldata-tutorial/releases)
  for the full list.
- **Port in use:** if something else is already using port 8888, use
  `-p 8889:8888` and change the port in the link to `8889`.
- **Linux: "Permission denied" saving to `work/`:** the container runs as user
  id 1000. If your user id (`id -u`) is different, run `chmod a+rwx work` once.

## Other ways to run

### VS Code devcontainer

For editing the notebooks or contributing, clone this repository and choose
**Reopen in Container** in VS Code. The first build compiles metalldata from
source and takes a while. Later builds reuse the cache.

In the repository, notebooks are stored as MyST Markdown (`notebooks/*.md`)
so they diff cleanly. JupyterLab opens them as notebooks through
[jupytext](https://jupytext.readthedocs.io). If one opens as plain text,
right-click it and choose **Open With → Jupytext Notebook**. The Docker image
converts them to `.ipynb`, so tutorial users only ever see notebooks.

### Your own metalldata build

If you already have metalldata built (for example on an HPC system), download
`requirements.txt` and `env.sh` from a release, or use the copies in this
repository, then run:

```bash
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
source env.sh /path/to/metalldata/build/src/clippy
export TUTORIAL_DATA=/path/to/metalldata-tutorial/data
jupyter lab
```

`env.sh` sets the following, each of which you can override:

| Variable | Purpose | Default |
|---|---|---|
| `CLIPPY_BACKEND_PATH` | metalldata's `src/clippy` build directory | `/src/build/src/clippy` |
| `CLIPPY_CMD_PREFIX` | Prefix for every backend call | `mpirun -n 2` |
| `MG_WORKDIR` | Where graphs are stored; use local disk, since Metall uses mmap | `/tmp/mg` |

The `llnl-clippy` version in `requirements.txt` must match the one your
metalldata build uses. The metalldata commit this tutorial is tested against
is pinned in [`METALLDATA_REF`](METALLDATA_REF).

## Building the image yourself

```bash
docker build -f docker/Dockerfile --build-arg METALLDATA_REF=$(cat METALLDATA_REF) -t mdt .
docker run --rm -p 8888:8888 mdt
```

To execute every notebook non-interactively into `build/*.ipynb`, which is
what CI does, run:

```bash
docker run --rm -v "$PWD:/work" -w /work -e TUTORIAL_DATA=/work/data mdt bash scripts/run-notebooks.sh
```

Tagging `v*` builds the image natively for amd64 and arm64, executes the
notebooks on both, publishes a multi-arch image to GHCR (plus per-arch
`<tag>-amd64` and `<tag>-arm64` images), and creates a GitHub release with the
executed notebooks attached.

## License

MetallData is distributed under the MIT license.

All new contributions must be made under the MIT license.

See LICENSE, NOTICE, and COPYRIGHT for details.

SPDX-License-Identifier: MIT

LLNL-CODE-835154
