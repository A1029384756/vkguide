package vk_engine

import "core:container/queue"
import "core:mem/virtual"
import vk "vendor:vulkan"

FrameData :: struct {
	command_pool:        vk.CommandPool,
	main_command_buffer: vk.CommandBuffer,
	swapchain_semaphore: vk.Semaphore,
	render_semaphore:    vk.Semaphore,
	render_fence:        vk.Fence,
	deletion_queue:      DeletionQueue,
}

AllocatedImage :: struct {
	image:      vk.Image,
	image_view: vk.ImageView,
}

DeletionQueue :: struct {
	queue:     queue.Queue(proc()),
	allocator: virtual.Arena,
}

deletion_queue_init :: proc(q: ^DeletionQueue) {
	err := virtual.arena_init_static(&q.allocator)
	assert(err == nil)
	queue.init(&q.queue, allocator = virtual.arena_allocator(&q.allocator))
}

deletion_queue_push :: proc(q: ^DeletionQueue, item: proc()) {
	queue.push_back(&q.queue, item)
}

deletion_queue_flush :: proc(q: ^DeletionQueue) {
	for queue.len(q.queue) > 0 {
		queue.pop_back(&q.queue)()
	}
	queue.clear(&q.queue)
}

deletion_queue_delete :: proc(q: ^DeletionQueue) {
	deletion_queue_flush(q)
	queue.destroy(&q.queue)
	virtual.arena_destroy(&q.allocator)
}
