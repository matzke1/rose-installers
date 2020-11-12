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

# Jovial analysis is not supported when ROSE is configured with only binary analysis support
[[ override ]]
build-test-install-rose-garden-jovial() {
    : jovial is disabled
}
