package vk_engine

import "core:container/queue"
import "core:math"
import "core:time"
import vkb "odin-vk-bootstrap/vkb"
import sdl "vendor:sdl2"
import vk "vendor:vulkan"

VulkanEngine :: struct {
	initialized:           bool,
	frame_number:          i32,
	stop_rendering:        bool,
	window_extent:         vk.Extent2D,
	window:                ^sdl.Window,
	// instance fields
	instance:              ^vkb.Instance,
	debug_messenger:       vk.DebugUtilsMessengerEXT,
	chosen_gpu:            ^vkb.Physical_Device,
	device:                ^vkb.Device,
	surface:               vk.SurfaceKHR,
	// swapchain fields
	swapchain:             ^vkb.Swapchain,
	swapchain_images:      []vk.Image,
	swapchain_image_views: []vk.ImageView,
	// commands
	frames:                [FRAME_OVERLAP]FrameData,
	graphics_queue:        vk.Queue,
	graphics_queue_family: u32,
	// allocation info
	main_deletion_queue:   DeletionQueue,
}

FRAME_OVERLAP :: 2
VK_VALIDATE :: #config(VK_VALIDATE, true)
loaded_engine: ^VulkanEngine

vk_engine_init :: proc(self: ^VulkanEngine) {
	assert(loaded_engine == nil)
	loaded_engine = self

	sdl.Init({.VIDEO})
	self.window = sdl.CreateWindow(
		"Engine",
		sdl.WINDOWPOS_UNDEFINED,
		sdl.WINDOWPOS_UNDEFINED,
		i32(self.window_extent.width),
		i32(self.window_extent.height),
		{.VULKAN, .ALLOW_HIGHDPI},
	)

	vk.load_proc_addresses(sdl.Vulkan_GetVkGetInstanceProcAddr())

	for &frame in self.frames {
		deletion_queue_init(&frame.deletion_queue)
	}

	vk_engine_init_vulkan(self)
	vk_engine_init_swapchain(self)
	vk_engine_init_commands(self)
	vk_engine_init_sync_structures(self)
	self.initialized = true
}

vk_engine_cleanup :: proc(self: ^VulkanEngine) {
	if self.initialized {
		vk.DeviceWaitIdle(self.device.ptr)
		for &frame in self.frames {
			vk.DestroyCommandPool(self.device.ptr, frame.command_pool, nil)
			vk.DestroyFence(self.device.ptr, frame.render_fence, nil)
			vk.DestroySemaphore(self.device.ptr, frame.render_semaphore, nil)
			vk.DestroySemaphore(self.device.ptr, frame.swapchain_semaphore, nil)

			deletion_queue_flush(&frame.deletion_queue)
		}

		sdl.DestroyWindow(self.window)
	}

	deletion_queue_flush(&self.main_deletion_queue)

	vk_engine_destroy_swapchain(self)
	vkb.destroy_device(self.device)
	vkb.destroy_physical_device(self.chosen_gpu)
	vkb.destroy_instance(self.instance)

	loaded_engine = nil
}

