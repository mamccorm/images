# DO NOT EDIT - this file is autogenerated by tfgen

output "summary" {
  value = merge(
    {
      basename(path.module) = {
        "ref"    = module.velero.image_ref
        "config" = module.velero.config
        "tags"   = ["latest"]
      }
  })
}

