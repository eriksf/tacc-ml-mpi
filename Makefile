.PHONY: docker clean
.SILENT: docker

SHELL = bash

ORG := tacc
CUDA := 12.2.2
CUDA_ARM := 12.4.1
PUSH ?= 0
CACHE ?= 1
DETECTED_OS := $(shell uname -s 2>/dev/null || echo Unknown)

ifeq "$(CACHE)" "0"
    NOCACHE:=--no-cache
else
    NOCACHE:=
endif

BUILD = docker build -t $(ORG)/tacc-base:$(@) -f $(word 1,$^) $(NOCACHE)
PUSHC = [ "$(PUSH)" -eq "1" ] && docker push $(ORG)/tacc-base:$@ || echo "not pushing $@"
####################################
# CFLAGS
####################################
AMD64 := -O2 -pipe -march=x86-64 -ftree-vectorize -mtune=core-avx2
#ARM64 :=

####################################
# Sanity checks
####################################
docker:
	docker info 1> /dev/null 2> /dev/null && \
	if [ ! $$? -eq 0 ]; then \
		echo "\n[ERROR] Could not communicate with docker daemon. You may need to run with sudo.\n"; \
		exit 1; \
	fi

####################################
# Multi-arch stuff
####################################
.SILENT: qemu-user-static arm64 stop_qemu
.PHONY: stop_qemu
qemu-user-static: | docker
	ifeq ($(DETECTED_OS),Linux)
		echo "Starting qemu-user-static"
		docker run --rm --privileged multiarch/qemu-user-static --reset -p yes &> /dev/null
		touch $@
	else
		echo "qemu-user-static not needed!"
	endif
stop_qemu:
	if [ -e qemu-user-static ]; then \
		docker run --rm --privileged multiarch/qemu-user-static --reset &> /dev/null \
		&& rm qemu-user-static; \
	fi
	if [ -e arm64 ]; then rm arm64; fi
arm64: | docker
	if docker run --rm -it --platform linux/arm64 ubuntu:22.04 uname &> /dev/null; then \
		touch $@; \
	else \
		$(MAKE) qemu-user-static && touch $@ || exit 1; \
	fi

####################################
# Base Images
####################################
BASE_AMD64 := $(shell echo {ubuntu22.04,rockylinux9}-cuda12)
BASE_ARM64 := $(shell echo arm64-{ubuntu22.04,rockylinux9}-cuda12)

%: containers/% | docker
	$(BUILD) --build-arg FLAGS="$(AMD64)" --build-arg CUDA="$(CUDA)" --platform linux/amd64 ./containers &> $@.log
	$(PUSHC)
	touch $@

arm64-%: containers/arm64-% arm64 | docker
	$(BUILD) --build-arg FLAGS="$(ARM64)" --build-arg CUDA="$(CUDA_ARM)" --platform linux/arm64 ./containers &> $@.log
	$(PUSHC)
	touch $@

base-images: $(BASE_AMD64) $(BASE_ARM64)
	touch $@

base-images-amd64: $(BASE_AMD64)
	touch $@

base-images-arm64: $(BASE_ARM64)
	touch $@

.PHONY: clean-base clean-base-amd64 clean-base-arm64
clean-base: | clean-base-amd64 clean-base-arm64

clean-base-amd64: | docker
	for img in $(BASE_AMD64); do docker rmi $(ORG)/tacc-base:$$img; rm -f $$img $$img.log; done
	if [ -e base-images-amd64]; then rm base-images-amd64; fi

clean-base-arm64: | docker
	for img in $(BASE_ARM64); do docker rmi $(ORG)/tacc-base:$$img; rm -f $$img $$img.log; done
	if [ -e base-images-arm64]; then rm base-images-arm64; fi

####################################
# ML Images
####################################
ML := $(shell echo {ubuntu18.04,ubuntu20.04,ubuntu22.04,rockylinux8}-cuda11-tf2.11-pt1.13)

%-tf2.11-pt1.13: containers/tf-pt-jupyter-conda % | docker
	$(BUILD) --build-arg FROM_TAG="$(word 2,$^)" --build-arg ORG="$(ORG)" --build-arg FLAGS="$(FLAGS)" ./containers &> $@.log
	$(PUSHC)
	touch $@

ml-images: $(ML)
	touch $@

clean-ml: | docker
	for img in $(ML); do docker rmi -f $(ORG)/tacc-base:$$img; rm -f $$img $$img.log; done
	if [ -e ml-images ]; then rm ml-images; fi

####################################
# MPI Images
####################################
MPI := $(shell echo {ubuntu18.04,ubuntu20.04,ubuntu22.04,rockylinux8}-mvapich2.3-{ib,psm2})
IMPI := $(shell echo {ubuntu18.04,ubuntu20.04,ubuntu22.04,rockylinux8}-impi19.0.9-common)

