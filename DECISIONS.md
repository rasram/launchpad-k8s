# Architecture Decisions

This document records the load-bearing decisions behind LaunchPad-K8s and the
reasoning that would otherwise live only in someone's head.

## Why KEDA instead of CPU-based HPA for build-worker

A build worker spends almost all of its wall-clock time waiting — cloning a repo,
pulling base images, waiting on a registry push. During that time its CPU sits at
roughly 0–2%. The work that defines "load" for this service is not CPU cycles; it
is the number of build jobs sitting in the `build-jobs` Kafka topic. A CPU-based
HorizontalPodAutoscaler reads the wrong signal entirely: 500 jobs could be queued
while the autoscaler observes "2% CPU, nothing to do" and keeps a single pod. The
queue would drain at one-pod throughput while the metric the HPA trusts says
everything is fine.

KEDA scales on the semantically correct signal: Kafka consumer lag, which *is* the
count of pending jobs. We configure one pod per `lagThreshold` pending jobs (5 in
dev, 3 in prod), so the worker fleet grows in direct proportion to the backlog and
shrinks as it clears. The scaling decision now tracks the actual unit of work
instead of a proxy that happens to be flat for this workload.

The second reason is cost. KEDA's `minReplicaCount: 0` gives true scale-to-zero:
when the build queue is empty there are zero build-worker pods and zero spend. A
standard HPA cannot express this — it requires `minReplicas >= 1`, so you always
pay for at least one idle worker. For a platform where builds are bursty and idle
periods are long, scale-to-zero is the difference between paying for capacity you
use and paying for capacity that waits. KEDA brings the deployment back from zero
the moment lag crosses the threshold, typically within ~15 seconds.

## Why GitOps with ArgoCD instead of kubectl in CI

Running `kubectl apply` from a CI pipeline puts the cluster's desired state inside
the pipeline: the truth of "what is supposed to be running" becomes a function of
which job ran last and what arguments it used. That state is ephemeral, hard to
audit, and impossible to diff. Anyone with cluster credentials can also apply
changes out of band that CI never sees, and nothing reconciles the difference.

GitOps inverts this. The desired state lives in git as declarative manifests, and
ArgoCD continuously reconciles the cluster toward what git says. Deploying is a
commit; the pull request *is* the change-review surface; the git history *is* the
deployment audit log. There is exactly one path to production and it is reviewable.

ArgoCD's `selfHeal: true` closes the drift gap: if someone runs `kubectl edit` in
production, ArgoCD reverts it back to the committed state automatically. `prune:
true` deletes resources that were removed from git, so deletions are as governed as
additions. Rollback stops being a special procedure and becomes `git revert` — push
the revert and ArgoCD syncs the cluster back to the previous known-good state.

## Why Helm multi-env overlays instead of separate manifests

Dev, staging, and prod share well over 90% of their manifest structure — the same
Deployments, Services, probes, ScaledObject, and Ingress. Maintaining three
separate copies guarantees they drift: a fix applied to prod gets forgotten in
staging, and the environments stop being comparable. A single chart with per-
environment value overlays keeps one source of truth for structure and lets each
environment override only what genuinely differs.

What differs is small and explicit: replica counts, resource limits, KEDA lag
thresholds and ceilings, ingress hostnames, and the cert-manager issuer.
`values.yaml` holds dev defaults; `values.staging.yaml` and `values.prod.yaml`
override just those keys. Reading the prod overlay tells you exactly how prod
deviates from dev and nothing else — the diff is the documentation.

## Why upload-service uses CPU HPA but build-worker uses KEDA

upload-service is a stateless HTTP handler. Its load is request throughput, and for
a request/response service CPU utilization is a faithful proxy for throughput: more
concurrent requests means more CPU, and shedding load means less. A CPU-targeted
HorizontalPodAutoscaler is exactly the right tool here, and reaching for KEDA would
add a queueing abstraction the service does not have.

build-worker is an event consumer. Its load is queue depth, and its CPU is flat and
uninformative. The correct signal is Kafka consumer lag, which only KEDA reads. The
point is not that KEDA is newer or better in the abstract — it is that the scaling
signal must match the workload. Using CPU for the HTTP service and lag for the
queue consumer shows the choice is driven by the workload's nature, not by reflex.

## What I would add at production scale

Pod autoscaling only solves half the elasticity problem. KEDA can ask for twenty
build-worker pods, but if the cluster has no room they sit Pending. I would add
**Karpenter** (or Cluster Autoscaler) so node capacity scales with pod demand —
KEDA scales pods, Karpenter scales the nodes underneath them, and scale-to-zero
extends to the node level. I would also add **PodDisruptionBudgets** and tuned
`terminationGracePeriodSeconds` so in-flight builds drain cleanly during node
consolidation.

On the platform side: **External Secrets Operator** so secrets come from a real
manager (Vault / AWS Secrets Manager) instead of base64 in a Kubernetes Secret;
**NetworkPolicies** to restrict pod-to-pod traffic to the paths that should exist;
**Velero** for backup and disaster recovery of cluster state and persistent data;
and **Prometheus alerting rules** on sustained lag and stuck scale-ups so the
autoscaling system is itself observable and paged on, not just graphed.
