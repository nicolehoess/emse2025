# Reproduction package for "Oops!... I did it again"

The study investigates some threats to validity in complex pipelines of
mining software repositories (MSR) tools for evolutionary software analyses 
and evaluates the tools’ agreement in terms of data, study outcomes and 
conclusions for the same research questions. 

For this purpose, the study conducts a literature review and formally 
replicates three studies on collaboration and coordination, software 
maintenance and software quality from high-ranked venues with the mining
tools [Codeface](https://github.com/lfd/codeface), [git2net](https://github.com/gotec/git2net), 
[GrimoireLab](https://github.com/chaoss/grimoirelab) and [Kaiaulu](https://github.com/sailuh/kaiaulu).

## Repository contents

The study repository has the following structure and can be inspected ad-hoc:
- `analysis/`: contains all bash scripts for the analysis pipeline presented in the paper.
- `data/`: contains the git repositories for analysis and the data extracted by the MSR tools.
- `docker/`: contains scripts for the docker containers.
- `literature/`: contains the annotated tool and study lists (in `venues`) from the literature review.
- `original_studies/`: contains supplementary results from the original studies.
- `plot/`: contains the plots from the paper and the source code to generate them in R.
- `results/`: contains the results data of the replications and comparative analyses.
- `src/`: contains our replication and comparative analysis scripts in Python.
- `tools/`: contains snapshots of the MSR tools Codeface, git2net, GrimoireLab and Kaiaulu as used in the study.

## Setup

### 1. Docker 

The MSR tools used in this study require specific dependencies. To additionally
avoid confusion of analysis results of the same subject projects in different studies, 
we isolate some replication workloads in separate Docker containers:

1. Build the study and tool docker images using:
```
# Study image including git2net and Kaiaulu
docker build -t emse . [2>&1 | tee emse_build.log]

# Codeface image
docker build -t codeface -f Dockerfile_codeface . [2>&1 | tee codeface_build.log]

# GrimoireLab images and containers
docker-compose -f tools/grimoire/snapshot/docker-compose/docker-compose.yml up -d
```

2. Run the following docker containers from the images with the following mounts:
```
# Study container including git2net and Kaiaulu
docker run --name emse -d -t --user emse \
  -v ./data:/home/emse/data \
  -v ./results:/home/emse/results \
  -v ./plot:/home/emse/plot \
  --network docker-compose_default \
  emse

# Codeface replication containers
docker run --name codeface_joblin -d -t --user emse \
  -v ./data:/home/emse/data \
  -v ./results:/home/emse/results \
  -v ./plot:/home/emse/plot \
  codeface
docker run --name codeface_gote -d -t --user emse \
  -v ./data:/home/emse/data \
  -v ./results:/home/emse/results \
  -v ./plot:/home/emse/plot \
  codeface
docker run --name codeface_foucault -d -t --user emse \
  -v ./data:/home/emse/data \
  -v ./results:/home/emse/results \
  -v ./plot:/home/emse/plot \
  codeface
```

### 2. Analyses

We provide separate scripts for each part of the study.

Executing all analysis steps sequentially can be very time-consuming 
(up to several months) and risky due to sporadic parallelisation errors.

For quickly evaluating our replication package, you can exclude subject 
projects from the `project_list` in the respective `analysis.conf` files in 
the `analysis` directory. The scripts below will then only consider the defined
subset of projects. However, be aware that statistical results and visualisations
will differ in this scenario.

Note that composing GrimoireLab immediately starts its analysis pipeline.
Analysing all subject projects, as specified in the `projects_custom.json` in
the `tools/grimoire/snapshot/default-grimoirelab-settings`, will take
several days. Here, you can again save time by removing
individual subject projects from the file. The GrimoireLab analyses have to
be finished before starting with the replications and comparisons.

1. Start the analysis pipeline with git2net and Kaiaulu:
```
docker exec -it emse bash analysis/git2net_kaiaulu.sh
```

2. Start the analysis pipelines with Codeface:
```
docker exec -it codeface_joblin bash analysis/codeface_joblin.sh
docker exec -it codeface_gote bash analysis/codeface_gote.sh
docker exec -it codeface_foucault bash analysis/codeface_foucault.sh
```

3. Before proceeding, ensure that *all* tool containers finished all analyses.

4. Compare data and results across tools:
```
docker exec -it emse bash analysis/comparison.sh
```

5. You can find all analysis results and visualisations in the `results`
and `plot` directories, respectively.
