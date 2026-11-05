# Image repository service

The images VPS runs the repository service behind the existing HTTPS proxy.
`modules/services/osctl-repo-server.nix` defines its site options. The module is
disabled unless `services.osctl-repo-server-site.enable` is set. Public routing
also requires `publicServing`; enabling the service alone exposes run repositories
under `/runs/` while leaving the existing public static repository in place.

The service package comes from the selected vpsAdminOS input as
`pkgs.osctl-repo-server`. Select a reviewed source through the `os-staging` confctl
channel before setting the package option. Use `confctl inputs channel set --commit
os-staging vpsadminos REVISION` for an exact feature revision and retain its input
graph in the rollout record. Input publication and deployment each require their
normal authorization; this document does not authorize either operation.

## Configuration and access

Supply the repository and instance names, package, storage limits, run/export
leases, log limits and three distinct public SSH keys. No production budget or
credential is supplied by the module. Measure runner CPU/RAM/scratch, image VPS
free space and concurrent read/upload load before choosing limits. Reserve room
for current public images, active-run references, SQLite/WAL, incoming files,
private logs and a verified recovery export. Creating another run pins metadata
and files; it does not copy all image payloads.

The service owns `/var/lib/osctl-repo-server` by default. Its role sockets live in
`/run/osctl-repo-server` with mode 0660 and separate producer, publisher and admin
groups. Each role has a separate SSH user, forced local `ctl --socket` command
and `restrict` key options. Producers cannot publish. Keep the publishing key in
a protected job outside builder VMs. External repository/workflow/ref admission
and secret separation must be verified before using persistent privileged runners.
Do not infer trust from a caller's claimed branch or source hash.

The Unix control protocol and immutable file/SQLite schema belong to
[osctl-repo-server](https://github.com/vpsfreecz/vpsadminos/tree/staging/osctl-repo-server).
Only its writer changes catalogs or reclaims managed files. Native local add/rm,
destructive native GC and legacy rsync must never write its managed data.
Use native tools against separate offline fixtures or exported recovery trees.

## HTTP, dashboard and requester logs

Public and sealed-run v1 paths stream the selected archive or ZFS file without
redirects. GET, HEAD, range responses and conditional requests remain compatible.
Public date validators are conservative to avoid stale 304 responses after
same-second replacement or rollback. Sealed run validators remain stable.
Expired runs return 410 and unfinished runs return not-ready; there is no static
or live-public fallback for a failed selected candidate.

The HTTPS edge replaces `X-Repo-Client-IP` with its socket requester address.
Internal nginx accepts that value only from the configured edge address and
otherwise forwards its own requester address. Go accepts it only from loopback
nginx. Verify effective IPv4/IPv6 socket peers, header overwrite and direct-bypass
behavior before activation. Do not extend the trust list to an entire internal
network. Keep all public artifact routes through Go so measurements are complete.

The public HTML dashboard and `/dashboard.json` contain catalog, build-state,
storage and daily request aggregates. They contain no requester IPs, User-Agents,
raw request logs or work-item error messages. Counts are local to the named
repository/instance, not fleet totals or unique people. HEAD, INDEX, 206 ranges,
304 validation, failed requests and retries are distinct events. Bytes written
do not prove a client received an entire image or imported a container.

Requester details appear only in `/var/log/osctl-repo-server/access.jsonl`.
The directory is 0700 and files are 0600. Each line is schema 1 JSON: UTC timestamp,
request ID, repository/instance, trusted client IP, socket peer, method, path
without query, status, bytes, duration in milliseconds, public/run scope and run
key, request kind, resolved tuple/format/file ID, bounded User-Agent, Range and
Content-Range, and completion/interruption outcome. Missing resolved fields mean
the request did not select an artifact. Raw headers and query strings are omitted.
Use existing SSH/log access to inspect these files; they are not dashboard assets.

The service rotates by configured bytes and total file count, including the active
file; configure finite retention to suit operations. Daily SQLite aggregates have
a day window and row cap. The event queue is bounded. Logging/statistics failures
and queue drops increase public aggregate health counters but do not fail or delay
an image response. Queue pressure can leave measurement gaps. Application/control
diagnostics go to the journal separately. No GeoIP or requester identity service
is involved.

## Staging expiry and reclamation

Enabling the service also enables `osctl-repo-server-maintenance.timer`. It runs
a single oneshot every fifteen minutes, including a catch-up tick after downtime.
The dedicated `repo-maintenance` user connects
only to the administrator Unix socket; it does not read or delete storage files
directly. Each tick requests `expire` and then `reclaim`, with a fresh request ID
for each operation. An error from expiry stops that invocation before reclamation.
The unit requires the repository service to be active and its admin socket to
exist. It has a 120-second start timeout and cannot overlap itself.

`maintenance.onCalendar` and `maintenance.timeoutSeconds` configure these
bounds. The existing writer expires only elapsed run leases and reclaims only
unreferenced files. Active leases, public files and other retained references stay
protected; this timer does not run or change the public keep-count GC policy.
Inspect failures in the maintenance unit's journal. The next scheduled invocation
checks the current server state again; the unit has no transport retry loop or
separate cleanup daemon.

## Adoption and recovery

1. Resolve preflight access, disk budgets, runner admission and trusted requester
   routing. Test the reviewed package with disposable catalogs before production.
2. Exclude every legacy writer, including the build-host weekly timer, active VM
   build/post-run rsync, manual rsync and native local writers/GC. Stop or drain
   them only under an authorized deployment and machine ownership. An inactive
   timer does not prove its already-running service or a manual writer is gone.
3. Capture one coherent live INDEX and every referenced file/format/hash, plus
   aliases/defaults and exact system/source identities. Protect that baseline
   from writes. Import/adopt through the administrator control protocol and prove
   catalog/hash equivalence before replacing the public route. If adopting files
   in place, set `adoptedDirectory` explicitly and arrange service ownership only
   after old writers are excluded; the module does not recursively change owners.
4. Verify the service's public catalog and old direct/cached clients, complete
   pinned run, missing-candidate failure, exact public GC and private access logs.
   Set `publicServing` only after these checks. No static fallback may expose
   logically pruned files. Record the exact coherent import and recovery export.
5. Enable protected default-source publication after verification. Retire the old
   schedule under the separate configuration deployment package. Preserve every
   successful intervening update when recovering.

Back up SQLite with the service's retained immutable file references. Verify a
portable generation export and complete import before relying on it. To return
to static serving, materialize the intended current catalog and reconcile the
legacy source before restoring its writer. Restoring an old directory or rsync
source after new publications would discard those updates. Retain recovery
metadata, exact catalog/file hashes and deployment/input evidence in the rollout
record. Files pinned by active runs remain retained even after public GC removes
their public URL; reclamation belongs to the service.
