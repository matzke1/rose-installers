########################################################################################################################
# This file provides the base implementations of all the functions. Subclasses will override these definitions as
# necessary to implement specialized behavior. Note that you can say "[[ override ]]" to remind users that a function
# is overriding another (which is just a shell command that returns zero and has no meaning other than by convention).
########################################################################################################################

# Check that the hardware is capable of building all the software. These vary slightly according to the operating
# system, so this function takes a couple optional arguments to specify the minimum disk size and minimum RAM size in
# kB.  Note that the default minimums are larger than ROSE itself because the ROSE documentation doesn't consider the
# space needed to install all the prerequisite software. Also, the necessary RAM will be higher than the default minimum
# if the machine has more than one CPU.
check-hardware-requirements() {
    local min_disk_kb="$1" min_ram_kb="$2"
    [ -n "$min_disk_kb" ] || min_disk_kb=32000000
    [ -n "$min_ram_kb" ] || min_ram_kb=8000000

    # Available disk space, typically including /tmp. However, if /tmp is mounted elsewhere then that filesystem
    # should also be large.
    for dir in . "${TMPDIR:-/tmp}"; do
        local free_disk_kb=$(df "$dir" |sed -n '2,$ p' |tr -s ' \t' '\t' |cut -f4)
        if [ -n "$free_disk_kb" ]; then
            if [ $free_disk_kb -lt $min_disk_kb ]; then
                echo "$arg0: filesystem containing \"$dir\" is too small" >&2
                exit 1
            fi
        fi
    done

    local total_ram_kb=$(free |sed -n '/^Mem:/p' |tr -s ' \t' '\t' |cut -f2)
    if [ -n "$total_ram_kb" ]; then
        if [ $total_ram_kb -lt $min_ram_kb ]; then
            echo "$arg0: RAM size is too small" >&2
            exit 1
        fi
    fi
}

# Install basic operating-system comonents that are needed in order to build ROSE.  This will be different for
# every platform. The list is maintained at https://rosecompiler.atlassian.net/wiki/x/vwBhF
install-system-dependencies() {
    return 0
}

# Some systems require extra commands to be run in each shell. This function should do whatever is necessary to run
# commands. For instance, some older systems (like CentOS-7) require that build commands be run in a special shell that
# makes more modern C++ compilers available since such compilers are not installed system-wide.  The specific commands
# that are necessary are maintained at https://rosecompiler.atlassian.net/wiki/x/vwBhF
run() {
    (
        set -x
        "$@"
    )
}

# Steps to install the ROSE Meta Config/Spock (RMC/Spock) package management system. This managages software dependencies
# of ROSE that are not installed system-wide.
install-rmc-spock() {
    git clone https://github.com/matzke1/rmc-spock
    (cd rmc-spock && run ./scripts/bootstrap.sh)
    rm -rf rmc-spock
}

# Obtain the ROSE source code and places it in the "rose" directory, but only if that directory doesn't already exist.
get-rose-source-code() {
    if [ ! -d rose/. ]; then
        git clone -b develop https://github.com/rose-compiler/rose rose
    fi
}

# Similar to get-rose-source-code, but fakes it just enough that RMC can run. This is useful if you want to install ROSE
# prerequisites for a particular ROSE configuration without actually ever downloading any part of ROSE itself. RMC just
# checks for some arbitrary ROSE file, so we'll fake it.
get-rose-fake-source-code() {
    mkdir -p rose/src/frontend/BinaryFormats
    touch rose/src/frontend/BinaryFormats/ElfSection.C
    mkdir -p rose/config
    touch rose/config/support-rose.m4
}

# Decide what software dependencies should be used when compiling ROSE.
choose-rose-dependencies() {
    rm -rf rose/_build
    mkdir rose/_build
    (cd rose/_build && run rmc init --batch ..)
    cat rose/_build/.rmc-main.cfg
}

# Install dependencies for Jovial analysis within ROSE.  This is called by install-rose-dependencies if Jovial analysis
# is needed.
install-rose-jovial-dependencies() {
    : none
}

# Install all the software needed to build ROSE. The software was chosen by choose-rose-dependencies.
install-rose-dependencies() {
    (cd rose/_build && run rmc --install=yes true)
    install-rose-jovial-dependencies
}

# Run commands related to GNU Autotools, such as libtoolize, aclocal, autoheader, autoconf, and automake. This builds the
# "configure" script and generate "Makefile.in" from "Makefile.am", among other things.
create-automake-files() {
    run rmc -C rose/_build build
}

# Configure ROSE by running, for instance, "configure".
configure-rose() {
    # These next two lines are just for debugging
    run rmc -C rose/_build spock-using
    run rmc -C rose/_build config --dry-run

    run rmc -C rose/_build config
}

