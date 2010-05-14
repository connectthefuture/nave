#!/bin/bash

# This program contains parts of narwhal's "sea" program,
# as well as bits borrowed from Tim Caswell's "nvm"

# nave install <version>
# Fetch the version of node and install it in nave's folder.

# nave use <version>
# Install the <version> if it isn't already, and then start
# a subshell with that version's folder at the start of the
# $PATH

# nave --version <version> program.js
# Like "nave use", but have the subshell start the program.js
# immediately.

# When told to use a version:
# Ensure that the version exists, install it, and
# then add its prefix to the PATH, and start a subshell.

main () {
  # get the absolute path of the executable
  SELF_PATH=$( cd -P -- "$(dirname -- "$0")" \
            && pwd -P \
            ) && SELF_PATH=$SELF_PATH/$(basename -- "$0")

  # resolve symlinks
  while [ -h "$SELF_PATH" ]; do
    DIR=$(dirname -- "$SELF_PATH")
    SYM=$(readlink -- "$SELF_PATH")
    SELF_PATH=$( cd -- "$DIR" \
              && cd -- $(dirname -- "$SYM") \
              && pwd \
              )/$(basename -- "$SYM")
  done

  export NAVE_SRC="$(dirname -- "$SELF_PATH")/src"
  export NAVE_ROOT="$(dirname -- "$SELF_PATH")/installed"
  ensure_dir "$NAVE_SRC"
  ensure_dir "$NAVE_ROOT"
  
  local cmd="$1"
  shift
  case $cmd in
    install | fetch | use | install | clean | test | ls )
      cmd="nave_$cmd"
      ;;
    * )
      cmd="nave_help"
      ;;
  esac
  $cmd "$@"
  exit 0
}

function enquote_all () {
  ARGS=""
  for ARG in "$@"; do
    [ -n "$ARGS" ] && ARGS="$ARGS "
    ARGS="$ARGS'""$( echo " $ARG" \
                   | cut -c 2- \
                   | sed 's/'"'"'/'"'"'"'"'"'"'"'"'/g' \
                   )""'"
  done
  echo "$ARGS"
}

ensure_dir () {
  if ! [ -d "$1" ]; then
    mkdir -p -- "$1" || fail "couldn't create $1"
  fi
}
remove_dir () {
  if [ -d "$1" ]; then
    rm -rf -- "$1" || fail "Could not remove $1"
  fi
}

fail () {
  echo "$@" >&2
  exit 1
}

nave_fetch () {
  version="$1"
  version="${version/v/}"
  if nave_has "$version" && ! [ "$version" == "HEAD" ]; then
    echo "already fetched $version" >&2
    return 0
  fi

  src="$NAVE_SRC/$version"
  remove_dir "$src"
  ensure_dir "$src"
  if [ "$version" == "HEAD" ]; then
    url="http://github.com/ry/node/tarball/master"
  else
    url="http://nodejs.org/dist/node-v$version.tar.gz"
  fi
  curl "$url" \
    | tar xzv -C "$src" --strip 1 \
    || ( remove_dir "$src"; fail "Couldn't fetch $version" )
  return 0
}

nave_install () {
  version="$1"
  version="${version/v/}"

  if nave_installed "$version" && ! [ "$version" == "HEAD" ]; then
    echo "Already installed: $version" >&2
    return 0
  fi
  nave_fetch "$version"

  src="$NAVE_SRC/$version"
  install="$NAVE_ROOT/$version"
  remove_dir "$install"
  ensure_dir "$install"
  ( cd -- "$src"
    ./configure --prefix="$install" || fail "Failed to configure $version"
    make || fail "Failed to make $version"
    make install || fail "Failed to install $version"
  ) || fail "fail"
}
nave_test () {
  version="$1"
  version="${version/v/}"
  nave_fetch "$version"
  src="$NAVE_SRC/$version"
  ( cd -- "$src"
    ./configure --debug || fail "failed to ./configure --debug"
    make test-all || fail "Failed tests"
  ) || fail "failed"
}

nave_ls () {
  ( cd -- "$(dirname -- "$SELF_PATH")"
    ls -- {"$(basename "$NAVE_SRC")","$(basename "$NAVE_ROOT")"}
  )
}

nave_has () {
  version="$1"
  version="${version/v/}"
  [ -d "$NAVE_SRC/$version" ] || return 1
}
nave_installed () {
  version="$1"
  version="${version/v/}"
  [ -d "$NAVE_ROOT/$version/bin" ] || return 1
}  

nave_use () {
  version="$1"
  version="${version/v/}"
  nave_install "$version"
  bin="$NAVE_ROOT/$version/bin"
  if [ "$version" == "$NAVE" ]; then
    echo "already using $NAVE"
    if [ $# -gt 1 ]; then
      shift
      node "$@"
    fi
    return
  fi
  lvl=$[ ${NAVELVL-0} + 1 ]
  echo "using $version"
  if [ $# -gt 1 ]; then
    shift
    PATH="$bin:$PATH" NAVELVL=$lvl NAVE="$version" "$SHELL" -c "$(enquote_all node "$@")"
  else
    PATH="$bin:$PATH" NAVELVL=$lvl NAVE="$version" "$SHELL"
  fi
}

nave_clean () {
  version="$1"
  version="${version/v/}"
  remove_dir "$NAVE_SRC/$version"
}
nave_uninstall () {
  version="$1"
  version="${version/v/}"
  remove_dir "$NAVE_ROOT/$version"
}

nave_help () {
  echo "HELP! $@"
}

main "$@"
