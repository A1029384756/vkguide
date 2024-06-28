package main

import "core:fmt"
import "core:log"
import e "vk_engine"

main :: proc() {
	when ODIN_DEBUG {
		context.logger = log.create_console_logger(opt = {.Level, .Terminal_Color})
		defer log.destroy_console_logger(context.logger)
	}

	engine := e.VulkanEngine {
		window_extent = {1700, 900},
	}
	e.vk_engine_init(&engine)
	e.vk_engine_run(&engine)
	e.vk_engine_cleanup(&engine)
}
