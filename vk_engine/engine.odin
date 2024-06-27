package vk_engine

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
}

FRAME_OVERLAP :: 2
FrameData :: struct {
	command_pool:        vk.CommandPool,
	main_command_buffer: vk.CommandBuffer,
}

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

	vk_engine_init_vulkan(self)
	vk_engine_init_swapchain(self)
	vk_engine_init_commands(self)
	vk_engine_init_sync_structures(self)
	self.initialized = true
}

vk_engine_cleanup :: proc(self: ^VulkanEngine) {
	if self.initialized {
		vk.DeviceWaitIdle(self.device.ptr)
		for i in 0 ..< 2 {
			vk.DestroyCommandPool(self.device.ptr, self.frames[i].command_pool, nil)
		}

		sdl.DestroyWindow(self.window)
	}

	vk_engine_destroy_swapchain(self)
	vkb.destroy_device(self.device)
	vkb.destroy_physical_device(self.chosen_gpu)
	vkb.destroy_instance(self.instance)

	loaded_engine = nil
}

vk_engine_draw :: proc(self: ^VulkanEngine) {
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

	for i in 0 ..< FRAME_OVERLAP {
		res_create_cmd_pool := vk.CreateCommandPool(
			self.device.ptr,
			&command_pool_info,
			nil,
			&self.frames[i].command_pool,
		)
		assert(res_create_cmd_pool == .SUCCESS)

		cmd_alloc_info := command_buffer_allocate_info(self.frames[i].command_pool, 1)
		res_alloc_cmd_buf := vk.AllocateCommandBuffers(
			self.device.ptr,
			&cmd_alloc_info,
			&self.frames[i].main_command_buffer,
		)
		assert(res_alloc_cmd_buf == .SUCCESS)
	}
}

@(private)
vk_engine_init_sync_structures :: proc(self: ^VulkanEngine) {
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
vk_engine_get_current_frame :: proc(self: ^VulkanEngine) -> ^FrameData {
	return &self.frames[self.frame_number % FRAME_OVERLAP]
}
