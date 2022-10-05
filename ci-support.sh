#! /bin/bash
# ^^ (not a script: only here for shellcheck's benefit)

set -e
set -o pipefail

ci_support="https://gitlab.tiker.net/inducer/ci-support/raw/main"

if [ "$(uname)" = "Darwin" ]; then
  PLATFORM=MacOSX
elif [ "$(uname)" = "Linux" ]; then
  PLATFORM=Linux
else
  PLATFORM=Windows
fi

if [ "$PY_EXE" == "" ]; then
  if [ "$py_version" == "" ]; then
    if [ "$PLATFORM" = "Windows" ]; then
      PY_EXE=python
    else
      PY_EXE=python3
    fi
  else
    PY_EXE=python${py_version}
  fi
fi

if test "$CI_SERVER_NAME" = "GitLab" && test -d ~/.local/lib; then
  echo "ERROR: $HOME/.local/lib exists. It really shouldn't. Here's what it contains:"
  find ~/.local/lib
  exit 1
fi


# {{{ utilities

function with_echo()
{
  echo "+++" "$@"
  "$@"
}

function get_proj_name()
{
  if [ -n "$CI_PROJECT_NAME" ]; then
    echo "$CI_PROJECT_NAME"
  else
    basename "$GITHUB_REPOSITORY"
  fi
}

print_status_message()
{
  echo "-----------------------------------------------"
  echo "Current directory: $(pwd)"
  echo "Python executable: ${PY_EXE}"
  echo "PYOPENCL_TEST: ${PYOPENCL_TEST}"
  echo "PYTEST_ADDOPTS: ${PYTEST_ADDOPTS}"
  echo "PROJECT_INSTALL_FLAGS: ${PROJECT_INSTALL_FLAGS}"
  echo "git revision: $(git rev-parse --short HEAD)"
  echo "git status:"
  git status -s
  test -f /proc/cpuinfo && ( grep 'model name' /proc/cpuinfo | head -n 1)
  echo "-----------------------------------------------"
}


