# kubernetes-elasticsearch-cluster

Elasticsearch 6.6.0 cluster on top of Kubernetes made easy.

These files are the project manifests and image generation files used on the article [https://medium.com/@carlosedp/log-aggregation-with-elasticsearch-fluentd-and-kibana-stack-on-arm64-kubernetes-cluster-516fb64025f9](https://medium.com/@carlosedp/log-aggregation-with-elasticsearch-fluentd-and-kibana-stack-on-arm64-kubernetes-cluster-516fb64025f9).

The images in this project were built for the ARM64 and AMD64 platform. A hybrid cluster (Intel and ARM) can be created using these files.

## Table of Contents

- [kubernetes-elasticsearch-cluster](#kubernetes-elasticsearch-cluster)
  - [Table of Contents](#table-of-contents)
  - [Abstract](#abstract)
  - [(Very) Important notes](#very-important-notes)
  - [Pre-requisites](#pre-requisites)
  - [Build images](#build-images)
    - [Deploy](#deploy)
    - [Access the service](#access-the-service)
  - [Pod anti-affinity](#pod-anti-affinity)
  - [Availability](#availability)
  - [Install plug-ins](#install-plug-ins)
  - [Clean-up with Curator](#clean-up-with-curator)
  - [Kibana](#kibana)
  - [FAQ](#faq)
  - [Troubleshooting](#troubleshooting)
    - [No up-and-running site-local](#no-up-and-running-site-local)
    - [(IPv6) org.elasticsearch.bootstrap.StartupException: BindTransportException](#ipv6-orgelasticsearchbootstrapstartupexception-bindtransportexception)

## Abstract

[Elasticsearch best-practices recommend to separate nodes in three roles](https://www.elastic.co/guide/en/elasticsearch/reference/6.5/modules-node.html):

- `Master` nodes - intended for clustering management only, no data, no HTTP API
- `Client` nodes - intended for client usage, no data, with HTTP API
- `Data` nodes - intended for storing and indexing data, no HTTP API

This is the recommended way to deploy ElasticSearch in case your nodes are not CPU/Memory limited. The manifests on `separate-roles` show how to provision a production grade scenario consisting of 1 master, 1 client and 2 data nodes. The set of manifests in the root deploys a three-node ES cluster where all nodes perform all roles.

## (Very) Important notes

- Elasticsearch pods need for an init-container to run in privileged mode, so it can set some VM options. For that to happen, the `kubelet` should be running with args `--allow-privileged`, otherwise
the init-container will fail to run.

- By default, `ES_JAVA_OPTS` is set to `-Xms512m -Xmx512m` for the master node and `-Xms1G -Xmx1G` for the client and data nodes. This is a *low* value but possible to be used on ARM boards with 4GB of RAM. One can change this in the deployment descriptors available in this repository. In the full-role nodes, all nodes start with 1GB heap.

- In this project,the pods use the Default `StorageClass` for storing data in each data node container. It could be adapted to other storage targets according to one's needs.

- The all pods (master, data and ingest) are deployed as a `StatefulSet`. These use a `volumeClaimTemplates` to provision persistent storage for each pod.

- By default, `PROCESSORS` is set to `1` with a limit of `3` CPUs. This may not be enough for some deployments, especially at startup time. Adjust `resources.limits.cpu` and/or `livenessProbe` accordingly if required. Note that `resources.limits.cpu` must be an integer.

## Pre-requisites

- Kubernetes cluster with (tested with v1.9.3 and 1.13.1 on-premises cluster).
- `kubectl` configured to access the cluster master API Server
- For curator jobs to be cleaned atomatically, the `- --feature-gates=TTLAfterFinished=true` feature gate should be enabled on the static manifests (`/etc/kubernetes/manifests`).

## Build images

The project uses images built for the ARM64 and AMD64 (x86) platform stored in my [Dockerhub account](https://hub.docker.com/r/carlosedp/). The images can be built in the `images` dir with the provided script or manually. As default, the images will be built by the script for the platform it's running on.

### Deploy

Use the `deploy` script or follow it manually (these commands deploy the full stack).

You have two options, one deployng nodes with separate roles (master, client and data) or having all nodes with all roles.
This can be uncommented on the `deploy` script or using the instruction below.

Create the namespace and cofiguration:

```bash
kubectl create namespace logging
alias kctl='kubectl --namespace logging'

kctl apply -f es-configmap.yaml
```

Or to have a three-node cluster with all roles, use this:

```bash
kctl apply -f es-full-svc.yaml
kctl apply -f es-full-statefulset.yaml
```

To have separate roles on each node, use this:

```bash
# Deploy Elasticsearch master node and wait until it's up
kctl apply -f ./separate-roles/es-master-svc.yaml
kctl apply -f ./separate-roles/es-master-statefulset.yaml
until kctl rollout status statefulset es-master  > /dev/null 2>&1; do sleep 1; printf "."; done

# Deploy Elasticsearch client node and wait until it's up
kctl apply -f ./separate-roles/es-ingest-svc.yaml
kctl apply -f ./separate-roles/es-ingest-statefulset.yaml
until kctl rollout status deployment es-client  > /dev/null 2>&1; do sleep 1; printf "."; done

# Deploy Elasticsearch data node and wait until it's up
kctl apply -f ./separate-roles/es-data-svc.yaml
kctl apply -f ./separate-roles/es-data-statefulset.yaml
until kctl rollout status statefulset es-data  > /dev/null 2>&1; do sleep 1; printf "."; done
```

This is common to any option:

```bash
# Deploy Curator
kctl apply -f es-curator-configmap.yaml
kctl apply -f es-curator-cronjob.yaml

# Deploy Cerebro
kctl apply -f cerebro.yaml
kctl apply -f cerebro-external-ingress.yaml

# Deploy Kibana
kctl apply -f kibana-configmap.yaml
kctl apply -f kibana-svc.yaml
kctl apply -f kibana-deployment.yaml
kctl apply -f kibana-external-ingress.yaml

# Deploy Fluentd
kctl apply -f fluentd-configmap.yaml
kctl apply -f fluentd-daemonset.yaml
```

Let's check if everything is working properly:
Check one of the Elasticsearch master nodes logs:

```bash
$ kubectl get svc,deployment,statefulsets,pods -l component=elasticsearch
NAME                                     TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
service/elasticsearch                    NodePort    10.106.88.175   <none>        9200:30230/TCP   73m
service/elasticsearch-data-discovery     ClusterIP   None            <none>        9300/TCP         6h8m
service/elasticsearch-discovery          ClusterIP   None            <none>        9300/TCP         6h4m
service/elasticsearch-ingest-discovery   ClusterIP   None            <none>        9300/TCP         6h11m

NAME                         READY   AGE
statefulset.apps/es-data     2/2     102m
statefulset.apps/es-ingest   1/1     98m
statefulset.apps/es-master   1/1     6h50m

NAME              READY   STATUS    RESTARTS   AGE
pod/es-data-0     1/1     Running   0          59m
pod/es-data-1     1/1     Running   0          95m
pod/es-ingest-0   1/1     Running   0          98m
pod/es-master-0   1/1     Running   0          6h46m
```

Check one of the Elasticsearch master nodes logs:

```bash
$ kubectl logs po/es-master-6f6449b7f-jwbcb
chown: changing ownership of '/elasticsearch/config/elasticsearch.yml': Read-only file system
[2019-01-16T14:06:37,974][WARN ][o.e.c.l.LogConfigurator  ] [es-master-0] Some logging configurations have %marker but don't have %node_name. We will automatically add %node_name to the pattern to ease the migration for users who customize log4j2.properties but will stop this behavior in 7.0. You should manually replace `%node_name` with `[%node_name]%marker ` in these locations:
  /elasticsearch/config/log4j2.properties
[2019-01-16T14:06:42,312][INFO ][o.e.e.NodeEnvironment    ] [es-master-0] using [1] data paths, mounts [[/data (192.168.1.62:/data/kubernetes-storage/logging-elasticsearch-master-es-master-0-pvc-3f9d2bc1-1997-11e9-b14b-00e04c3bb2dc)]], net usable_space [821.8gb], net total_space [879.2gb], types [nfs4]
[2019-01-16T14:06:42,314][INFO ][o.e.e.NodeEnvironment    ] [es-master-0] heap size [494.9mb], compressed ordinary object pointers [true]
[2019-01-16T14:06:42,348][INFO ][o.e.n.Node               ] [es-master-0] node name [es-master-0], node ID [FZPGD1bqRbW105MYCBtnYw]
[2019-01-16T14:06:42,350][INFO ][o.e.n.Node               ] [es-master-0] version[6.5.4], pid[1], build[default/tar/d2ef93d/2018-12-17T21:17:40.758843Z], OS[Linux/4.4.138/aarch64], JVM[Oracle Corporation/OpenJDK 64-Bit Server VM/1.8.0_181/25.181-b13]
[2019-01-16T14:06:42,351][INFO ][o.e.n.Node               ] [es-master-0] JVM arguments [-XX:+UseConcMarkSweepGC, -XX:CMSInitiatingOccupancyFraction=75, -XX:+UseCMSInitiatingOccupancyOnly, -XX:+DisableExplicitGC, -XX:+AlwaysPreTouch, -Xss1m, -Djava.awt.headless=true, -Dfile.encoding=UTF-8, -Djna.nosys=true, -Djdk.io.permissionsUseCanonicalPath=true, -Dio.netty.noUnsafe=true, -Dio.netty.noKeySetOptimization=true, -Dlog4j.shutdownHookEnabled=false, -Dlog4j2.disable.jmx=true, -Dlog4j.skipJansi=true, -XX:+HeapDumpOnOutOfMemoryError, -Xms512m, -Xmx512m, -Des.path.home=/elasticsearch, -Des.path.conf=/elasticsearch/config, -Des.distribution.flavor=default, -Des.distribution.type=tar]
[2019-01-16T14:06:58,712][WARN ][o.e.d.c.s.Settings       ] [es-master-0] [http.enabled] setting was deprecated in Elasticsearch and will be removed in a future release! See the breaking changes documentation for the next major version.
[2019-01-16T14:07:22,304][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [aggs-matrix-stats]
[2019-01-16T14:07:22,305][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [analysis-common]
[2019-01-16T14:07:22,305][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [ingest-common]
[2019-01-16T14:07:22,305][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [lang-expression]
[2019-01-16T14:07:22,306][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [lang-mustache]
[2019-01-16T14:07:22,306][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [lang-painless]
[2019-01-16T14:07:22,306][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [mapper-extras]
[2019-01-16T14:07:22,306][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [parent-join]
[2019-01-16T14:07:22,306][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [percolator]
[2019-01-16T14:07:22,307][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [rank-eval]
[2019-01-16T14:07:22,307][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [reindex]
[2019-01-16T14:07:22,308][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [repository-url]
[2019-01-16T14:07:22,308][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [transport-netty4]
[2019-01-16T14:07:22,309][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [tribe]
[2019-01-16T14:07:22,309][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [x-pack-ccr]
[2019-01-16T14:07:22,309][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [x-pack-core]
[2019-01-16T14:07:22,310][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [x-pack-deprecation]
[2019-01-16T14:07:22,310][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [x-pack-graph]
[2019-01-16T14:07:22,311][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [x-pack-logstash]
[2019-01-16T14:07:22,311][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [x-pack-ml]
[2019-01-16T14:07:22,312][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [x-pack-monitoring]
[2019-01-16T14:07:22,312][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [x-pack-rollup]
[2019-01-16T14:07:22,312][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [x-pack-security]
[2019-01-16T14:07:22,313][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [x-pack-sql]
[2019-01-16T14:07:22,313][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [x-pack-upgrade]
[2019-01-16T14:07:22,313][INFO ][o.e.p.PluginsService     ] [es-master-0] loaded module [x-pack-watcher]
[2019-01-16T14:07:22,316][INFO ][o.e.p.PluginsService     ] [es-master-0] no plugins loaded
[2019-01-16T14:08:38,128][INFO ][o.e.x.s.a.s.FileRolesStore] [es-master-0] parsed [0] roles from file [/elasticsearch/config/roles.yml]
[2019-01-16T14:08:56,727][INFO ][o.e.d.DiscoveryModule    ] [es-master-0] using discovery type [zen] and host providers [settings]
[2019-01-16T14:09:04,910][INFO ][o.e.n.Node               ] [es-master-0] initialized
[2019-01-16T14:09:04,912][INFO ][o.e.n.Node               ] [es-master-0] starting ...
[2019-01-16T14:09:06,029][INFO ][o.e.t.TransportService   ] [es-master-0] publish_address {10.44.0.2:9300}, bound_addresses {10.44.0.2:9300}
[2019-01-16T14:09:06,210][INFO ][o.e.b.BootstrapChecks    ] [es-master-0] bound or publishing to a non-loopback address, enforcing bootstrap checks
[2019-01-16T14:09:09,707][INFO ][o.e.c.s.MasterService    ] [es-master-0] zen-disco-elected-as-master ([0] nodes joined), reason: new_master {es-master-0}{FZPGD1bqRbW105MYCBtnYw}{9cYQt93zRFyW5szy5vSkJA}{10.44.0.2}{10.44.0.2:9300}{xpack.installed=true}
[2019-01-16T14:09:09,738][INFO ][o.e.c.s.ClusterApplierService] [es-master-0] new_master {es-master-0}{FZPGD1bqRbW105MYCBtnYw}{9cYQt93zRFyW5szy5vSkJA}{10.44.0.2}{10.44.0.2:9300}{xpack.installed=true}, reason: apply cluster state (from master [master {es-master-0}{FZPGD1bqRbW105MYCBtnYw}{9cYQt93zRFyW5szy5vSkJA}{10.44.0.2}{10.44.0.2:9300}{xpack.installed=true} committed version [1] source [zen-disco-elected-as-master ([0] nodes joined)]])
[2019-01-16T14:09:09,805][INFO ][o.e.n.Node               ] [es-master-0] started
```

As we can assert, the cluster is up and running. Easy, wasn't it?

### Access the service

-Don't forget* that services in Kubernetes are only acessible from containers in the cluster. For different behavior one should [configure the creation of an external load-balancer](https://kubernetes.io/docs/tasks/access-application-cluster/create-external-load-balancer) or use an ingress as currently included in the project.

-Note:* if you are using one of the cloud providers which support external load balancers, setting the type field to "LoadBalancer" will provision a load balancer for your Service. You can add the field in `es-ingest-svc.yaml`.

```bash
$ kubectl get svc elasticsearch
NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
elasticsearch   ClusterIP   10.100.220.56   <none>        9200/TCP   3m
```

From any host on the Kubernetes cluster (that's running `kube-proxy` or similar), run:

```bash
curl http://10.100.220.56:9200
```

One should see something similar to the following:

```json
{
  "name" : "es-ingest-0",
  "cluster_name" : "myesdb",
  "cluster_uuid" : "y_wU9c5rRZKqRF8jlxKJMg",
  "version" : {
    "number" : "6.5.4",
    "build_flavor" : "default",
    "build_type" : "tar",
    "build_hash" : "d2ef93d",
    "build_date" : "2018-12-17T21:17:40.758843Z",
    "build_snapshot" : false,
    "lucene_version" : "7.5.0",
    "minimum_wire_compatibility_version" : "5.6.0",
    "minimum_index_compatibility_version" : "5.0.0"
  },
  "tagline" : "You Know, for Search"
}
```

Or if one wants to see cluster information:

```bash
curl http://10.100.220.56:9200/_cluster/health?pretty
```

One should see something similar to the following:

```json
{
  "cluster_name" : "myesdb",
  "status" : "green",
  "timed_out" : false,
  "number_of_nodes" : 4,
  "number_of_data_nodes" : 2,
  "active_primary_shards" : 70,
  "active_shards" : 138,
  "relocating_shards" : 0,
  "initializing_shards" : 0,
  "unassigned_shards" : 0,
  "delayed_unassigned_shards" : 0,
  "number_of_pending_tasks" : 0,
  "number_of_in_flight_fetch" : 0,
  "task_max_waiting_in_queue_millis" : 0,
  "active_shards_percent_as_number" : 100.0
}
```

## Pod anti-affinity

One of the main advantages of running Elasticsearch on top of Kubernetes is how resilient the cluster becomes, particularly during
node restarts. However if all data pods are scheduled onto the same node(s), this advantage decreases significantly and may even
result in no data pods being available.

It is then **highly recommended**, in the context of the solution described in this repository, that one adopts [pod anti-affinity](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#inter-pod-affinity-and-anti-affinity-beta-feature)
in order to guarantee that two data pods will never run on the same node.

Here's an example:

```yaml
spec:
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: component
              operator: In
              values:
              - elasticsearch
            - key: role
              operator: In
              values:
              - data
          topologyKey: kubernetes.io/hostname
  containers:
  - (...)
```

## Availability

If one wants to ensure that no more than `n` Elasticsearch nodes will be unavailable at a time, one can optionally (change and) apply the following manifests:

```bash
kubectl create -f pdb/es-master-pdb.yaml
kubectl create -f pdb/es-data-pdb.yaml
```

-*Note:** This is an advanced subject and one should only put it in practice if one understands clearly what it means both in the Kubernetes and Elasticsearch contexts. For more information, please consult [Pod Disruptions](https://kubernetes.io/docs/concepts/workloads/pods/disruptions).

## Install plug-ins

The image used in this repo is standard. However, one can install additional plug-ins at will by simply specifying the `ES_PLUGINS_INSTALL` environment variable in the desired pod descriptors. For instance, to install [Google Cloud Storage](https://www.elastic.co/guide/en/elasticsearch/plugins/current/repository-gcs.html) and [S3](https://www.elastic.co/guide/en/elasticsearch/plugins/current/repository-s3.html) plug-ins it would be like follows:

```yaml
- name: "ES_PLUGINS_INSTALL"
  value: "repository-gcs,repository-s3"
```

This is not tested in current image, please report on Issues any errors or successes.

## Clean-up with Curator

Additionally, one can run a [CronJob](http://kubernetes.io/docs/user-guide/cron-jobs/) that will periodically run [Curator](https://github.com/elastic/curator) to clean up indices (or do other actions on the Elasticsearch cluster).

```bash
kubectl create -f es-curator-config.yaml
kubectl create -f es-curator_v1beta1.yaml
```

Please, confirm the job has been created.

```bash
$ kubectl get cronjobs
NAME      SCHEDULE    SUSPEND   ACTIVE    LAST-SCHEDULE
curator   1 0 * * *   False     0         <none>
```

The job is configured to run once a day at _1 minute past midnight and delete indices that are older than 30 days_.

-*Notes**

- One can change the schedule by editing the cron notation in `es-curator-cronjob.yaml`.
- One can change the action (e.g. delete older than 3 days) by editing the `es-curator-configmap.yaml`.
- The definition of the `action_file.yaml` is quite self-explaining for simple set-ups. For more advanced configuration options, please consult the [Curator Documentation](https://www.elastic.co/guide/en/elasticsearch/client/curator/current/index.html).

If one wants to remove the curator job, just run:

```bash
kubectl delete cronjob curator
kubectl delete configmap curator-config
```

## Kibana

Kibana will be available through service `kibana`, and one will be able to access it from within the cluster or proxy it through the Kubernetes API Server, as follows:

There is also an Ingress to expose the service publicly or simply use the service nodeport.
In the case one proceeds to do so, one must change the environment variable `SERVER_BASEPATH` to the match their environment.

## FAQ

**Why does `NUMBER_OF_MASTERS` differ from number of master-replicas?**

The default value for this environment variable is 2, meaning a cluster will need a minimum of 2 master nodes to operate. If a cluster has 3 masters and one dies, the cluster still works. Minimum master nodes are usually `n/2 + 1`, where `n` is the number of master nodes in a cluster. If a cluster has 5 master nodes, one should have a minimum of 3, less than that and the cluster _stops_. If one scales the number of masters, make sure to update the minimum number of master nodes through the Elasticsearch API as setting environment variable will only work on cluster setup. [More info](https://www.elastic.co/guide/en/elasticsearch/guide/1.x/_important_configuration_changes.html#_minimum_master_nodes).

**How can I customize `elasticsearch.yaml`?**

Read a different config file by settings env var `ES_PATH_CONF=/path/to/my/config/` [(see the Elasticsearch docs for more)](https://www.elastic.co/guide/en/elasticsearch/reference/current/settings.html#config-files-location) or edit the provided ConfigMap in file `es-configmap.yaml`.

## Troubleshooting

### No up-and-running site-local

One of the errors one may come across when running the setup is the following error:

```bash
[2016-11-29T01:28:36,515][WARN ][o.e.b.ElasticsearchUncaughtExceptionHandler] [] uncaught exception in thread [main]
org.elasticsearch.bootstrap.StartupException: java.lang.IllegalArgumentException: No up-and-running site-local (private) addresses found, got [name:lo (lo), name:eth0 (eth0)]
at org.elasticsearch.bootstrap.Elasticsearch.init(Elasticsearch.java:116) ~[elasticsearch-5.0.1.jar:5.0.1]
at org.elasticsearch.bootstrap.Elasticsearch.execute(Elasticsearch.java:103) ~[elasticsearch-5.0.1.jar:5.0.1]
at org.elasticsearch.cli.SettingCommand.execute(SettingCommand.java:54) ~[elasticsearch-5.0.1.jar:5.0.1]
at org.elasticsearch.cli.Command.mainWithoutErrorHandling(Command.java:96) ~[elasticsearch-5.0.1.jar:5.0.1]
at org.elasticsearch.cli.Command.main(Command.java:62) ~[elasticsearch-5.0.1.jar:5.0.1]
at org.elasticsearch.bootstrap.Elasticsearch.main(Elasticsearch.java:80) ~[elasticsearch-5.0.1.jar:5.0.1]
at org.elasticsearch.bootstrap.Elasticsearch.main(Elasticsearch.java:73) ~[elasticsearch-5.0.1.jar:5.0.1]
Caused by: java.lang.IllegalArgumentException: No up-and-running site-local (private) addresses found, got [name:lo (lo), name:eth0 (eth0)]
at org.elasticsearch.common.network.NetworkUtils.getSiteLocalAddresses(NetworkUtils.java:187) ~[elasticsearch-5.0.1.jar:5.0.1]
at org.elasticsearch.common.network.NetworkService.resolveInternal(NetworkService.java:246) ~[elasticsearch-5.0.1.jar:5.0.1]
at org.elasticsearch.common.network.NetworkService.resolveInetAddresses(NetworkService.java:220) ~[elasticsearch-5.0.1.jar:5.0.1]
at org.elasticsearch.common.network.NetworkService.resolveBindHostAddresses(NetworkService.java:130) ~[elasticsearch-5.0.1.jar:5.0.1]
at org.elasticsearch.transport.TcpTransport.bindServer(TcpTransport.java:575) ~[elasticsearch-5.0.1.jar:5.0.1]
at org.elasticsearch.transport.netty4.Netty4Transport.doStart(Netty4Transport.java:182) ~[?:?]
at org.elasticsearch.common.component.AbstractLifecycleComponent.start(AbstractLifecycleComponent.java:68) ~[elasticsearch-5.0.1.jar:5.0.1]
at org.elasticsearch.transport.TransportService.doStart(TransportService.java:182) ~[elasticsearch-5.0.1.jar:5.0.1]
at org.elasticsearch.common.component.AbstractLifecycleComponent.start(AbstractLifecycleComponent.java:68) ~[elasticsearch-5.0.1.jar:5.0.1]
at org.elasticsearch.node.Node.start(Node.java:525) ~[elasticsearch-5.0.1.jar:5.0.1]
at org.elasticsearch.bootstrap.Bootstrap.start(Bootstrap.java:211) ~[elasticsearch-5.0.1.jar:5.0.1]
at org.elasticsearch.bootstrap.Bootstrap.init(Bootstrap.java:288) ~[elasticsearch-5.0.1.jar:5.0.1]
at org.elasticsearch.bootstrap.Elasticsearch.init(Elasticsearch.java:112) ~[elasticsearch-5.0.1.jar:5.0.1]
... 6 more
[2016-11-29T01:28:37,448][INFO ][o.e.n.Node               ] [kIEYQSE] stopping ...
[2016-11-29T01:28:37,451][INFO ][o.e.n.Node               ] [kIEYQSE] stopped
[2016-11-29T01:28:37,452][INFO ][o.e.n.Node               ] [kIEYQSE] closing ...
[2016-11-29T01:28:37,464][INFO ][o.e.n.Node               ] [kIEYQSE] closed
```

This is related to how the container binds to network ports (defaults to ``_local_``). It will need to match the actual node network interface name, which depends on what OS and infrastructure provider one uses. For instance, if the primary interface on the node is `p1p1` then that is the value that needs to be set for the `NETWORK_HOST` environment variable.
Please see [the documentation](https://github.com/pires/docker-elasticsearch#environment-variables) for reference of options.

In order to workaround this, set `NETWORK_HOST` environment variable in the pod descriptors as follows:

```yaml
- name: "NETWORK_HOST"
  value: "_eth0_" #_p1p1_ if interface name is p1p1, _ens4_ if interface name is ens4, and so on.
```

### (IPv6) org.elasticsearch.bootstrap.StartupException: BindTransportException

Intermittent failures occur when the local network interface has both IPv4 and IPv6 addresses, and Elasticsearch tries to bind to the IPv6 address first.
If the IPv4 address is chosen first, Elasticsearch starts correctly.

In order to workaround this, set `NETWORK_HOST` environment variable in the pod descriptors as follows:

```yaml
- name: "NETWORK_HOST"
  value: "_eth0:ipv4_" #_p1p1:ipv4_ if interface name is p1p1, _ens4:ipv4_ if interface name is ens4, and so on.
```
