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
    commandBufferCount =1 ,
		level = .PRIMARY,
	}
}

@(private)
fence_create_info :: proc(flags: vk.FenceCreateFlags) -> vk.FenceCreateInfo {
	return vk.FenceCreateInfo{sType = .FENCE_CREATE_INFO, flags = flags}
}

@(private)
semaphore_create_info :: proc(flags: vk.SemaphoreCreateFlags) -> vk.SemaphoreCreateInfo {
	return vk.SemaphoreCreateInfo{sType = .SEMAPHORE_CREATE_INFO, flags = flags}
}

@(private)
command_buffer_begin_info :: proc(flags: vk.CommandBufferUsageFlags) -> vk.CommandBufferBeginInfo {
	return vk.CommandBufferBeginInfo{sType = .COMMAND_BUFFER_BEGIN_INFO, flags = flags}
}

@(private)
image_subresource_range :: proc(aspect_mask: vk.ImageAspectFlags) -> vk.ImageSubresourceRange {
	return vk.ImageSubresourceRange {
		aspectMask = aspect_mask,
		baseMipLevel = 0,
		levelCount = vk.REMAINING_MIP_LEVELS,
		baseArrayLayer = 0,
		layerCount = vk.REMAINING_ARRAY_LAYERS,
	}
}

@(private)
sephamore_submit_info :: proc(
	stage_mask: vk.PipelineStageFlag2,
	semaphore: vk.Semaphore,
) -> vk.SemaphoreSubmitInfo {
	return vk.SemaphoreSubmitInfo {
		sType = .SUBMIT_INFO,
		semaphore = semaphore,
		stageMask = {stage_mask},
		deviceIndex = 0,
		value = 1,
	}
}

@(private)
command_buffer_submit_info :: proc(cmd: vk.CommandBuffer) -> vk.CommandBufferSubmitInfo {
	return vk.CommandBufferSubmitInfo{sType = .SUBMIT_INFO, commandBuffer = cmd, deviceMask = 0}
}

@(private)
submit_info :: proc(
	cmd: ^vk.CommandBufferSubmitInfo,
	signal_semaphore_info, wait_semaphore_info: ^vk.SemaphoreSubmitInfo,
) -> vk.SubmitInfo2 {
	return vk.SubmitInfo2 {
		sType = .SUBMIT_INFO_2,
		waitSemaphoreInfoCount = wait_semaphore_info == nil ? 0 : 1,
		pWaitSemaphoreInfos = wait_semaphore_info,
		signalSemaphoreInfoCount = signal_semaphore_info == nil ? 0 : 1,
		pSignalSemaphoreInfos = signal_semaphore_info,
		commandBufferInfoCount = 1,
		pCommandBufferInfos = cmd,
	}
}