create_and_set_up_virtualenv()
{
  ${PY_EXE} -m venv .env
  . .env/bin/activate

  # https://github.com/pypa/pip/issues/5345#issuecomment-386443351
  export XDG_CACHE_HOME=$HOME/.cache/$CI_RUNNER_ID

  RESOLVED_PY_EXE=$(which ${PY_EXE})
  case "$RESOLVED_PY_EXE" in
    $PWD/.env/*) ;;
    *)
      echo "Python executable $PY_EXE not in virtualenv"
      exit 1
      ;;
  esac


  $PY_EXE -m pip install --upgrade pip
  $PY_EXE -m pip install setuptools wheel
}


install_miniforge()
{
  MINIFORGE_VERSION=3
  MINIFORGE_INSTALL_DIR=.miniforge${MINIFORGE_VERSION}

  if [ "$PLATFORM" == "Windows" ]; then
    MINIFORGE_EXT="exe"
  else
    MINIFORGE_EXT="sh"
  fi
  MINIFORGE_INSTALLER=Miniforge3-$PLATFORM-x86_64.$MINIFORGE_EXT
  curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/$MINIFORGE_INSTALLER"

  rm -Rf "$MINIFORGE_INSTALL_DIR"

  if [ "$PLATFORM" == "Windows" ]; then
    echo "start /wait \"\" ${MINIFORGE_INSTALLER} /InstallationType=JustMe /RegisterPython=0 /S /D=$(cygpath -w "${PWD}/${MINIFORGE_INSTALL_DIR}")" > install.bat
    cmd.exe /c install.bat
  else
    bash "$MINIFORGE_INSTALLER" -b -p "$MINIFORGE_INSTALL_DIR"
  fi
}


handle_extra_install()
{
  if test "$EXTRA_INSTALL" != ""; then
    for i in $EXTRA_INSTALL ; do
      with_echo "$PY_EXE" -m pip install "$i"
    done
  fi
}


pip_install_project()
{
  handle_extra_install

  if test "$REQUIREMENTS_TXT" == ""; then
    REQUIREMENTS_TXT="requirements.txt"
  fi

  if test -f "$REQUIREMENTS_TXT"; then
    # Filter out any numpy requirements, install first. Otherwise some packages
    # might build against wrong version of numpy.
    # Context: https://github.com/numpy/numpy/issues/20709
    if grep -q "^numpy" "$REQUIREMENTS_TXT"; then
      echo "Installing numpy first to avoid numpy#20709."
      grep -e "^numpy" "$REQUIREMENTS_TXT" > ci-support-numpy-req.txt
      with_echo pip install -r ci-support-numpy-req.txt
    fi

    with_echo pip install -r "$REQUIREMENTS_TXT"
  fi

  if test -f .conda-ci-build-configure.sh; then
    with_echo source .conda-ci-build-configure.sh
  fi

  if test -f .ci-build-configure.sh; then
    with_echo source .ci-build-configure.sh
  fi

  # Append --editable to PROJECT_INSTALL_FLAGS, if not there already.
  # See: https://gitlab.tiker.net/inducer/ci-support/-/issues/3
  # Can be removed after https://github.com/pypa/pip/issues/2195 is resolved.
  if [[ ! $PROJECT_INSTALL_FLAGS =~ (^|[[:space:]]*)(--editable|-e)[[:space:]]*$ ]]; then
      PROJECT_INSTALL_FLAGS="$PROJECT_INSTALL_FLAGS --editable"
  fi

  with_echo "$PY_EXE" -m pip install $PROJECT_INSTALL_FLAGS .
}


# }}}


# {{{ cleanup

clean_up_repo_and_working_env()
{
  rm -Rf .env
  rm -Rf build
  find . -name '*.pyc' -delete

  rm -Rf env
  git clean -fdx \
    -e siteconf.py \
    -e boost-numeric-bindings \
    -e '.pylintrc.yml' \
    -e 'prepare-and-run-*.sh' \
    -e 'ci-support.sh' \
    -e 'run-*.py' \
    -e '.test-*.yml' \
    $GIT_CLEAN_EXCLUDE


  if test `find "siteconf.py" -mmin +1`; then
    echo "siteconf.py older than a minute, assumed stale, deleted"
    rm -f siteconf.py
  fi

  if [[ "$NO_SUBMODULES" = "" ]]; then
    git submodule update --init --recursive
  fi
}

# }}}


# {{{ virtualenv build

build_py_project_in_venv()
{
  print_status_message
  clean_up_repo_and_working_env
  create_and_set_up_virtualenv

  pip_install_project
}

# }}}


# {{{ miniconda build

install_conda_deps()
{
  print_status_message
  clean_up_repo_and_working_env
  install_miniforge

  if test "$CONDA_ENVIRONMENT" = ""; then
    if test -f ".test-conda-env-py3.yml"; then
      CONDA_ENVIRONMENT=.test-conda-env-py3.yml
    elif test -f ".test-conda-env.yml"; then
      CONDA_ENVIRONMENT=.test-conda-env.yml
    fi
  fi

  local CONDA_EXE_DIR
  if [ $PLATFORM = "Windows" ]; then
    CONDA_EXE_DIR=$MINIFORGE_INSTALL_DIR/Scripts
  else
    CONDA_EXE_DIR=$MINIFORGE_INSTALL_DIR/bin
  fi

  PATH="$CONDA_EXE_DIR:$PATH" with_echo conda update conda --yes --quiet
  PATH="$CONDA_EXE_DIR:$PATH" with_echo conda update --all --yes --quiet
  PATH="$CONDA_EXE_DIR:$PATH" with_echo conda env create --file "$CONDA_ENVIRONMENT" --name testing --quiet

  source "$CONDA_EXE_DIR/activate" testing

  # https://github.com/conda-forge/ocl-icd-feedstock/issues/11#issuecomment-456270634
  rm -f $MINIFORGE_INSTALL_DIR/envs/testing/etc/OpenCL/vendors/system-*.icd
  # https://gitlab.tiker.net/inducer/pytential/issues/112
  rm -f $MINIFORGE_INSTALL_DIR/envs/testing/etc/OpenCL/vendors/apple.icd

  # https://github.com/pypa/pip/issues/5345#issuecomment-386443351
  export XDG_CACHE_HOME=$HOME/.cache/$CI_RUNNER_ID

  with_echo conda install --quiet --yes pip
  with_echo conda list

  # Placeholder until github.com/conda-forge/qt-feedstock/issues/208 is fixed
  if [ "$(uname)" = "Linux" ]; then
    with_echo rm -rf $MINIFORGE_INSTALL_DIR/envs/testing/x86_64-conda-linux-gnu/sysroot
  fi

  local LIBRARY_PREFIX
  # If a job decides it wants to build PyOpenCL from source, e.g. this situation:
  # https://github.com/conda-forge/pyopencl-feedstock/pull/64#issuecomment-842831669
  # give it a fighting chance if running with Conda:
  if test "$CONDA_PREFIX" != ""; then
    if [ "$PLATFORM" = "Windows" ]; then
      LIBRARY_PREFIX="$CONDA_PREFIX/Library"
    else
      LIBRARY_PREFIX="$CONDA_PREFIX"
    fi
    cat >> ~/.aksetup-defaults.py <<EOF
CL_INC_DIR = ["$LIBRARY_PREFIX/include"]
CL_LIB_DIR = ["$LIBRARY_PREFIX/lib"]

# This matches the default on Linux and forces the use of the conda-installed
# ICD loader on macOS.
CL_LIBNAME = ["OpenCL"]
EOF
  fi
}

build_py_project_in_conda_env()
{
  install_conda_deps
  pip_install_project
}

# }}}


# {{{ generic build

build_py_project()
{
  if test "$USE_CONDA_BUILD" == "1"; then
    build_py_project_in_conda_env
  else
    build_py_project_in_venv
  fi
}

# }}}


# {{{ test

test_py_project()
{
  $PY_EXE -m pip install pytest pytest-github-actions-annotate-failures

  # Needed for https://github.com/utgwkk/pytest-github-actions-annotate-failures
  export PYTEST_RUN_PATH=test

  # pytest-xdist fails on pypy with: ImportError: cannot import name '_psutil_linux'
  # AK, 2020-08-20
  if [[ "${PY_EXE}" == pypy* ]]; then
    CISUPPORT_PARALLEL_PYTEST=no
  else
    $PY_EXE -m pip install pytest-xdist
  fi

  AK_PROJ_NAME="$(get_proj_name)"

  TESTABLES=""
  if [ -d test ]; then
    cd test

    if ! [ -f .not-actually-ci-tests ]; then
      TESTABLES="$TESTABLES ."
    fi

    if [ -z "$NO_DOCTESTS" ]; then
      RST_FILES=(../doc/*.rst)

      for f in "${RST_FILES[@]}"; do
        if [ -e "$f" ]; then
          if ! grep -q no-doctest "$f"; then
            TESTABLES="$TESTABLES $f"
          fi
        fi
      done

      # macOS bash is too old for mapfile: Oh well, no doctests on mac.
      if [ "$(uname)" != "Darwin" ]; then
        mapfile -t DOCTEST_MODULES < <( git grep -l doctest -- ":(glob,top)$AK_PROJ_NAME/**/*.py" )
        TESTABLES="$TESTABLES ${DOCTEST_MODULES[*]}"
      fi
    fi

    if [[ -n "$TESTABLES" ]]; then
      # Core dumps? Sure, take them.
      ulimit -c unlimited

      if test "$PLATFORM" != "Windows"; then
        # 10 GiB should be enough for just about anyone :)
        ulimit -m "$(python -c 'print(1024*1024*10)')"
      fi

      if [[ $CISUPPORT_PARALLEL_PYTEST == "" || $CISUPPORT_PARALLEL_PYTEST == "xdist" ]]; then
        # Default: parallel if Not (Gitlab and GPU CI)?
        PYTEST_PARALLEL_FLAGS=""

        # CI_RUNNER_DESCRIPTION is set by Gitlab
        if [[ $CI_RUNNER_DESCRIPTION != *-gpu ]]; then
          if [[ $CISUPPORT_PYTEST_NRUNNERS == "" ]]; then
            PYTEST_PARALLEL_FLAGS="-n 4"
          else
            PYTEST_PARALLEL_FLAGS="-n $CISUPPORT_PYTEST_NRUNNERS"
          fi
        fi

      elif [[ $CISUPPORT_PARALLEL_PYTEST == "no" ]]; then
          PYTEST_PARALLEL_FLAGS=""
      else
        echo "unrecognized scheme in CISUPPORT_PARALLEL_PYTEST"
      fi

      # It... somehow... (?) seems to cause crashes for pytential.
      # https://gitlab.tiker.net/inducer/pytential/-/issues/146
      if [[ $CISUPPORT_PYTEST_NO_DOCTEST_MODULES == "" ]]; then
        DOCTEST_MODULES_FLAG="--doctest-modules"
      else
        DOCTEST_MODULES_FLAG=""
      fi

      CONDA_JEMALLOC="$CONDA_PREFIX/lib/libjemalloc.so.2"
      if test "$CONDA_PREFIX" != "" && test -f "$CONDA_JEMALLOC"; then
        echo "*** running with $CONDA_JEMALLOC in LD_PRELOAD"
        export CI_SUPPORT_LD_PRELOAD="$CONDA_JEMALLOC"
      else
        export CI_SUPPORT_LD_PRELOAD="$LD_PRELOAD"
      fi

      ( LD_PRELOAD="$CI_SUPPORT_LD_PRELOAD" with_echo "${PY_EXE}" -m pytest \
          --durations=10 \
          --tb=native  \
          --junitxml=pytest.xml \
          $DOCTEST_MODULES_FLAG \
          -rxsw \
          $PYTEST_FLAGS $PYTEST_PARALLEL_FLAGS $TESTABLES )
    fi
  fi
}