vk_engine_draw :: proc(self: ^VulkanEngine) {
	fence_wait_res := vk.WaitForFences(
		self.device.ptr,
		1,
		&get_current_frame(self).render_fence,
		true,
		1000000000,
	)
	assert(fence_wait_res == .SUCCESS)

	deletion_queue_flush(&get_current_frame(self).deletion_queue)

	fence_reset_res := vk.ResetFences(self.device.ptr, 1, &get_current_frame(self).render_fence)
	assert(fence_reset_res == .SUCCESS)

	swapchain_image_idx: u32
	next_image_res := vk.AcquireNextImageKHR(
		self.device.ptr,
		self.swapchain.ptr,
		1000000000,
		get_current_frame(self).swapchain_semaphore,
		get_current_frame(self).render_fence,
		&swapchain_image_idx,
	)
	assert(next_image_res == .SUCCESS)

	cmd := get_current_frame(self).main_command_buffer
	buf_reset_res := vk.ResetCommandBuffer(cmd, {.RELEASE_RESOURCES})
	assert(buf_reset_res == .SUCCESS)

	cmd_begin_info := command_buffer_begin_info({.ONE_TIME_SUBMIT})
	buf_begin_res := vk.BeginCommandBuffer(cmd, &cmd_begin_info)
	assert(buf_begin_res == .SUCCESS)

	transition_image(cmd, self.swapchain_images[swapchain_image_idx], .UNDEFINED, .GENERAL)

	flash := abs(math.sin_f32(f32(self.frame_number) / 120))
	clear_value := vk.ClearColorValue {
		float32 = {0, 0, flash, 1},
	}

	clear_range := image_subresource_range({.COLOR})
	vk.CmdClearColorImage(
		cmd,
		self.swapchain_images[swapchain_image_idx],
		.GENERAL,
		&clear_value,
		1,
		&clear_range,
	)

	transition_image(cmd, self.swapchain_images[swapchain_image_idx], .GENERAL, .PRESENT_SRC_KHR)
	buf_end_res := vk.EndCommandBuffer(cmd)
	assert(buf_begin_res == .SUCCESS)

	cmd_info := command_buffer_submit_info(cmd)
	wait_info := sephamore_submit_info(
		.COLOR_ATTACHMENT_OUTPUT,
		get_current_frame(self).swapchain_semaphore,
	)
	signal_info := sephamore_submit_info(.ALL_GRAPHICS, get_current_frame(self).render_semaphore)

	submit := submit_info(&cmd_info, &signal_info, &wait_info)
	queue_submit_res := vk.QueueSubmit2(
		self.graphics_queue,
		1,
		&submit,
		get_current_frame(self).render_fence,
	)
	assert(queue_submit_res == .SUCCESS)

	present_info := vk.PresentInfoKHR {
		sType              = .PRESENT_INFO_KHR,
		pSwapchains        = &self.swapchain.ptr,
		swapchainCount     = 1,
		pWaitSemaphores    = &get_current_frame(self).render_semaphore,
		waitSemaphoreCount = 1,
		pImageIndices      = &swapchain_image_idx,
	}

	queue_present_res := vk.QueuePresentKHR(self.graphics_queue, &present_info)
	assert(queue_present_res == .SUCCESS)

	self.frame_number += 1
}

vk_engine_run :: proc(self: ^VulkanEngine) {
	e: sdl.Event
	quit := false

	for !quit {
		for sdl.PollEvent(&e) {
			if e.type == .QUIT {
				quit = true
			}

			if e.type == .WINDOWEVENT {
				#partial switch e.window.event {
				case .MINIMIZED:
					self.stop_rendering = true
				case .RESTORED:
					self.stop_rendering = false
				}
			}

			if self.stop_rendering {
				time.sleep(100 * time.Millisecond)
				continue
			}
		}

		vk_engine_draw(self)
	}
}

@(private)
vk_engine_init_vulkan :: proc(self: ^VulkanEngine) {
	builder, builder_init_err := vkb.init_instance_builder()
	assert(builder_init_err == nil)
	defer vkb.destroy_instance_builder(&builder)

	vkb.instance_set_app_name(&builder)
	vkb.instance_request_validation_layers(&builder, VK_VALIDATE)
	vkb.instance_use_default_debug_messenger(&builder)
	vkb.instance_require_api_version(&builder, vk.API_VERSION_1_3)

	instance, builder_build_err := vkb.build_instance(&builder)
	assert(builder_build_err == nil)

	self.instance = instance
	self.debug_messenger = instance.debug_messenger

	sdl.Vulkan_CreateSurface(self.window, self.instance.ptr, &self.surface)

	features := vk.PhysicalDeviceVulkan13Features {
		sType            = .PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
		dynamicRendering = true,
		synchronization2 = true,
	}

	features12 := vk.PhysicalDeviceVulkan12Features {
		sType               = .PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
		bufferDeviceAddress = true,
		descriptorIndexing  = true,
	}

	selector, selector_init_err := vkb.init_physical_device_selector(instance)
	assert(selector_init_err == nil)
	defer vkb.destroy_physical_device_selector(&selector)

	vkb.selector_set_minimum_version(&selector, vk.API_VERSION_1_3)
	vkb.selector_set_required_features_13(&selector, features)
	vkb.selector_set_required_features_12(&selector, features12)
	vkb.selector_set_surface(&selector, self.surface)
	phys_device, selector_selection_err := vkb.select_physical_device(&selector)
	assert(selector_selection_err == nil)

	device_builder, device_build_init_err := vkb.init_device_builder(phys_device)
	assert(device_build_init_err == nil)
	defer vkb.destroy_device_builder(&device_builder)

	vk_device, device_build_err := vkb.build_device(&device_builder)
	assert(device_build_err == nil)

	self.device = vk_device
	self.chosen_gpu = phys_device

	graphics_queue, get_queue_err := vkb.device_get_queue(self.device, .Graphics)
	assert(get_queue_err == nil)
	self.graphics_queue = graphics_queue

	graphics_queue_idx, get_queue_idx_err := vkb.device_get_queue_index(self.device, .Graphics)
	assert(get_queue_idx_err == nil)
	self.graphics_queue_family = graphics_queue_idx
}