# mvapich2.3-ib
ubuntu18.04-mvapich2.3-ib: containers/ubuntu-mvapich2.3-ib ubuntu18.04-cuda11 | docker
	$(BUILD) --build-arg FROM_TAG="$(word 2,$^)" --build-arg ORG="$(ORG)" --build-arg FLAGS="$(FLAGS)" ./containers &> $@.log
	$(PUSHC)
	touch $@

ubuntu20.04-mvapich2.3-ib: containers/ubuntu-mvapich2.3-ib ubuntu20.04-cuda11 | docker
	$(BUILD) --build-arg FROM_TAG="$(word 2,$^)" --build-arg ORG="$(ORG)" --build-arg FLAGS="$(FLAGS)" ./containers &> $@.log
	$(PUSHC)
	touch $@

ubuntu22.04-mvapich2.3-ib: containers/ubuntu-mvapich2.3-ib ubuntu22.04-cuda11 | docker
	$(BUILD) --build-arg FROM_TAG="$(word 2,$^)" --build-arg ORG="$(ORG)" --build-arg FLAGS="$(FLAGS)" ./containers &> $@.log
	$(PUSHC)
	touch $@

rockylinux8-mvapich2.3-ib: containers/rockylinux-mvapich2.3-ib rockylinux8-cuda11 | docker
	$(BUILD) --build-arg FROM_TAG="$(word 2,$^)" --build-arg ORG="$(ORG)" --build-arg FLAGS="$(FLAGS)" ./containers &> $@.log
	$(PUSHC)
	touch $@

# mvapich2.3-psm2
ubuntu18.04-mvapich2.3-psm2: containers/ubuntu-mvapich2.3-psm2 ubuntu18.04-cuda11 | docker
	$(BUILD) --build-arg FROM_TAG="$(word 2,$^)" --build-arg ORG="$(ORG)" --build-arg FLAGS="$(FLAGS)" ./containers &> $@.log
	$(PUSHC)
	touch $@

ubuntu20.04-mvapich2.3-psm2: containers/ubuntu-mvapich2.3-psm2 ubuntu20.04-cuda11 | docker
	$(BUILD) --build-arg FROM_TAG="$(word 2,$^)" --build-arg ORG="$(ORG)" --build-arg FLAGS="$(FLAGS)" ./containers &> $@.log
	$(PUSHC)
	touch $@

ubuntu22.04-mvapich2.3-psm2: containers/ubuntu-mvapich2.3-psm2 ubuntu22.04-cuda11 | docker
	$(BUILD) --build-arg FROM_TAG="$(word 2,$^)" --build-arg ORG="$(ORG)" --build-arg FLAGS="$(FLAGS)" ./containers &> $@.log
	$(PUSHC)
	touch $@

rockylinux8-mvapich2.3-psm2: containers/rockylinux-mvapich2.3-psm2 rockylinux8-cuda11 | docker
	$(BUILD) --build-arg FROM_TAG="$(word 2,$^)" --build-arg ORG="$(ORG)" --build-arg FLAGS="$(FLAGS)" ./containers &> $@.log
	$(PUSHC)
	touch $@

# impi19.0.9-common
ubuntu18.04-impi19.0.9-common: containers/ubuntu-impi19.0.9-common ubuntu18.04-cuda11 | docker
	$(BUILD) --build-arg FROM_TAG="$(word 2,$^)" --build-arg ORG="$(ORG)" --build-arg FLAGS="$(FLAGS)" --build-arg OS="ubuntu18.04" ./containers &> $@.log
	$(PUSHC)
	touch $@

ubuntu20.04-impi19.0.9-common: containers/ubuntu-impi19.0.9-common ubuntu20.04-cuda11 | docker
	$(BUILD) --build-arg FROM_TAG="$(word 2,$^)" --build-arg ORG="$(ORG)" --build-arg FLAGS="$(FLAGS)" --build-arg OS="ubuntu20.04" ./containers &> $@.log
	$(PUSHC)
	touch $@

ubuntu22.04-impi19.0.9-common: containers/ubuntu-impi19.0.9-common ubuntu22.04-cuda11 | docker
	$(BUILD) --build-arg FROM_TAG="$(word 2,$^)" --build-arg ORG="$(ORG)" --build-arg FLAGS="$(FLAGS)" --build-arg OS="ubuntu22.04" ./containers &> $@.log
	$(PUSHC)
	touch $@

rockylinux8-impi19.0.9-common: containers/rockylinux-impi19.0.9-common rockylinux8-cuda11 | docker
	$(BUILD) --build-arg FROM_TAG="$(word 2,$^)" --build-arg ORG="$(ORG)" --build-arg FLAGS="$(FLAGS)" --build-arg OS="rhel8.7" ./containers &> $@.log
	$(PUSHC)
	touch $@

mpi-images: $(MPI) $(IMPI)
	touch $@

clean-mpi: | docker
	for img in $(MPI); do docker rmi -f $(ORG)/tacc-base:$$img; rm -f $$img $$img.log; done
	for img in $(IMPI); do docker rmi -f $(ORG)/tacc-base:$$img; rm -f $$img $$img.log; done
	if [ -e mpi-images ]; then rm mpi-images; fi