# }}}


# {{{ run examples

run_examples()
{
  if test "$1" == "--no-require-main"; then
    MAIN_FILTER=()
  else
    MAIN_FILTER=(-exec grep -q __main__ '{}' \;)
  fi

  if ! test -d examples; then
    echo "!!! No 'examples' directory found"
    exit 1
  else
    cd examples

    for i in $(find . -name '*.py' "${MAIN_FILTER[@]}" -print ); do
      echo "-----------------------------------------------------------------------"
      echo "RUNNING $i"
      echo "-----------------------------------------------------------------------"
      dn=$(dirname "$i")
      bn=$(basename "$i")

      CONDA_JEMALLOC="$CONDA_PREFIX/lib/libjemalloc.so.2"
      if test "$CONDA_PREFIX" != "" && test -f "$CONDA_JEMALLOC"; then
        echo "*** running with $CONDA_JEMALLOC in LD_PRELOAD"
        export CI_SUPPORT_LD_PRELOAD="$CONDA_JEMALLOC"
      else
        export CI_SUPPORT_LD_PRELOAD="$LD_PRELOAD"
      fi

      (cd "$dn"; time LD_PRELOAD="$CI_SUPPORT_LD_PRELOAD" ${PY_EXE} "$bn")
    done
  fi
}

# }}}


