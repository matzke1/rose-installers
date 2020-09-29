########################################################################################################################
# This file provides functions that are needed when installing binary analysis on various platforms. This functions
# defined in this file override the base class implementations in base-class.sh, and in turn are overridden by
# subclasses.
########################################################################################################################

. "${dir0}/impl/base-class.sh"

# Decide what software dependencies should be used when compiling ROSE. Binary analysis always uses Tup as the
# build system because it's just simply better and faster than any other supported ROSE build system.
[[ override ]]
choose-rose-dependencies() {
    rm -rf rose/_build
    mkdir rose/_build
    (cd rose/_build && BUILD=tup run rmc init --project=binaries --batch ..)
    cat rose/_build/.rmc-main.cfg
}

# Configure ROSE by running, for instance, "configure".
[[ override ]]
configure-rose() {
    # These next two lines are just for debugging
    run rmc -C rose/_build spock-using
    run rmc -C rose/_build config --dry-run

    run rmc -C rose/_build config
    echo "CONFIG_TUP_ACKNOWLEDGMENT=yes" >> rose/_build/tup.config
}

# Build, test, and install the Megachiropteran tools.
[[ override ]]
build-test-install-megachiropteran() {
    # [ROSE-2593] We need to temporarily disable the bat-conc tool since we configured ROSE without any database
    # support and therefore no concolic testing support.
    sed -i 's/^\(run .*bat-conc\)/#\1/' megachiropteran/Tupfile

    run spock-shell -C megachiropteran --with tup,patchelf --install ./configure latest install
}

# Build, test, and install the ESTCP tools.
[[ override ]]
build-test-install-estcp() {
    # [ROSE-2594] The sample sqlite "firmware" doesn't compile on this system, so exclude it from the build.
    mv estcp-software/tests/sqlite-3.22.0/Tupfile{,.bak} || true
    mv estcp-software/tests/sqlite-3.23.1/Tupfile{,.bak} || true

    run spock-shell -C estcp-software --with tup,patchelf --install ./configure latest install
}

########################################################################################################################
# Mid-level functionality that calls the low-level stuff defined above.
########################################################################################################################

[[ override ]]
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

[[ override ]]
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