@(private)
vk_engine_init_swapchain :: proc(self: ^VulkanEngine) {
	vk_engine_create_swapchain(self, self.window_extent.width, self.window_extent.height)
}

@(private)
vk_engine_init_commands :: proc(self: ^VulkanEngine) {
	command_pool_info := command_pool_create_info(
		self.graphics_queue_family,
		{.RESET_COMMAND_BUFFER},
	)

	for &frame in self.frames {
		res_create_cmd_pool := vk.CreateCommandPool(
			self.device.ptr,
			&command_pool_info,
			nil,
			&frame.command_pool,
		)
		assert(res_create_cmd_pool == .SUCCESS)

		cmd_alloc_info := command_buffer_allocate_info(frame.command_pool, 1)
		res_alloc_cmd_buf := vk.AllocateCommandBuffers(
			self.device.ptr,
			&cmd_alloc_info,
			&frame.main_command_buffer,
		)
		assert(res_alloc_cmd_buf == .SUCCESS)
	}
}

@(private)
vk_engine_init_sync_structures :: proc(self: ^VulkanEngine) {
	fence_create_info := fence_create_info({.SIGNALED})
	semaphore_create_info := semaphore_create_info({})

	for &frame in self.frames {
		fence_create_res := vk.CreateFence(
			self.device.ptr,
			&fence_create_info,
			nil,
			&frame.render_fence,
		)
		assert(fence_create_res == .SUCCESS)

		swapchain_semaphore_res := vk.CreateSemaphore(
			self.device.ptr,
			&semaphore_create_info,
			nil,
			&frame.swapchain_semaphore,
		)
		assert(swapchain_semaphore_res == .SUCCESS)

		render_semaphore_res := vk.CreateSemaphore(
			self.device.ptr,
			&semaphore_create_info,
			nil,
			&frame.render_semaphore,
		)
		assert(render_semaphore_res == .SUCCESS)
	}
}

@(private)
vk_engine_create_swapchain :: proc(self: ^VulkanEngine, width: u32, height: u32) {
	swapchain_builder, builder_init_err := vkb.init_swapchain_builder(
		self.chosen_gpu,
		self.device,
		self.surface,
	)
	assert(builder_init_err == nil)
	defer vkb.destroy_swapchain_builder(&swapchain_builder)

	swapchain, swapchain_err := vkb.build_swapchain(&swapchain_builder)
	swapchain_images, swapchain_images_err := vkb.swapchain_get_images(swapchain)
	swapchain_image_views, swapchain_image_views_err := vkb.swapchain_get_image_views(swapchain)
	assert(swapchain_err == nil)
	assert(swapchain_images_err == nil)
	assert(swapchain_image_views_err == nil)

	self.swapchain = swapchain
	self.swapchain_images = swapchain_images
	self.swapchain_image_views = swapchain_image_views
}

@(private)
vk_engine_destroy_swapchain :: proc(self: ^VulkanEngine) {
	delete(self.swapchain_images)

	vkb.swapchain_destroy_image_views(self.swapchain, &self.swapchain_image_views)
	delete(self.swapchain_image_views)
	vkb.destroy_swapchain(self.swapchain)
}

@(private)
get_current_frame :: proc(self: ^VulkanEngine) -> ^FrameData {
	return &self.frames[self.frame_number % FRAME_OVERLAP]
}