# {{{ docs

build_docs()
{
  if test "$CI_SUPPORT_SPHINX_VERSION_SPECIFIER" = ""; then
    # >=3.2.1 for https://github.com/sphinx-doc/sphinx/issues/8084
    # >=4.0.2 because sphinx 4 is nice :D
    CI_SUPPORT_SPHINX_VERSION_SPECIFIER=">=4.0.2"
  fi

  # Two separate installs to trick sphinx into not precisely enforcing dependencies.
  # At the time of this writing, furo says it only works with sphinx 3.x.
  # (but it seems 4.x is OK!) -AK, 2021-05-20
  with_echo $PY_EXE -m pip install furo sphinx-copybutton

  with_echo $PY_EXE -m pip install "sphinx$CI_SUPPORT_SPHINX_VERSION_SPECIFIER" \

  if test "$1" = "--no-check"; then
    (cd doc; with_echo make html)
  else
    (cd doc; with_echo make html SPHINXOPTS="-W --keep-going -n")
  fi
}

maybe_upload_docs()
{
  if [[ "$(basename "$(pwd)")" != "doc" ]]; then
    cd doc
    maybe_upload_docs
    cd ..
    return
  fi

  if test -n "${DOC_UPLOAD_KEY}" && test "$CI_DEFAULT_BRANCH" && test "$CI_COMMIT_REF_NAME" = "$CI_DEFAULT_BRANCH"; then
    cat > doc_upload_ssh_config <<END
Host doc-upload
   User doc
   IdentityFile doc_upload_key
   IdentitiesOnly yes
   Hostname marten.tiker.net
   StrictHostKeyChecking false
END

    echo "${DOC_UPLOAD_KEY}" > doc_upload_key
    chmod 0600 doc_upload_key
    RSYNC_RSH="ssh -F doc_upload_ssh_config" ./upload-docs.sh || { rm doc_upload_key; exit 1; }
    rm doc_upload_key
  else
    echo "Not uploading docs. No DOC_UPLOAD_KEY or not on $CI_DEFAULT_BRANCH on Gitlab."
  fi
}

