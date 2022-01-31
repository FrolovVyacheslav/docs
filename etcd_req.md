## CPU
Typical clusters need two to four cores to run smoothly.
Heavily loaded etcd deployments, serving thousands of clients or tens of thousands of requests per second. Such heavy deployments usually need eight to sixteen dedicated cores.

## RAM
Typically `8GB` is enough. For heavy deployments with thousands of watchers and millions of keys, allocate `16GB` to `64GB` memory accordingly.

## Disk
Typically 10MB/s will recover 100MB data within 15 seconds. For large clusters, 100MB/s or higher is suggested for recovering 1GB data within 15 seconds.
1GbE is sufficient for common etcd deployments. For large etcd clusters, a 10GbE network will reduce mean time to recovery.

More information and example hardware configurations in [etcd documentation](https://etcd.io/docs/v3.5/op-guide/hardware/#example-hardware-configurations)
