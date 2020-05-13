#!/bin/bash
# Copyright 2019 The TensorFlow Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

set -e

function build_wheel() {
  TMPDIR="$1"
  DESTDIR="$2"
  RELEASE_FLAG="$3"

  # Before we leave the top-level directory, make sure we know how to
  # call python.
  if [[ -e python_bin_path.sh ]]; then
    echo $(date)  "Setting PYTHON_BIN_PATH equal to what was set with configure.py."
    source python_bin_path.sh
  fi
  PYTHON_BIN_PATH=${PYTHON_BIN_PATH:-$(which python3)}

  pushd ${TMPDIR} > /dev/null

  echo $(date) : "=== Building wheel"
  "${PYTHON_BIN_PATH}" setup.py bdist_wheel ${PKG_NAME_FLAG} --plat manylinux2010_x86_64 > /dev/null
  DEST=${TMPDIR}/dist/
  if [[ ! "$TMPDIR" -ef "$DESTDIR" ]]; then
    mkdir -p ${DESTDIR}
    cp dist/* ${DESTDIR}
    DEST=${DESTDIR}
  fi
  popd > /dev/null
  echo $(date) : "=== Output wheel file is in: ${DEST}"
}

function prepare_src() {
  TMPDIR="${1%/}"
  mkdir -p "$TMPDIR"

  echo $(date) : "=== Preparing sources in dir: ${TMPDIR}"

  if [ ! -d bazel-bin/reverb ]; then
    echo "Could not find bazel-bin.  Did you run from the root of the build tree?"
    exit 1
  fi

  RUNFILES=bazel-bin/reverb/pip_package/build_pip_package.runfiles/reverb

  cp ${RUNFILES}/LICENSE ${TMPDIR}
  cp -L -R ${RUNFILES}/reverb ${TMPDIR}/reverb

  mv ${TMPDIR}/reverb/pip_package/setup.py ${TMPDIR}
  mv ${TMPDIR}/reverb/pip_package/MANIFEST.in ${TMPDIR}
  mv ${TMPDIR}/reverb/pip_package/reverb_version.py ${TMPDIR}

  # TODO(b/155300149): Don't move .so files to the top-level directory.
  # This copies all .so files except for those found in the ops directory, which
  # must remain where they are for TF to find them.
  find "${TMPDIR}/reverb/cc" -type d -name ops -prune -o -name '*.so' \
    -exec mv {} "${TMPDIR}/reverb" \;
}

function usage() {
  echo "Usage:"
  echo "$0 [options]"
  echo "  Options:"
  echo "    --release         build a release version"
  echo "    --dst             path to copy the .whl into."
  echo ""
  exit 1
}

function main() {
  RELEASE_FLAG=""
  # This is where the source code is copied and where the whl will be built.
  DST_DIR=""
  # TODO(b/155864463): Set NIGHTLY_BUILD=0 and change flags below.
  while true; do
    if [[ "$1" == "--help" ]]; then
      usage
      exit 1
    elif [[ "$1" == "--release" ]]; then
      RELEASE_FLAG="--release"
    elif [[ "$1" == "--dst" ]]; then
      shift
      DST_DIR=$1
    fi

    if [[ -z "$1" ]]; then
      break
    fi
    shift
  done

  TMPDIR="$(mktemp -d -t tmp.XXXXXXXXXX)"
  if [[ -z "$DST_DIR" ]]; then
    DST_DIR=${TMPDIR}
  fi

  prepare_src "$TMPDIR"

  if [[ ${NIGHTLY_BUILD} == "1" ]]; then
    RELEASE_FLAG="--release"
  fi

  build_wheel "$TMPDIR" "$DST_DIR" "$RELEASE_FLAG"
}

main "$@"
