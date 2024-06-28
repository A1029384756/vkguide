package vk_engine

import vk "vendor:vulkan"

@(private)
command_pool_create_info :: proc(
	queue_family_idx: u32,
	flags: vk.CommandPoolCreateFlags,
) -> vk.CommandPoolCreateInfo {
	return {sType = .COMMAND_POOL_CREATE_INFO, queueFamilyIndex = queue_family_idx, flags = flags}
}

@(private)
command_buffer_allocate_info :: proc(
	pool: vk.CommandPool,
	count: u32,
) -> vk.CommandBufferAllocateInfo {
	return {
		sType = .COMMAND_BUFFER_ALLOCATE_INFO,
		commandPool = pool,
		commandBufferCount = 1,
		level = .PRIMARY,
	}
}

@(private)
fence_create_info :: proc(flags: vk.FenceCreateFlags) -> vk.FenceCreateInfo {
	return {sType = .FENCE_CREATE_INFO, flags = flags}
}

@(private)
semaphore_create_info :: proc(flags: vk.SemaphoreCreateFlags) -> vk.SemaphoreCreateInfo {
	return {sType = .SEMAPHORE_CREATE_INFO, flags = flags}
}

@(private)
command_buffer_begin_info :: proc(flags: vk.CommandBufferUsageFlags) -> vk.CommandBufferBeginInfo {
	return {sType = .COMMAND_BUFFER_BEGIN_INFO, flags = flags}
}

@(private)
image_subresource_range :: proc(aspect_mask: vk.ImageAspectFlags) -> vk.ImageSubresourceRange {
	return {
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
	return {
		sType = .SUBMIT_INFO,
		semaphore = semaphore,
		stageMask = {stage_mask},
		deviceIndex = 0,
		value = 1,
	}
}

@(private)
command_buffer_submit_info :: proc(cmd: vk.CommandBuffer) -> vk.CommandBufferSubmitInfo {
	return {sType = .SUBMIT_INFO, commandBuffer = cmd, deviceMask = 0}
}

@(private)
submit_info :: proc(
	cmd: ^vk.CommandBufferSubmitInfo,
	signal_semaphore_info, wait_semaphore_info: ^vk.SemaphoreSubmitInfo,
) -> vk.SubmitInfo2 {
	return {
		sType = .SUBMIT_INFO_2,
		waitSemaphoreInfoCount = wait_semaphore_info == nil ? 0 : 1,
		pWaitSemaphoreInfos = wait_semaphore_info,
		signalSemaphoreInfoCount = signal_semaphore_info == nil ? 0 : 1,
		pSignalSemaphoreInfos = signal_semaphore_info,
		commandBufferInfoCount = 1,
		pCommandBufferInfos = cmd,
	}
}

@(private)
image_create_info :: proc(
	format: vk.Format,
	usage_flags: vk.ImageUsageFlags,
	extent: vk.Extent3D,
) -> vk.ImageCreateInfo {
	return {
		sType = .IMAGE_CREATE_INFO,
		imageType = .D2,
		format = format,
		extent = extent,
		mipLevels = 1,
		arrayLayers = 1,
		samples = {._1},
		tiling = .OPTIMAL,
		usage = usage_flags,
	}
}

@(private)
imageview_create_info :: proc(
	format: vk.Format,
	image: vk.Image,
	aspect_flags: vk.ImageAspectFlags,
) -> vk.ImageViewCreateInfo {
	return {
		sType = .IMAGE_VIEW_CREATE_INFO,
		viewType = .D2,
		image = image,
		format = format,
		subresourceRange = {
			baseMipLevel = 0,
			levelCount = 1,
			baseArrayLayer = 0,
			layerCount = 1,
			aspectMask = aspect_flags,
		},
	}
}