# }}}


# {{{ flake8

install_and_run_flake8()
{
  FLAKE8_PACKAGES=(flake8 pep8-naming)
  if grep -q quotes setup.cfg; then
    true
    FLAKE8_PACKAGES+=(flake8-quotes)
  else
    echo "-----------------------------------------------------------------"
    echo "Consider enabling quote checking for this package by configuring"
    echo "https://github.com/zheller/flake8-quotes"
    echo "in setup.cfg. Follow this example:"
    echo "https://github.com/illinois-ceesd/mirgecom/blob/45457596cac2eeb4a0e38bf6845fe4b7c323f6f5/setup.cfg#L5-L7"
    echo "-----------------------------------------------------------------"
  fi

  if grep -q enable-flake8-bugbear setup.cfg; then
    FLAKE8_PACKAGES+=(flake8-bugbear)
  else
    echo "-----------------------------------------------------------------"
    echo "Consider enabling quote checking for this package by configuring"
    echo "https://github.com/PyCQA/flake8-bugbear"
    echo "in setup.cfg. Simply add a line"
    echo "# enable-flake8-bugbear"
    echo "-----------------------------------------------------------------"
  fi

  ${PY_EXE} -m pip install "${FLAKE8_PACKAGES[@]}"
  ${PY_EXE} -m flake8 "$@"
}

# }}}


# {{{ pylint

run_pylint()
{
  curl -L -O "${ci_support}/run-pylint.py"

  if ! test -f .pylintrc.yml; then
    curl -o .pylintrc.yml "${ci_support}/.pylintrc-default.yml"
  fi

  # version bound put in place out of an abundance of cautiousness, no particular reason
  # 2021-05-03 AK
  # pytest is being installed since test_*.py modules may import pytest, which
  # pylint may inspect.

  # astroid 2.5.7 seems to produce spurious pylint failures
  $PY_EXE -m pip install "pylint<2.15" "astroid!=2.5.7" PyYAML pytest

  PYLINT_RUNNER_ARGS="--jobs=4 --yaml-rcfile=.pylintrc.yml"

  if test -f .pylintrc-local.yml; then
    PYLINT_RUNNER_ARGS="$PYLINT_RUNNER_ARGS --yaml-rcfile=.pylintrc-local.yml"
  fi

  $PY_EXE run-pylint.py $PYLINT_RUNNER_ARGS "$@"
}

# }}}


# {{{ benchmarks

function setup_asv
{
  pip install asv

  if [[ ! -f ~/.asv-machine.json ]]; then
    asv machine --yes
  fi
}

