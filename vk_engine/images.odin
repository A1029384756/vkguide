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

@(private)
copy_image_to_image :: proc(
	cmd: vk.CommandBuffer,
	source: vk.Image,
	destination: vk.Image,
	src_size: vk.Extent2D,
	dst_size: vk.Extent2D,
) {
	blit_region := vk.ImageBlit2 {
		sType = .IMAGE_BLIT_2,
		srcOffsets = {{}, {i32(src_size.width), i32(src_size.height), 1}},
		dstOffsets = {{}, {i32(dst_size.width), i32(dst_size.height), 1}},
		srcSubresource = {aspectMask = {.COLOR}, baseArrayLayer = 0, layerCount = 1, mipLevel = 0},
		dstSubresource = {aspectMask = {.COLOR}, baseArrayLayer = 0, layerCount = 1, mipLevel = 0},
	}

	blit_info := vk.BlitImageInfo2 {
		sType          = .BLIT_IMAGE_INFO_2,
		dstImage       = destination,
		dstImageLayout = .TRANSFER_DST_OPTIMAL,
		srcImage       = source,
		srcImageLayout = .TRANSFER_SRC_OPTIMAL,
		filter         = .LINEAR,
		regionCount    = 1,
		pRegions       = &blit_region,
	}

	vk.CmdBlitImage2(cmd, &blit_info)
}