# Build, test, and install the ROSE library and whatever tools are appropriate for this configuration.
build-test-install-rose() {
    run rmc -C rose/_build install

    # Autotools and CMake need to choose the ROSE installation directory when ROSE is configured rather than delaying
    # that until it's installed.  So now we try to fix things up. Besides the rpaths in the libraries and executables,
    # I'm not sure what other hard-coded installation paths are present in the source code (binary analysis has
    # none). Therefore we need to also leave the old names in the file system. Certainly the rose-config.cfg has hard
    # coded paths that will be used when building additional tools.
    if [ -e rose/_build/installed/lib/rose-config.cfg ]; then
        local dst="$HOME/rose-installed/$(date +%Y-%m-%d)/binrelease-$(date +%H%M%S)"
        rm -rf "$dst" "$HOME/rose-installed/latest" "$HOME/rose-installed/latest-release"
        mkdir -p "$dst"
        mv rose/_build/installed/* "$dst"
        rm -rf rose/_build/installed
        (cd "$HOME/rose-installed" && ln -s "$dst" latest && ln -s "$dst" latest-release)
        (cd rose/_build && ln -s "$dst" installed)
    fi
    
    # If we used a non-standard compiler that wouldn't be installed on the user's system, we should make sure to
    # distribute it as part of the binary release.
    local cxx_spec="$(run rmc -C rose/_build spock-using c++-compiler)"
    if ! (run spock-ls "$cxx_spec" |grep -q system-compiler); then
        local cxx_vendor_uc="$(run rmc -C rose/_build c++ --spock-triplet |cut -d: -f1 |tr a-z A-Z)"
        local cxx_root="$(run rmc -C rose/_build bash -c "echo \\\$${cxx_vendor_uc}_COMPILERS_ROOT")"
        rsync -ai "$cxx_root/" "$HOME/rose-installed/latest/."
    fi
    
    # The stratego installation needs to be copied to ROSE's installation root.
    if [ -d rose/_build/stratego ]; then
	rsync -ai rose/_build/stratego/ "$HOME/rose-installed/latest/."
    fi

    # If Tristan's Jovial tests are present, then install them too.
    if [ -f /software/tests.tar ]; then
	(cd "$HOME/rose-installed/latest/." && tar xf /software/tests.tar)
    fi

    # If this was a non-Tup build (i.e., Autotools or CMake) then we still have a bunch of work to do to install stuff
    # because ROSE's makefiles are incomplete.
    if [ -e rose/_build/installed/lib/rose-config.cfg ]; then
        # ROSE Autotools and CMake builds fail to install the mkinstaller script, which is needed later in order to
        # build a binary release from the installed copy of ROSE.
        if [ ! -x "$HOME/rose-installed/latest/bin/mkinstaller" ]; then
            cp rose/scripts/mkinstaller "$HOME/rose-installed/latest/bin/."
        fi

        # The rose-config.cfg file is missing almost all the shared library directories. Also, instead of being a colon-separated
        # list of directory names, each directory must be preceded by "-R " and spaces instead of colons.
        local rpaths="-R $(run rmc -C rose/_build bash -c 'echo \$ALL_LIBDIRS' |sed 's/:/ -R /g')"
	if [ -d "rose/_build/stratego/." ]; then
	   rpaths="$rpaths -R $(pwd)/rose/_build/stratego"
	fi
        (
            sed '/^ROSE_RPATHS/d' <"$HOME/rose-installed/latest/lib/rose-config.cfg"
            echo
            echo "# Corrected variables after autotools make install"
            echo "ROSE_RPATHS = $rpaths"
        ) >"$HOME/rose-installed/latest/lib/rose-config.cfg.new"
        mv "$HOME/rose-installed/latest/lib/rose-config.cfg.new" "$HOME/rose-installed/latest/lib/rose-config.cfg"
    fi
}


# Build, test, and install the Megachiropteran tools.
build-test-install-megachiropteran() {
    # [ROSE-2593] We need to temporarily disable the bat-conc tool since we configured ROSE without any database
    # support and therefore no concolic testing support.
    sed -i 's/^\(run .*bat-conc\)/#\1/' megachiropteran/Tupfile

    run spock-shell -C megachiropteran --with tup,patchelf --install ./configure latest install

    # Optional Juliet test suite tests
    (cd megachiropteran && PATH="$HOME/rose-installed/latest/bin:$PATH" ./maybe-run-juliet-tests /software/juliet.tar.gz)
}

# Build, test, and install the ESTCP tools.
build-test-install-estcp() {
    # [ROSE-2594] The sample sqlite "firmware" doesn't compile on this system, so exclude it from the build.
    mv estcp-software/tests/sqlite-3.22.0/Tupfile{,.bak} || true
    mv estcp-software/tests/sqlite-3.23.1/Tupfile{,.bak} || true

    run spock-shell -C estcp-software --with tup,patchelf --install ./configure latest install
}

# Build, test, install ROSE Garden Jovial (called by build-test-install-rose-garden)
build-test-install-rose-garden-jovial() {
    cat >rose/_build/build-rosegarden-jovial <<'EOF'
        export PATH="$HOME/rose-installed/latest/bin:$PATH"
        cd ../../rose-garden/jovial-to-cpp/src
        make -j$RMC_PARALLELISM
	make install
EOF
    run rmc -C rose/_build bash build-rosegarden-jovial
}

# Build, test, install ROSE Garden attributeLib (called by build-test-install-rose-garden)
build-test-install-rose-garden-attributeLib() {
    run make -C rose-garden/attributeLib/src -f Makefile.robb install
}

# Build, test, and install the ROSE Garden tools
build-test-install-rose-garden() {
    if [ -r "$HOME/rose-installed/latest/include/rose-installed-make.cfg" ]; then
	cp "$HOME/rose-installed/latest/include/rose-installed-make.cfg" rose-garden/rose.cfg
    elif [ -r "$HOME/rose-installed/latest/lib/rose-config.cfg" ]; then
	cp "$HOME/rose-installed/latest/lib/rose-config.cfg" rose-garden/rose.cfg
    fi

    build-test-install-rose-garden-jovial
    build-test-install-rose-garden-attributeLib
}

# Create a binary release of everything that's been installed, plus any additional libraries and headers that would be
# needed on the target machine.
build-binary-release() {
    # [ROSE-2596] ROSE doesn't have a script for building a binary release, so we need to grab one from some other repository.
    mkdir -p empty-project
    [ -d empty-project/tup-scripts ] || (cd empty-project && git clone https://github.com/matzke1/tup-scripts)

    if [ -r "$HOME/rose-installed/latest/include/rose-installed-make.cfg" ]; then
        # Tup builds
        cp "$HOME/rose-installed/latest/include/rose-installed-make.cfg" empty-project/rose.cfg
    else
        # Autotools and CMake builds
        cp "$HOME/rose-installed/latest/lib/rose-config.cfg" empty-project/rose.cfg
    fi

    cp empty-project/tup-scripts/post-install-script empty-project/.
    run spock-shell --with patchelf --install=yes -C empty-project tup-scripts/rose-make-binary-release --verbose
    mv empty-project/rose-* .
    rm -rf empty-project
}

# Compress and encrypt a previously-generated binary release.
compress-binary-release() {
    local password=$(echo $RANDOM$RANDOM$RANDOM$RANDOM$RANDOM |md5sum |cut -d' ' -f1)
    local release_name=$(ls rose-* |head -n1)
    7z a -p$password $release_name.7z $release_name
    local md5sum=$(md5sum "$release_name.7z" |cut -d' ' -f1)

    (
        echo
        echo "Binary release created:"
        echo "   name     = $release_name.7z"
        echo "   password = $password"
        echo "   md5sum   = $md5sum"
    ) |tee release-info.txt

    # If there's a "rose/artifacts" directory, move the release into that directory
    local artifacts="rose/artifacts"
    if [ -d "$artifacts/." ]; then
        mv "$release_name.7z" release-info.txt "$artifacts"
    fi
}

########################################################################################################################
# Mid-level functionality that calls the low-level stuff defined above.
########################################################################################################################

conditionally-install-megachiropteran() {
    if [ -d megachiropteran/. ]; then
        build-test-install-megachiropteran
    elif [ -e /software/megachiropteran.bundle ]; then
        git clone /software/megachiropteran.bundle megachiropteran
        build-test-install-megachiropteran
        rm -rf megachiropteran
    elif [ -d /software/megachiropteran/. ]; then
        (cd /software && build-test-install-megachiropteran)
    fi
}

conditionally-install-estcp() {
    if [ -d estcp-software/. ]; then
        build-test-install-estcp
    elif [ -e /software/estcp-software.bundle ]; then
        git clone /software/estcp-software.bundle estcp-software
        build-test-install-estcp
        rm -rf estcp-software
    elif [ -d /software/estcp-software/. ]; then
        (cd /software && build-test-install-estcp)
    fi
}

conditionally-install-rose-garden() {
    if [ -d rose-garden/. ]; then
        build-test-install-rose-garden
    elif [ -e /software/rose-garden.bundle ]; then
        git clone /software/rose-garden.bundle rose-garden
        build-test-install-rose-garden
        rm -rf rose-garden
    elif [ -d /software/rose-garden/. ]; then
        (cd /software && build-test-install-rose-garden)
    fi
}
