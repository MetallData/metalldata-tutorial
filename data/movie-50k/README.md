# Wikidata actor-to-movie graph (50k movies)

Bipartite graph of movies and actors/performers, generated from
Wikidata's official Query Service (`https://query.wikidata.org/sparql`), with
a ranking snapshot date of 2026-08-06.

Movies are ranked by descending Wikimedia sitelink count, with Wikidata QID as
a deterministic tie-breaker. Edges come from Wikidata cast member (P161) and
voice actor (P725) statements, so the graph can be a multigraph when an actor
has multiple credit statements for the same movie. Missing values are empty
fields, never zero.

## Node counts

161,666 total nodes: 50,000 movies and 111,666 actors/performers
(`node_type` column). 516,570 edges.

Note: 7 Wikidata QIDs appear twice in the node table (once as `movie`, once
as `actor`), so a graph built from it has 161,659 unique nodes. One node has
no edges.

## Contents

The primary distributable data is Parquet, split into 64 shards each for
parallel processing:

- `nodes/nodes-000.parquet` ... `nodes-063.parquet` — 64 shards of `50k-movie-nodes.pq`
  (161,666 rows total), columns `node_id,node_type,label,wikidata_qid,rank,birth_date,box_office_amount`
- `edges/edges-000.parquet` ... `edges-063.parquet` — 64 shards of `50k-movie-edges.pq`
  (516,570 rows total), columns `edge_id,source,target,credit_type,character_qids,character_names`

Rows are divided as evenly as possible per shard and kept in original row
order. `50k-movie-nodes.pq` and `50k-movie-edges.pq` are the unsplit source
Parquet files each shard set is sliced from.

### Original CSV exports

The pipeline's raw output:

| File | Rows | Columns |
|---|---|---|
| `node_metadata.csv` | 161,666 + header | `node_id,node_type,label,wikidata_qid,rank,rank_snapshot_date,sitelink_count,year,birth_date,birth_date_precision,birth_date_conflict,birth_dates_json,box_office_amount,box_office_currency_qid,box_office_statements_json` |
| `edge_list.csv` | 516,570 + header | `edge_id,source,target` (directed, actor → movie) |
| `edge_metadata.csv` | 516,570 + header | `edge_id,wikidata_statement_id,credit_type,billing_order,character_qids,character_names,role_names` |
| `node_metadata_2.csv` | 161,666 + header | Trimmed columns: `node_id,node_type,label,wikidata_qid,rank,birth_date,box_office_amount` |
| `edge_metadata_2.csv` | 516,570 + header | Trimmed columns: `edge_id,credit_type,character_qids,character_names` |
| `edges.csv` | 516,570 + header | `edge_id,source,target,credit_type,character_qids,character_names` (edge list joined with trimmed edge metadata) |

Repeated character values are separated with `|`. The `50k-movie-*.pq` files
(and their `split-*` shards) are Parquet copies of the trimmed
`*_metadata_2.csv`/`edges.csv` columns, with all fields stored as strings.

## License and attribution

Wikidata structured data is available under the Creative Commons CC0 1.0
Universal Public Domain Dedication. Attribution is appreciated:

> Data source: Wikidata contributors, https://www.wikidata.org/ (CC0 1.0).

See https://www.wikidata.org/wiki/Wikidata:Licensing.

