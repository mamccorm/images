terraform {
  required_providers {
    oci  = { source = "chainguard-dev/oci" }
    helm = { source = "hashicorp/helm" }
  }
}

variable "digests" {
  description = "The image digests to run tests over."
  type = object({
    server   = string
    cluster  = string
    sentinel = string
  })
}


locals { parsed = { for k, v in var.digests : k => provider::oci::parse(v) } }

data "imagetest_inventory" "this" {}

resource "imagetest_harness_k3s" "this" {
  name      = "redis-bitnami"
  inventory = data.imagetest_inventory.this

  sandbox = {
    mounts = [
      {
        source      = path.module
        destination = "/tests"
      }
    ]
  }
}

module "helm" {
  source = "../../../tflib/imagetest/helm"

  name      = "redis"
  namespace = "redis"
  chart     = "oci://registry-1.docker.io/bitnamicharts/redis"

  values = {
    image = {
      registry   = local.parsed.registry
      repository = local.parsed.repo
      digest     = local.parsed.digest
    }
    sentinel = {
      enabled = true
      image = {
        registry   = local.parsed["sentinel"].registry
        repository = local.parsed["sentinel"].repo
        digest     = local.parsed["sentinel"].digest
      }
    }
  }
}