####################################
# ML/MPI Images
####################################
MLMPI := $(shell echo {ubuntu18.04,ubuntu20.04,ubuntu22.04,rockylinux8}-cuda11-tf2.11-pt1.13-mvapich2.3-ib)
MLIMPI := $(shell echo {ubuntu18.04,ubuntu20.04,ubuntu22.04,rockylinux8}-cuda11-tf2.11-pt1.13-impi19.0.9-common)

# mvapich2.3-ib
ubuntu18.04-cuda11-tf2.11-pt1.13-mvapich2.3-ib: containers/ubuntu-mvapich2.3-ib ubuntu18.04-cuda11-tf2.11-pt1.13 | docker
	$(BUILD) --build-arg FROM_TAG="$(word 2,$^)" --build-arg ORG="$(ORG)" --build-arg FLAGS="$(FLAGS)" ./containers &> $@.log
	$(PUSHC)
	touch $@

ubuntu20.04-cuda11-tf2.11-pt1.13-mvapich2.3-ib: containers/ubuntu-mvapich2.3-ib ubuntu20.04-cuda11-tf2.11-pt1.13 | docker
	$(BUILD) --build-arg FROM_TAG="$(word 2,$^)" --build-arg ORG="$(ORG)" --build-arg FLAGS="$(FLAGS)" ./containers &> $@.log
	$(PUSHC)
	touch $@

ubuntu22.04-cuda11-tf2.11-pt1.13-mvapich2.3-ib: containers/ubuntu-mvapich2.3-ib ubuntu22.04-cuda11-tf2.11-pt1.13 | docker
	$(BUILD) --build-arg FROM_TAG="$(word 2,$^)" --build-arg ORG="$(ORG)" --build-arg FLAGS="$(FLAGS)" ./containers &> $@.log
	$(PUSHC)
	touch $@

rockylinux8-cuda11-tf2.11-pt1.13-mvapich2.3-ib: containers/rockylinux-mvapich2.3-ib rockylinux8-cuda11-tf2.11-pt1.13 | docker
	$(BUILD) --build-arg FROM_TAG="$(word 2,$^)" --build-arg ORG="$(ORG)" --build-arg FLAGS="$(FLAGS)" ./containers &> $@.log
	$(PUSHC)
	touch $@

# impi19.0.9-common
ubuntu18.04-cuda11-tf2.11-pt1.13-impi19.0.9-common: containers/ubuntu-impi19.0.9-common ubuntu18.04-cuda11-tf2.11-pt1.13 | docker
	$(BUILD) --build-arg FROM_TAG="$(word 2,$^)" --build-arg ORG="$(ORG)" --build-arg FLAGS="$(FLAGS)" --build-arg OS="ubuntu18.04" ./containers &> $@.log
	$(PUSHC)
	touch $@

ubuntu20.04-cuda11-tf2.11-pt1.13-impi19.0.9-common: containers/ubuntu-impi19.0.9-common ubuntu20.04-cuda11-tf2.11-pt1.13 | docker
	$(BUILD) --build-arg FROM_TAG="$(word 2,$^)" --build-arg ORG="$(ORG)" --build-arg FLAGS="$(FLAGS)" --build-arg OS="ubuntu20.04" ./containers &> $@.log
	$(PUSHC)
	touch $@

ubuntu22.04-cuda11-tf2.11-pt1.13-impi19.0.9-common: containers/ubuntu-impi19.0.9-common ubuntu22.04-cuda11-tf2.11-pt1.13 | docker
	$(BUILD) --build-arg FROM_TAG="$(word 2,$^)" --build-arg ORG="$(ORG)" --build-arg FLAGS="$(FLAGS)" --build-arg OS="ubuntu22.04" ./containers &> $@.log
	$(PUSHC)
	touch $@

rockylinux8-cuda11-tf2.11-pt1.13-impi19.0.9-common: containers/rockylinux-impi19.0.9-common rockylinux8-cuda11-tf2.11-pt1.13 | docker
	$(BUILD) --build-arg FROM_TAG="$(word 2,$^)" --build-arg ORG="$(ORG)" --build-arg FLAGS="$(FLAGS)" --build-arg OS="rhel8.7" ./containers &> $@.log
	$(PUSHC)
	touch $@
	
ml-mpi-images: $(MLMPI) $(MLIMPI)
	touch $@

clean-ml-mpi: | docker
	for img in $(MLMPI); do docker rmi -f $(ORG)/tacc-base:$$img; rm -f $$img $$img.log; done
	for img in $(MLIMPI); do docker rmi -f $(ORG)/tacc-base:$$img; rm -f $$img $$img.log; done
	if [ -e ml-mpi-images ]; then rm ml-mpi-images; fi

####################################
# All
####################################
all: ml-mpi-images mpi-images
	docker system prune

clean: clean-base clean-ml clean-mpi clean-ml-mpi
	docker system prune

