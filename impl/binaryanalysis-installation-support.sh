########################################################################################################################
# This file provides functions that are needed when installing binary analysis on various platforms. This functions are
# the base versions suitable for any platform; particular platforms will override these functions with platform-specific
# implementations.
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

# Steps to install the ROSE Meta Config/Spock (RMC/Spock) package management system. This managages software
# dependencies of ROSE that are not installed system-wide.
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

# Similar to get-rose-source-code, but fakes it just enough that RMC can run. This is useful if you want
# to install ROSE prerequisites for a particular ROSE configuration without actually ever downloading
# any part of ROSE itself. RMC just checks for some arbitrary ROSE file, so we'll fake it.
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
    (cd rose/_build && BUILD=tup run rmc init --project=binaries --batch ..)
    cat rose/_build/.rmc-main.cfg
}

# Install all the software needed to build ROSE. The software was chosen by choose-rose-dependencies.
install-rose-dependencies() {
    (cd rose/_build && run rmc --install=yes true)
}

# Run commands related to GNU Autotools, such as libtoolize, aclocal, autoheader, autoconf, and automake. This
# builds the "configure" script and generate "Makefile.in" from "Makefile.am", among other things.
create-automake-files() {
    run rmc -C rose/_build build
}

# Configure ROSE by running, for instance, "configure".
configure-rose() {
    # These next two lines are just for debugging
    run rmc -C rose/_build spock-using
    run rmc -C rose/_build config --dry-run

    run rmc -C rose/_build config
    echo "CONFIG_TUP_ACKNOWLEDGMENT=yes" >> rose/_build/tup.config
}

# Build, test, and install the ROSE library and whatever tools are appropriate for this configuration.
build-test-install-rose() {
    run rmc -C rose/_build install
}

# Build, test, and install the Megachiropteran tools.
build-test-install-megachiropteran() {
    # [ROSE-2593] We need to temporarily disable the bat-conc tool since we configured ROSE without any database
    # support and therefore no concolic testing support.
    sed -i 's/^\(run .*bat-conc\)/#\1/' megachiropteran/Tupfile

    run spock-shell -C megachiropteran --with tup,patchelf --install ./configure latest install
}

# Build, test, and install the ESTCP tools.
build-test-install-estcp() {
    # [ROSE-2594] The sample sqlite "firmware" doesn't compile on this system, so exclude it from the build.
    mv estcp-software/tests/sqlite-3.22.0/Tupfile{,.bak} || true
    mv estcp-software/tests/sqlite-3.23.1/Tupfile{,.bak} || true

    run spock-shell -C estcp-software --with tup,patchelf --install ./configure latest install
}

# Create a binary release of everything that's been installed, plus any additional libraries and headers that would be
# needed on the target machine.
build-binary-release() {
    # [ROSE-2596] ROSE doesn't have a script for building a binary release, so we need to grab one from some other repository.
    mkdir -p empty-project
    [ -d empty-project/tup-scripts ] || (cd empty-project && git clone https://github.com/matzke1/tup-scripts)
    cp $HOME/rose-installed/latest/include/rose-installed-make.cfg empty-project/rose.cfg
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
