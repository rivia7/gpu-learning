#!/bin/bash
ENABLE_PRUNE="true"

function docker_prune() {
    if [ "$ENABLE_PRUNE" = "true" ]; then
      docker system prune -a -f || exit 1
    fi
}

function build_pytorch_image() {
    local ngc_version="$1"
    local python_version="$2"
    local base_image="nvcr.io/nvidia/pytorch:$ngc_version-py3"
    docker build --target devel --build-arg BASE_IMAGE="$base_image" --build-arg PYTHON_VERSION="$python_version" \
      -t rivia/pytorch:"$ngc_version" -f Dockerfile . || exit 1
    docker push rivia/pytorch:"$ngc_version" && docker_prune
}

function build_tensorflow_image() {
    local ngc_version="$1"
    local python_version="$2"
    local base_image="nvcr.io/nvidia/tensorflow:$ngc_version-tf2-py3"
    docker build --target devel --build-arg BASE_IMAGE="$base_image" --build-arg PYTHON_VERSION="$python_version" \
      -t rivia/tensorflow:"$ngc_version" -f Dockerfile . || exit 1
    docker push rivia/tensorflow:"$ngc_version" && docker_prune
}

function build_triton_server_image() {
    local ngc_version="$1"
    local base_image="nvcr.io/nvidia/tritonserver:$ngc_version-py3"
    docker build --target base --build-arg BASE_IMAGE="$base_image" \
      -t rivia/tritonserver:"$ngc_version" -f Dockerfile . || exit 1
    docker push rivia/tritonserver:"$ngc_version" && docker_prune
}

function build_tensorrt_image() {
    local ngc_version="$1"
    local python_version="$2"
    local cmake_version="$3"
    local bazelisk_version="$4"
    local base_image="nvcr.io/nvidia/tensorrt:$ngc_version-py3"
    local stage_image="tensorrt:devel"
    docker build --target devel --build-arg BASE_IMAGE="$base_image" --build-arg PYTHON_VERSION="$python_version" \
      -t $stage_image -f Dockerfile . || exit 1
    docker build --target build --build-arg BASE_IMAGE="$stage_image" \
      --build-arg CMAKE_VERSION="$cmake_version" --build-arg BAZELISK_VERSION="$bazelisk_version" \
      -t rivia/tensorrt:"$ngc_version" -f Dockerfile . || exit 1
    docker push rivia/tensorrt:"$ngc_version" && docker_prune
}

function build_trtllm_image() {
    local trtllm_version="$1"
    local python_version="$2"
    local base_image="nvcr.io/nvidia/tensorrt-llm/release:$trtllm_version"
    local stage_image="triton_backend:base"
    docker build --target base --build-arg BASE_IMAGE="$base_image" \
      -t $stage_image -f Dockerfile . || exit 1
    docker build --target devel --build-arg BASE_IMAGE="$stage_image" --build-arg PYTHON_VERSION="$python_version" \
      -t rivia/tensorrt-llm:"$trtllm_version" -f Dockerfile . || exit 1
    docker push rivia/tensorrt-llm:"$trtllm_version" && docker_prune
}

function build_triton_backend_image() {
    local ngc_version="$1"
    local python_version="$2"
    local cmake_version="$3"
    local bazelisk_version="$4"
    local backend_type="$5"
    local base_image
    if [[ "$backend_type" == "trtllm" ]]; then
      base_image="nvcr.io/nvidia/tritonserver:$ngc_version-trtllm-python-py3"
      tag="$ngc_version-trtllm"
    elif [[ "$backend_type" == "vllm" ]]; then
      base_image="nvcr.io/nvidia/tritonserver:$ngc_version-vllm-python-py3"
      tag="$ngc_version-vllm"
    else
      base_image="nvcr.io/nvidia/tritonserver:$ngc_version-py3"
      tag="$ngc_version"
    fi
    local stage_image="triton_backend:base"
    docker build --target base --build-arg BASE_IMAGE="$base_image" \
      -t $stage_image -f Dockerfile . || exit 1
    docker build --target devel --build-arg BASE_IMAGE="$stage_image" --build-arg PYTHON_VERSION="$python_version" \
      -t rivia/triton_backend:"$tag" -f Dockerfile . || exit 1
    docker push rivia/triton_backend:"$tag" && docker_prune
}

