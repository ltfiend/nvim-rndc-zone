.PHONY: test

PLUGIN_PATH := /home/ubuntu/Git/nvim-rndc-zone
DOCKER_IMAGE := registry.devries.tv/neodocker:v0.11.5

test:
	docker run --rm \
		-v $(HOME)/Git:/home/ubuntu/Git:rw \
		-v $(HOME)/.local/share/nvim:/home/ubuntu/.local/share/nvim:rw \
		--user ubuntu \
		--workdir $(PLUGIN_PATH) \
		$(DOCKER_IMAGE) --headless -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