function clone_asv_results_repo
{
  local PROJECT
  PROJECT="$(get_proj_name)"

  if [[ -n "$CI" ]]; then
    mkdir -p .asv
    if [[ "$CI_PROJECT_NAMESPACE" == "inducer" && -n "${BENCHMARK_DATA_DEPLOY_KEY}" ]]; then
      echo "$BENCHMARK_DATA_DEPLOY_KEY" > .deploy_key
      chmod 700 .deploy_key
      ssh-keyscan gitlab.tiker.net >> ~/.ssh/known_hosts
      chmod 644 ~/.ssh/known_hosts
      ssh-agent bash -c "ssh-add $PWD/.deploy_key; git clone git@gitlab.tiker.net:isuruf/benchmark-data"
    else
      git clone https://gitlab.tiker.net/isuruf/benchmark-data
    fi
    ln -s "$PWD/benchmark-data/$PROJECT" ".asv/results"

    if [[ "$(git branch --show-current)" != "main" ]]; then
      # Fetch the origin/main branch and setup main to track origin/main
      git fetch origin main || true
      git branch main origin/main -f
    fi
    if [[ ! -f $PWD/.asv/results/benchmarks.json ]]; then
      # this is a brand new project. Run benchmark discovery process
      asv run --bench just-discover
    fi
  fi
}

function upload_benchmark_results
{
  if [[ "$CI_PROJECT_NAMESPACE" == "inducer" ]]; then
    cd benchmark-data
    git add "$PROJECT"
    export GIT_AUTHOR_NAME="Automated Benchmark Bot"
    export GIT_AUTHOR_EMAIL="bot@gitlab.tiker.net"
    export GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME
    export GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL
    git commit -m "Update benchmark data for $main_commit" --allow-empty
    ssh-agent bash -c "ssh-add $PWD/../.deploy_key; git pull -r origin main"
    ssh-agent bash -c "ssh-add $PWD/../.deploy_key; git push"
    cd ..
  fi
}

function run_asv
{
  if [[ -z "$PYOPENCL_TEST" ]]; then
      echo "PYOPENCL_TEST env var not set"
      exit 1
  fi

  main_commit="$(git rev-parse main)"
  test_commit="$(git rev-parse HEAD)"

  # cf. https://github.com/pandas-dev/pandas/pull/25237
  # for reasoning on --launch-method=spawn
  asv run "$main_commit...$main_commit~" --skip-existing --verbose --show-stderr --launch-method=spawn
  asv run "$test_commit...$test_commit~" --skip-existing --verbose --show-stderr --launch-method=spawn

  output="$(asv compare "$main_commit" "$test_commit" --factor "${ASV_FACTOR:-1}" -s)"
  echo "$output"

  if [[ "$output" = *"worse"* ]]; then
    echo "Some of the benchmarks have gotten worse"
    exit 1
  fi
}

function build_asv_html
{
  setup_asv
  clone_asv_results_repo
  asv publish --html-dir doc/_build/html/benchmarks
}

function build_and_run_benchmarks
{
  setup_asv
  clone_asv_results_repo
  run_asv
  upload_benchmark_results
}

# }}}


# {{{ transfer_requirements_git_urls

function transfer_requirements_git_urls()
{
  curl -L -O "${ci_support}/transfer-requirements-git-urls"
  python3 ./transfer-requirements-git-urls "$@"
}

# }}}


# {{{ edit_requirements_txt_for_downstream_in_subdir

function edit_requirements_txt_for_downstream_in_subdir()
{
  # Assumed to be run in directory of downstream project checked out in
  # subdirectory of upstream.

  # Unshallow the upstream repo. Without that, a bunch of the commands that
  # pip (as of 21.3) uses cause copious error spew, along the lines of
  # "warning: rejected (SHA) because shallow roots are not allowed to be updated"
  # "warning: filtering not recognized by server, ignoring"
  (cd ..; if $(git rev-parse --is-shallow-repository); then git fetch --unshallow; fi)

  local PRJ_NAME
  local REQ_TXT_TO_EDIT
  local TMP_FOR_COMPARISON="zzztmp-ci-support-req.txt"

  PRJ_NAME="$(get_proj_name)"
  REQ_TXT_TO_EDIT="${1:-requirements.txt}"
  cp "$REQ_TXT_TO_EDIT" "$TMP_FOR_COMPARISON"
  sed -i "/egg=$PRJ_NAME/ c git+file://$(readlink -f ..)#egg=$PRJ_NAME" "$REQ_TXT_TO_EDIT"
  if cmp "$REQ_TXT_TO_EDIT" "$TMP_FOR_COMPARISON" > /dev/null ; then
    echo "sed did not change $REQ_TXT_TO_EDIT for downstream CI"
    exit 1
  fi
}