function build_ollama_image() {
    local ollama_version="$1"
    local python_version="$2"
    local jetson_version="$3"
    local arch="$4"
    if [[ "$arch" == "x86_64" ]]; then
      local base_image="ollama/ollama:$ollama_version"
      local platform="linux/amd64"
    else
      local base_image="dustynv/ollama:$ollama_version"
      local platform="linux/arm64"
    fi
    local stage_image="ollama:base"
    docker buildx build --platform $platform --target base --build-arg BASE_IMAGE="$base_image" \
      -t $stage_image -f Dockerfile --load . || exit 1
    docker buildx build --platform $platform --target conda --build-arg BASE_IMAGE="$stage_image" --build-arg PYTHON_VERSION="$python_version" \
      -t rivia/ollama:"$jetson_version" -f Dockerfile --load . || exit 1
    docker push rivia/ollama:"$jetson_version" && docker_prune
}

function build_deepstream_image() {
    local deepstream_version="$1"
    local python_version="$2"
    local pyds_version="$3"
    local arch="$4"
    if [[ "$arch" == "x86_64" ]]; then
      local base_image="nvcr.io/nvidia/deepstream:$deepstream_version"
    else
      local base_image="dustynv/deepstream:$deepstream_version"
    fi
    local stage_image="deepstream:devel"
    docker build --target devel --build-arg BASE_IMAGE="$base_image" --build-arg PYTHON_VERSION="$python_version" \
      -t $stage_image -f Dockerfile . || exit 1
    docker build --target deepstream --build-arg BASE_IMAGE="$stage_image" --build-arg ARCH="$arch" \
      --build-arg DEEPSTREAM_VERSION="$deepstream_version" --build-arg PYDS_VERSION="$pyds_version" \
      -t rivia/deepstream:"$deepstream_version" -f Dockerfile . || exit 1
    docker push rivia/deepstream:"$deepstream_version" && docker_prune
}

function build_nemo_image() {
    local ngc_version="$1"
    local python_version="$2"
    local base_image="nvcr.io/nvidia/nemo:$ngc_version"
    docker build --target devel --build-arg BASE_IMAGE="$base_image" --build-arg PYTHON_VERSION="$python_version" \
      -t rivia/nemo:"$ngc_version" -f Dockerfile . || exit 1
    docker push rivia/nemo:"$ngc_version" && docker_prune
}

function build_lmdeploy_image() {
    local lmdeploy_version="$1"
    local python_version="$2"
    local base_image="openmmlab/lmdeploy:v$lmdeploy_version"
    docker build --target devel --build-arg BASE_IMAGE="$base_image" --build-arg PYTHON_VERSION="$python_version" \
      -t "rivia/lmdeploy:v$lmdeploy_version" -f Dockerfile . || exit 1
    docker push "rivia/lmdeploy:v$lmdeploy_version" && docker_prune
}


NGC_VERSION="26.08"
PYTHON_VERSION="3.12"
CMAKE_VERSION="4.4.3"
BAZELISK_VERSION="1.29.0"
USE_JETSON="false"
DEEPSTREAM_VERSION="9.1-triton-multiarch"
JETSON_VERSION="r39.2.1"
PYDS_VERSION="1.2.2"
LMDEPLOY_VERSION="0.17.0"
TRTLLM_VERSION="1.3.0rc28"
dos2unix ./*

build_pytorch_image "$NGC_VERSION" "$PYTHON_VERSION" || exit 1
build_tensorflow_image "$NGC_VERSION" "$PYTHON_VERSION" || exit 1
build_triton_server_image "$NGC_VERSION" || exit 1
build_tensorrt_image "$NGC_VERSION" "$PYTHON_VERSION" "$CMAKE_VERSION" "$BAZELISK_VERSION" || exit 1
build_trtllm_image "$TRTLLM_VERSION" "$PYTHON_VERSION" || exit 1
build_triton_backend_image "$NGC_VERSION" "$PYTHON_VERSION" "$CMAKE_VERSION" "$BAZELISK_VERSION" "general" || exit 1
build_triton_backend_image "$NGC_VERSION" "$PYTHON_VERSION" "$CMAKE_VERSION" "$BAZELISK_VERSION" "vllm" || exit 1
build_triton_backend_image "$NGC_VERSION" "$PYTHON_VERSION" "$CMAKE_VERSION" "$BAZELISK_VERSION" "trtllm" || exit 1
if [ "$USE_JETSON" = "true" ]; then
  build_ollama_image "$JETSON_VERSION" "$PYTHON_VERSION" || exit 1
  build_deepstream_image "$JETSON_VERSION" "$PYTHON_VERSION" "$PYDS_VERSION" "jetson" || exit 1
else
  build_deepstream_image "$DEEPSTREAM_VERSION" "$PYTHON_VERSION" "$PYDS_VERSION" "x86_64" || exit 1
fi
build_nemo_image 25.09 3.12 || exit 1
build_lmdeploy_image "$LMDEPLOY_VERSION" "3.12" || exit 1
