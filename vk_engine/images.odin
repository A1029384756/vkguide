package vk_engine

import vk "vendor:vulkan"

@(private)
transition_image :: proc(
	cmd: vk.CommandBuffer,
	image: vk.Image,
	current_layout, new_layout: vk.ImageLayout,
) {
	aspect_mask :=
		new_layout == .DEPTH_ATTACHMENT_OPTIMAL \
		? vk.ImageAspectFlag.DEPTH \
		: vk.ImageAspectFlag.COLOR

	image_barrier := vk.ImageMemoryBarrier2 {
		sType            = .MEMORY_BARRIER_2,
		srcStageMask     = {.ALL_COMMANDS},
		dstAccessMask    = {.MEMORY_WRITE, .MEMORY_READ},
		oldLayout        = current_layout,
		newLayout        = new_layout,
		subresourceRange = image_subresource_range({aspect_mask}),
		image            = image,
	}

	dep_info := vk.DependencyInfo {
		sType                   = .DEPENDENCY_INFO,
		imageMemoryBarrierCount = 1,
		pImageMemoryBarriers    = &image_barrier,
	}

	vk.CmdPipelineBarrier2(cmd, &dep_info)
}
