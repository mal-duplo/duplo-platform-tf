tenant_id = "f286a9d3-b049-4502-a137-f7940970f5a2"
eks_version = "1.33"

# --- GPU pool: scale-from-zero, cap at 1 ---
gpu_enabled             = true
gpu_capacity            = "g4dn.xlarge"
gpu_instance_count      = 0
gpu_min_instance_count  = 0
gpu_max_instance_count  = 1
gpu_can_scale_from_zero = true

# optional savings:
gpu_use_spot_instances  = true
gpu_max_spot_price      = null

# small root disk for demos
gpu_os_disk_size        = 40

# label + taint so only GPU workloads land here
gpu_metadata = {
  KubeletExtraArgs = "--node-labels=workload=gpu,accelerator=nvidia,nodegroup=gpu-ng --register-with-taints=nvidia.com/gpu=present:NoSchedule"
}
gpu_taints = [
  { key = "nvidia.com/gpu", value = "present", effect = "NoSchedule" }
]