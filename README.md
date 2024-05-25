# gc-benchmarks

A small benchmark, currently only comparing GHC and Koka on basic
allocation-heavy examples.

Installation and running:
- For GHC: install `stack` from [here](https://docs.haskellstack.org/en/stable/)
  or through [`ghcup`](https://www.haskell.org/ghcup/), then hit `stack run` in
  the `ghc` directory. You can change RTS options by `stack run -- +RTS
  <options>`.
- For Koka: install [Koka](https://koka-lang.github.io/koka/doc/index.html),
  then hit `koka bench.kk -O2 -e` in the `koka` directory.

## Benchmarks

There's a normalization-by-evaluation implementation for pure lambda calculus,
with a normalizer and a beta-conversion checker. We use Church-encoded binary
trees for benchmarks.

- `Tree NF`: normalizes a complete binary tree of depth 20, without any in-memory
  sharing of subtrees.
- `Tree Conv`: checks beta-conversion of the same tree against itself, again no structure sharing.
- `Tree force`: folds over the same tree without actually building up a normalized result in memory;
  this is possible because of the Church-coding.
- `Tree NF share`: same as `Tree NF` except subtrees are shared in memory.
- `Tree Conv share`: same as `Tree Conv` except subtrees are shared in memory.

The practical relevance here is that beta-conversion of lambda terms is used
heavily in typechecking for every dependently typed language.

Reuse estimation is not easy for the NbE benchmarks. We can do the following:
look at GHC heap allocation just for `Tree NF` and `Tree force`. We know that
the difference between them is the quotation of the resuting normal tree, and we
also know that quotation should reuse the `Var` and `App` nodes in Koka, so
essentially all allocation in quotation is reused. From that we get a rough
estimate of reuse.

- Tree NF heap allocation: 9060M
- Tree force heap allocation: 7550M

Hence, around 16.7% of allocations should be reused in Tree NF in Koka.

Second, we switch over to binary trees in the host language, defined as ADTs.
Here we look at an extremely simple benchmark where we can precisely control the
ratio of allocation reuse in Koka. We create a tree and the map over it N times.

The creation of the initial tree has no reuse in Koka, but every subsequent
mappping has 100% reused allocations. Hence, mapping once has 1/2 total reuse,
twice 2/3 and so on.

GHC has no reuse so it copies the tree once whenever the new generation heap is
filled up. So the size of the new heap is the key factor for overheads.

## Test system

- OS: Ubuntu 22.04
- CPU: AMD Ryzen 7700X, stock voltage & frequency, no thermal throttling (cooler: Arctic LF III 280mm AIO).
- RAM: DDR5 6000 MT/s 32-38-38 2x16GB, using Buildzoid secondary timings (https://www.youtube.com/watch?v=dlYxmRcdLVw)

## Results

Build used:
- ghc 9.8.2 with `-O1 -threaded -fworker-wrapper-cbv -rtsopts`
- Koka 3.1.1 with gcc 11.4.0 with `-O2`.

RSS (resident set size) is reported from `/usr/bin/time -v` in all cases. I used
`/usr/bin/time -v` on the generated executables in the `.stack` and `.koka`
directories.

### GHC

**GHC +RTS -N8 -A16M -qb0 -s** (parallel copy, 128M arena)

|   |   |
|---|---|
|RSS:                 |352M |
|Tree NF:             |0.0585551657 s |
|Tree Conv:           |0.1000499138 s |
|Tree force:          |0.0308369736 s |
|Tree NF share:       |0.0085617557 s |
|Tree Conv share:     |0.0034091996 s |
|Maptree 1/2:         |0.0093272052 s |
|Maptree 2/3:         |0.0187194441 s |
|Maptree 3/4:         |0.0269395563 s |
|Maptree 4/5:         |0.0362283250 s |

**GHC +RTS -N8 -A8M -qb0 -s** (parallel copy, 64M arena)

|   |   |
|---|---|
|RSS:                 |285M|
|Tree NF:             |0.073256601 s|
|Tree Conv:           |0.098881875 s|
|Tree force:          |0.031688582 s|
|Tree NF share:       |0.023207658 s|
|Tree Conv share:     |0.003229039 s|
|Maptree 1/2:         |0.015514388 s|
|Maptree 2/3:         |0.027273184 s|
|Maptree 3/4:         |0.038060693 s|
|Maptree 4/5:         |0.048828525 s|

**GHC +RTS -N8 -A4M -qb0 -s** (parallel copy, 32M arena)

|   |   |
|---|---|
|RSS:                | 241M|
|Tree NF:            | 0.0770440263 s|
|Tree Conv:          | 0.1035009512 s|
|Tree force:         | 0.0309666622 s|
|Tree NF share:      | 0.0292150692 s|
|Tree Conv share:    | 0.0033002176 s|
|Maptree 1/2:        | 0.0157076319 s|
|Maptree 2/3:        | 0.0286112121 s|
|Maptree 3/4:        | 0.0429614781 s|
|Maptree 4/5:        | 0.0539486119 s|

**GHC +RTS -s** (default: no parallel copying, 4M arena)

|   |   |
|---|---|
|RSS:                 |230M|
|Tree NF:             |0.178919555 s|
|Tree Conv:           |0.178580515 s|
|Tree force:          |0.030624470 s|
|Tree NF share:       |0.087825472 s|
|Tree Conv share:     |0.003207482 s|
|Maptree 1/2:         |0.051536897 s|
|Maptree 2/3:         |0.094009938 s|
|Maptree 3/4:         |0.132026914 s|
|Maptree 4/5:         |0.166693688 s|

**GHC +RTS -N1 -G1 -A128M -s** (semispace collector, single threaded, 128M minimum heap)

|   |   |
|---|---|
|RSS:                 |348M|
|Tree NF:             |0.1085490721 s|
|Tree Conv:           |0.2061490365 s|
|Tree force:          |0.0323833961 s|
|Tree NF share:       |0.0229806656 s|
|Tree Conv share:     |0.0032150955 s|
|Maptree 1/2:         |0.0111321662 s|
|Maptree 2/3:         |0.0283437464 s|
|Maptree 3/4:         |0.0420059896 s|
|Maptree 4/5:         |0.0512852726 s|

**GHC +RTS -N1 -G1 -A256M -s** (semispace collector, single threaded, 256M minimum heap)

|   |   |
|---|---|
|RSS:                 |427M|
|Tree NF:             |0.0897052893 s|
|Tree Conv:           |0.1602031396 s|
|Tree force:          |0.0301616668 s|
|Tree NF share:       |0.0140957306 s|
|Tree Conv share:     |0.0032227575 s|
|Maptree 1/2:         |0.0114329003 s|
|Maptree 2/3:         |0.0238688409 s|
|Maptree 3/4:         |0.0340323339 s|
|Maptree 4/5:         |0.0433066331 s|

### Koka

|   |   |
|---|---|
|RSS:                 |101M|
|Tree NF:             |0.133963 s|
|Tree conv:           |0.221093 s|
|Tree force:          |0.100207 s|
|Tree NF share:       |0.029871 s|
|Tree conv share:     |0.010162 s|
|Maptree 1/2:         |0.018467 s|
|Maptree 2/3:         |0.022434 s|
|Maptree 3/4:         |0.027088 s|
|Maptree 4/5:         |0.031958 s|
