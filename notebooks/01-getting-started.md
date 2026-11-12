---
jupytext:
  text_representation:
    extension: .md
    format_name: myst
kernelspec:
  display_name: Python 3
  language: python
  name: python3
---

# Getting started with MetallGraph and CLIPPy

[MetallGraph](https://github.com/MetallData/metalldata) is a persistent,
distributed property graph. Its operations are C++/MPI executables, and
[CLIPPy](https://github.com/LLNL/clippy) (`llnl-clippy`) exposes them as an
ordinary Python class. Each method call runs a backend executable (here under
`mpirun`) against a graph stored on disk with [Metall](https://github.com/LLNL/metall).

In this notebook you will:

1. Configure CLIPPy to find the MetallGraph backend.
2. Build a tiny graph from Parquet and query it.
3. Load a real graph of 50,000 movies and their cast from Wikidata.
4. Run graph analytics: degree, top-k, value counts, connected components, and n-hop neighborhoods.
5. Reopen the persistent graph.

## Setup

CLIPPy discovers backends from `CLIPPY_BACKEND_PATH` **at import time**, so the
environment must be set before `import clippy`. The tutorial container already
sets these variables. The defaults below only apply when they are missing.

- `CLIPPY_BACKEND_PATH`: the directory containing the `MetallGraph/` and `MetallUtils/` backends.
- `CLIPPY_CMD_PREFIX`: the prefix for every backend call. `mpirun -n 2` runs each operation on 2 MPI ranks.
- `MG_WORKDIR`: where graphs are stored. Use local disk, not a network or bind-mounted filesystem.
- `TUTORIAL_DATA`: the directory holding the input Parquet files.

```{code-cell} ipython3
import os
from pathlib import Path

os.environ.setdefault("CLIPPY_BACKEND_PATH", "/src/build/src/clippy")
os.environ.setdefault("CLIPPY_CMD_PREFIX", "mpirun -n 2")

MG_WORKDIR = Path(os.environ.setdefault("MG_WORKDIR", "/tmp/mg"))
DATA = Path(os.environ.get("TUTORIAL_DATA", Path.cwd().parent / "data"))
MG_WORKDIR.mkdir(parents=True, exist_ok=True)

import clippy
from clippy import MetallGraph, MetallUtils

print("backend:", os.environ["CLIPPY_BACKEND_PATH"])
print("prefix: ", os.environ["CLIPPY_CMD_PREFIX"])
print("data:   ", DATA)
```

The methods on `MetallGraph` come straight from the backend executables:

```{code-cell} ipython3
sorted(m for m in dir(MetallGraph) if not m.startswith("_"))
```

## A tiny graph

`MetallGraph(path)` creates a graph at `path`, or opens it if one already
exists. We start from a clean directory so the notebook can be rerun.

```{code-cell} ipython3
import shutil

def fresh_graph(name: str) -> MetallGraph:
    path = MG_WORKDIR / name
    shutil.rmtree(path, ignore_errors=True)
    return MetallGraph(str(path))

toy = fresh_graph("toy.mg")
toy.describe()
```

`ingest_parquet_edges(path, u_column, v_column)` loads edges, and every other
column becomes an edge *series*. `ingest_parquet_nodes` attaches node metadata
keyed by a node id column.

```{code-cell} ipython3
toy.ingest_parquet_edges(str(DATA / "toy/two_triangles_0.parquet"), "s", "t")
toy.ingest_parquet_nodes(str(DATA / "toy/two_triangles-nodes_0.parquet"), "id")
toy.describe()
```

The node file also lists `foxtrot`, which appears in no edge. By default
`ingest_parquet_nodes` only attaches metadata to nodes already in the graph, so
foxtrot is skipped and reported as "nodes not found in graph". Pass
`add_new=True` to keep such nodes as disconnected vertices.

### Drawing a small graph

A graph this small is easier to understand as a picture. The helper below pulls
nodes and edges out with `select_nodes` / `select_edges` and draws them with
[networkx](https://networkx.org/). Edges are colored by their `color` series,
and nodes matching an optional `where`-style expression are highlighted. Only
use this on small graphs, since it copies the whole graph into Python.

```{code-cell} ipython3
import matplotlib.pyplot as plt
import networkx as nx

def draw_graph(g: MetallGraph, highlight=None, seed: int = 7) -> None:
    """Draw a small MetallGraph; nodes matching `highlight` are orange."""
    G = nx.DiGraph()
    for n in g.select_nodes(series_names=[g.node.id, g.node.label]):
        G.add_node(n["node.id"], label=n.get("node.label") or n["node.id"])
    for e in g.select_edges(series_names=[g.edge.u, g.edge.v, g.edge.color]):
        G.add_edge(e["edge.u"], e["edge.v"], color=e.get("edge.color") or "gray")

    hl = set()
    if highlight is not None:
        hl = {n["node.id"] for n in g.select_nodes(series_names=[g.node.id], where=highlight)}

    fig, ax = plt.subplots(figsize=(5, 4))
    nx.draw_networkx(
        G,
        nx.spring_layout(G, seed=seed),
        ax=ax,
        labels=nx.get_node_attributes(G, "label"),
        node_color=["orange" if v in hl else "lightsteelblue" for v in G],
        edge_color=[c for *_, c in G.edges(data="color")],
        node_size=1200,
        arrowsize=15,
        width=2,
    )
    ax.set_axis_off()
    plt.show()

draw_graph(toy)
```

Two directed triangles, blue and red, share the node `charlie`.

Results come back as plain Python lists of dicts, which work well with pandas.
Series are named `node.<name>` or `edge.<name>`. When you pass series to a
method, use the selector objects `toy.node.<name>` and `toy.edge.<name>`, not
strings.

```{code-cell} ipython3
import pandas as pd

pd.DataFrame(toy.select_edges(series_names=[toy.edge.color, toy.edge.weight]))
```

### Filtering with `where`

`toy.node.<series>` and `toy.edge.<series>` build expressions with normal
Python operators. CLIPPy turns them into [JSONLogic](https://jsonlogic.com/)
and evaluates them inside the backend.

```{code-cell} ipython3
pd.DataFrame(toy.select_nodes(series_names=[toy.node.age, toy.node.label], where=toy.node.age > 25))
```

The same expression can drive the drawing:

```{code-cell} ipython3
draw_graph(toy, highlight=toy.node.age > 25)
```

```{code-cell} ipython3
pd.DataFrame(toy.select_edges(where=(toy.edge.color == "blue") & (toy.edge.weight > 2)))
```

Analytics write their results into a new series:

```{code-cell} ipython3
toy.connected_components("cc")
pd.DataFrame(toy.select_nodes(series_names=[toy.node.cc]))
```

## A real graph: 50,000 movies from Wikidata

`data/movie-50k` is a bipartite graph of the 50,000 movies with the most
Wikimedia sitelinks and the people credited in them (cast member P161 or voice
actor P725). Edges are directed **actor → movie**. Both files are split into 64
Parquet shards. Passing the *directory* lets the MPI ranks ingest the shards in
parallel.

```{code-cell} ipython3
movies = fresh_graph("movies.mg")
movies.ingest_parquet_edges(
    str(DATA / "movie-50k/edges"), "source", "target", metadata=["credit_type"]
)
movies.ingest_parquet_nodes(
    str(DATA / "movie-50k/nodes"),
    "node_id",
    add_new=True,  # keep movies with no credited cast
    metadata=["node_type", "label", "rank"],
)
movies.describe()
```

How many movies and how many people?

```{code-cell} ipython3
movies.value_counts(movies.node.node_type)
```

### Degree

Because edges run actor → movie, a movie's **in-degree** is its cast size and a
person's **out-degree** is the number of their credited films.

```{code-cell} ipython3
movies.in_degree("cast_size")
movies.out_degree("n_films")

pd.DataFrame(
    movies.topk(movies.node.n_films, k=10, addl_series=[movies.node.label]),
    columns=["films", "person"],
)
```

```{code-cell} ipython3
pd.DataFrame(
    movies.topk(
        movies.node.cast_size,
        k=10,
        addl_series=[movies.node.label],
        where=movies.node.node_type == "movie",
    ),
    columns=["cast", "movie"],
)
```

### Connected components

```{code-cell} ipython3
movies.connected_components("cc")
cc_sizes = movies.value_counts(movies.node.cc, k=5)
pd.DataFrame(cc_sizes, columns=["component", "nodes"])
```

### Neighborhoods with `nhops`

`nhops` follows edge direction from a set of seed nodes, so the seeds must have
outgoing edges. Here that means people, not movies. We'll mark every node
within 1 hop of Humphrey Bogart, which is Bogart himself (hop 0) and his films
(hop 1).

```{code-cell} ipython3
seed = movies.select_nodes(where=movies.node.label == "Humphrey Bogart")
seed
```

```{code-cell} ipython3
seed_id = seed[0]["node.id"]
movies.nhops("hops", 1, [seed_id])
movies.value_counts(movies.node.hops)
```

```{code-cell} ipython3
pd.DataFrame(
    movies.select_nodes(
        series_names=[movies.node.label], where=movies.node.hops == 1, limit=10
    )
)
```

## Persistence

The graph lives in `MG_WORKDIR`. A new `MetallGraph` object on the same path
picks up all of the series computed above, with no reload needed.

```{code-cell} ipython3
again = MetallGraph(str(MG_WORKDIR / "movies.mg"))
again.describe()
```

## Next steps

- `assign` to compute new series from JSONLogic expressions
- `add_faker` to generate synthetic attributes
- `sample_nodes` / `sample_edges`
- `dump_parquet_nodes` / `dump_parquet_edges` for export
- `MetallUtils().copy` to snapshot a graph
