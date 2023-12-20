<!--monopod:start-->
# falco
| | |
| - | - |
| **OCI Reference** | `cgr.dev/chainguard/falco` |


* [View Image in Chainguard Academy](https://edu.chainguard.dev/chainguard/chainguard-images/reference/falco/overview/)
* [View Image Catalog](https://console.enforce.dev/images/catalog) for a full list of available tags.
* [Contact Chainguard](https://www.chainguard.dev/chainguard-images) for enterprise support, SLAs, and access to older tags.*

---
<!--monopod:end-->

<!--overview:start-->
A minimal, wolfi-based image for falco-no-driver. This streamlined variant of Falco, designed for real-time security monitoring on Linux, replaces the traditional kernel module with eBPF technology, thus enhancing portability in containerized environments.
<!--overview:end-->

<!--getting:start-->
## Get It!
The image is available on `cgr.dev`:

```
docker pull cgr.dev/chainguard/falco:latest
```
<!--getting:end-->

<!--body:start-->

## How does falco-no-driver differ over falco?

The primary distinction between falco, and falco-no-driver (i.e this image),
lies in their approach to monitoring system calls.

Falco requires a kernel-specific module to hook into the system an monitor
system calls.

In contrast, falco-no-driver does not depend on a kernel-specific module,
instead leveraging eBPF (modern-bpf driver). This eliminates the need for
loading sepatate kernel modules and makes the image more portable, between
environments.

When we talk about falco-no-driver, this means no kernel drivers.
falco-no-driver is bundled with the modern-bpf driver itself. This can be
confusing and is worth clarifying.

## Disclaimer: falco doesn't run on macOS!

If you are intending on testing this image locally, note that falco does not run
on macOS. If you attempt to run the image it will fail to launch. See the
[following falco documentation](https://falco.org/blog/falco-apple-silicon/),
where they recommend setting up a linux VM.

# Running falco-no-driver

Please refer to the [upstream documentation](https://falco.org/docs/install-operate/running/)
for full instructions on how to configure and run falco-no-driver. The below
are basic examples utilising the chainguard image.

> Note: You can launch the image on mac by passing in the `--nodriver` argument
> instead of `--modern-bpf`, but other than running the service, it'll not
> collect anything, so shouldn't be used in place of a linux environment for testing.

### Docker

#### Running with modern-bpf

Refer to the [upstream documentation](https://falco.org/docs/install-operate/running/)
upstream documentation for full instructions on how to run falco-no-driver.

Below is one example taken from the falco documentaton, updated to use the
chainguard image:

```bash
docker run --rm -i -t \
    --privileged \
    -v /var/run/docker.sock:/host/var/run/docker.sock \
    -v /proc:/host/proc:ro \
    cgr.dev/chainguard/falco:latest falco --modern-bpf
```

### Running without a

### Helm chart



<!--body:end-->
