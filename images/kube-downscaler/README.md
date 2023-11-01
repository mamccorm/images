<!--monopod:start-->
# kube-downscaler
| | |
| - | - |
| **OCI Reference** | `cgr.dev/chainguard/kube-downscaler` |


* [View Image in Chainguard Academy](https://edu.chainguard.dev/chainguard/chainguard-images/reference/kube-downscaler/overview/)
* [View Image Catalog](https://console.enforce.dev/images/catalog) for a full list of available tags.
* [Contact Chainguard](https://www.chainguard.dev/chainguard-images) for enterprise support, SLAs, and access to older tags.*

---
<!--monopod:end-->

kube-downscaler is a Kubernetes add-on that enables automatic scaling down of
specific deployments or stateful sets during off-peak hours or periods of
inactivity.

This is a minimal, Wolfi-based image of [kube-downscaler](https://codeberg.org/hjacobs/kube-downscaler).

## Get It!

The image is available on `cgr.dev`:

```bash
docker pull cgr.dev/chainguard/kube-downscaler:latest
```

## Usage

This image is intended to be deployed in kubernetes. Refer to the upstream
reposiories [usage documentation](https://codeberg.org/hjacobs/kube-downscaler)
for detailed usage information.

The upstream git repository includes a [helm chart](https://codeberg.org/hjacobs/kube-downscaler/src/branch/main/deploy),
but this can also be found [published here](https://artifacthub.io/packages/helm/deliveryhero/kube-downscaler).

Example using chart, overriding with the chainguard image:

## Deploy

```bash
helm repo add deliveryhero https://charts.deliveryhero.io/

helm install my-release deliveryhero/kube-downscaler \
  --set image.repository=cgr.dev/chainguard/kube-downscaler \
  --set image.tag=latest
```
