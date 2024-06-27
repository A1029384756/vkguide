package vk_engine

import vk "vendor:vulkan"

@(private)
command_pool_create_info :: proc(
	queue_family_idx: u32,
	flags: vk.CommandPoolCreateFlags,
) -> vk.CommandPoolCreateInfo {
	return vk.CommandPoolCreateInfo {
		sType = .COMMAND_POOL_CREATE_INFO,
		queueFamilyIndex = queue_family_idx,
		flags = flags,
	}
}

@(private)
command_buffer_allocate_info :: proc(
	pool: vk.CommandPool,
	count: u32,
) -> vk.CommandBufferAllocateInfo {
	return vk.CommandBufferAllocateInfo {
		sType = .COMMAND_BUFFER_ALLOCATE_INFO,
		commandPool = pool,
		level = .PRIMARY,
	}
}