# }}}


# {{{ install_ispc

function install_ispc()
{
    if (curl -L "https://ci.appveyor.com/api/projects/ispc/ispc/artifacts/build%2Fispc-trunk-linux.tar.gz?job=Environment%3A%20APPVEYOR_BUILD_WORKER_IMAGE%3DUbuntu1804%2C%20LLVM_VERSION%3Dlatest" \
        | tar xfz - ) ; then
      # Appveyor downloads can fail if the daily download limit is exceeded.
      PATH="$(pwd)/ispc-trunk-linux/bin:$PATH"
    else
      curl -L https://github.com/ispc/ispc/releases/download/v1.17.0/ispc-v1.17.0-linux.tar.gz  | tar xfz -
      PATH="$(pwd)/ispc-v1.17.0-linux/bin:$PATH"
    fi

    export PATH
}

# }}}


# {{{ prepare_downstream_build

function prepare_downstream_build()
{
  # NOTE: parses https://github.com/user/repo.git@branch_name
  local proj_url="${1%%@*}"
  local proj_branch=${1#"${proj_url}@"}
  local proj_name=$(basename "$proj_url" .git)

  # This is here because PyOpenCL needs to record a config change so
  # CL headers are found. It git adds siteconf.py.
  if ! git diff --quiet HEAD; then
    git config --global user.email "inform@tiker.net"
    git config --global user.name "CI runner"
    git commit -a -m "Fake commit to record local changes"
  fi

  if [[ "$proj_branch" != "$proj_url" ]]; then
    git clone "$proj_url" --branch "$proj_branch"
  else
    git clone "$proj_url"
  fi

  cd "$proj_name"
  echo "*** $proj_name version: $(git rev-parse --short HEAD)"

  if test -f ../requirements.txt; then
    transfer_requirements_git_urls ../requirements.txt ./requirements.txt
  fi

  edit_requirements_txt_for_downstream_in_subdir

  # Avoid slow or complicated tests in downstream projects
  export PYTEST_ADDOPTS="-k 'not (slowtest or octave or mpi)'"

  if [[ "$proj_name" = "mirgecom" ]]; then
      # can't turn off MPI in mirgecom
      export CONDA_ENVIRONMENT=conda-env.yml

      if [[ "$GITHUB_ACTIONS" != "" ]]; then
        # Github runners don't have a lot of RAM and tend to run out.
        export CISUPPORT_PARALLEL_PYTEST=no
      fi

      echo "- mpi4py" >> "$CONDA_ENVIRONMENT"
  else
      sed -i "/mpi4py/ d" requirements.txt
  fi
}

# }}}


# {{{ test_downstream

function test_downstream()
{
  local downstream_url="$1"
  local proj_url=""
  local test_examples=0

  if [[ "$downstream_url" =~ .*_examples ]]; then
    downstream_url="${downstream_url%_examples}"
    test_examples=1
  fi

  if [[ "$downstream_url" =~ https://.* ]]; then
    proj_url="$downstream_url"
  else
    if [[ "$downstream_url" == "mirgecom" ]]; then
      proj_url="https://github.com/illinois-ceesd/$downstream_url.git"
    else
      proj_url="https://github.com/inducer/$downstream_url.git"
    fi
  fi

  prepare_downstream_build "$proj_url"
  install_conda_deps

  # Downstream CI for pytools must override pytools that's installed via conda
  # (because it comes in as a dependency of, e.g., pyopencl). Try harder to
  # get rid of it.
  pip uninstall -y "$(get_proj_name)"

  pip_install_project

  if [[ "$test_examples" == "0" ]]; then
    test_py_project
  else
    if [[ "$proj_url" =~ .*mirgecom.* ]]; then
      examples/run_examples.sh ./examples
    else
      run_examples
    fi
  fi
}

# }}}


# vim: foldmethod=marker:sw=2
