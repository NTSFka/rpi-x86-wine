
export PATH := "/tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/bin:$(PATH)"
KERNEL := kernel7
IMAGE_FILE_SRC=$(shell cat .image-file 2> /dev/null)
LOOP=$(shell cat .loopdev 2> /dev/null)
MOUNT_DIR=./mnt

all: build

git-init:
	git submodule init linux
	git submodule init tools

build: git-init
	$(MAKE) -j4 -C linux ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- bcm2709_defconfig
	# TODO: change configuration
	$(MAKE) -j4 -C linux ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- zImage modules dtbs

install: build mount
	# Install modules
	$(MAKE) -C linux ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH=$(MOUNT_DIR)/data modules_install
	cp $(MOUNT_DIR)/boot/$(KERNEL).img $(KERNEL).backup.img
	sudo cp linux/arch/arm/boot/zImage $(MOUNT_DIR)/boot/$(KERNEL).img
	sudo cp linux/arch/arm/boot/dts/*.dtb $(MOUNT_DIR)/boot/
	sudo cp linux/arch/arm/boot/dts/overlays/*.dtb* $(MOUNT_DIR)/boot/overlays/
	sudo cp linux/arch/arm/boot/dts/overlays/README $(MOUNT_DIR)/boot/overlays/

choose-image:
	@echo "Writing selected image to .image-file"
	@echo $(IMAGE) > .image-file

mount:
	# Mounts selected image as loop devices
	@if test -z $(IMAGE_FILE_SRC); then echo "Image not set. Call '$(MAKE) IMAGE=<image> choose-image'"; exit 1; fi
	@if test -f .loopdev; then echo "Already mounted. Call '$(MAKE) umount'"; exit 1; fi
	@echo "Creating loop devices..."
	@$(eval $@_LOOP := $(shell sudo losetup -fP --show $(IMAGE_FILE_SRC)))
	@echo $($@_LOOP) > .loopdev
	@echo "Mounting devices to directory $(MOUNT_DIR)..."
	@mkdir -p $(MOUNT_DIR)/boot
	@mkdir -p $(MOUNT_DIR)/data
	@sudo mount $($@_LOOP)p1 $(MOUNT_DIR)/boot
	@sudo mount $($@_LOOP)p2 $(MOUNT_DIR)/data

umount:
	# Unmounts already mounted image
	@if test -z $(LOOP); then echo "Nothing mounted"; exit 1; fi
	@echo "Unmounting devices..."
	@sudo umount $(MOUNT_DIR)/data
	@sudo umount $(MOUNT_DIR)/boot
	@echo "Removing loop devices..."
	@sudo losetup -d $(LOOP)
	@rm .loopdev

