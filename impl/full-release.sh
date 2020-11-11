########################################################################################################################
# This file provides functions that are needed when installing a full release of ROSE on various platforms. This
# functions defined in this file override the base class implementations in base-class.sh, and in turn are overridden by
# subclasses.
########################################################################################################################

. "${dir0}/impl/base-class.sh"

# Decide what software dependencies should be used when compiling ROSE.
[[ override ]]
choose-rose-dependencies() {
    rm -rf rose/_build
    mkdir rose/_build
    
    (
        set -x

        # For some reason, Jovial analysis is enabled unlike any other analysis. Instead of adding "jovial" to the list
        # of supported languages, there's an entirely separate switch for it. Unfortunately, RMC/Spock doesn't know
        # about this nonstandard way of enabling a language, so we need to use the catch-all "rmc_other". Also, beware
        # of the mixed-style name containing both hyphens and underscores.
        (cd rose/_build && run env LANGUAGES="binaries,c,c++" rmc init --batch ..)
        local stratego_root="$(pwd)/rose/_build/stratego"
        echo "rmc_other '--enable-experimental_jovial_frontend --with-aterm=$stratego_root --with-stratego=$stratego_root'" >>rose/_build/.rmc-main.cfg
    )

    cat rose/_build/.rmc-main.cfg
}

# Install all the software needed to build ROSE. The software was chosen by choose-rose-dependencies.
[[ override ]]
install-rose-dependencies() {
    # All the standard stuff based on choose-rose-dependencies above.
    (cd rose/_build && run rmc --install=yes true)

    # We also need to build some software that's only available to ROSE team members. We assume that the following files
    # are present and unpack to similarly named directories. You may need to mount /software in the Docker container.
    #
    #   /software/aterm-3.0.tar.gz
    #   /software/sdf2-bundle-2.4.1.tar.gz
    #   /software/strategoxt-0.17.1.tar.gz
    #
    # These files can be found in the ROSE team's private NFS at /usr/casc/overture/ROSE/opt/rhel7/x86_64/stratego.
    # Contrary to what the path implies, this source code can be compiled on other platforms too.
    #
    # The following instructions are from Craig Rasmussen with some minor changes.  For instance, we're not using the
    # ROSE team's private Red Hat specific environment configuration scripts, but rather RMC/Spock. Craig's instructions
    # are that these steps are run inside a ROSE build environment, therefore we need to give all those commands to
    # RMC/Spock to run. Futhermore, RMC/Spock must be run inside the CentOS 6/Red Hat 6 "scl" command in order to have
    # additional more modern prerequisites available.  All this nesting causes an extra level of escaping to be needed
    # for double quotes and dollar signs. The current working directory, $RG_BLD, is the top of the ROSE build tree.
    #
    # Note: I'm assuming that the "make" commands can run in parallel, although Craigs instructions are to build
    # serially. (Update: parallel build failed with "/bin/sh: line 3: /rose/_build/strategoxt-0.17.1/xtc/src/xtc: No
    # such file or directory". This might be unrelated to a parallel build, but I'm disabling parallelism temporarily to
    # see if it fixes it.)
    cat >build-jovial-dependencies <<'EOF'
        set -ex
        export STRATEGO_HOME=$RG_BLD/stratego
        export CFLAGS=-DAT_64BIT

        # Temporarily disabling parallelism. See comment above.
        export RMC_PARALLELISM=1

        # Debugging. What software are we using?
        spock-using
        c++ --spock-triplet
        cc --spock-triplet

        # The 64-bit ATerm library
        tar xf /software/aterm-3.0.tar.gz
        cd aterm-3.0/aterm
        ./configure --prefix=$STRATEGO_HOME
        #make -j$RMC_PARALLELISM
        make install
        mkdir -p $STRATEGO_HOME/lib/pkgconfig
        sed "s/\(^Cflags:.*\)/\1 -DAT_64BIT/" <aterm.pc >$STRATEGO_HOME/lib/pkgconfig/aterm.pc
        cd $RG_BLD

        # The sdf2-bundle
        tar xf /software/sdf2-bundle-2.4.1.tar.gz
        cd sdf2-bundle-2.4.1
        ./configure --with-aterm=$STRATEGO_HOME --prefix=$STRATEGO_HOME
        make -j$RMC_PARALLELISM
        make install    
        cd $RG_BLD

        # Strategoxt
        tar xf /software/strategoxt-0.17.1.tar.gz
        cd strategoxt-0.17.1
        ./configure --with-aterm=$STRATEGO_HOME --with-sdf=$STRATEGO_HOME --prefix=$STRATEGO_HOME
        make -j$RMC_PARALLELISM
        make install
        cd $RG_BLD

        # Test
        #export PATH="$STRATEGO_HOME/bin:$PATH"
        #sglri -p $RG_SRC/src/3rdPartyLibraries/experimental-jovial-parser/share/rose/Jovial.tbl -i jovial_file.jov

        # Clean up source and build trees in order to not accidentally use something that we later do not distribute
        rm -rf aterm-3.0 ._aterm-3.0 sdf2-bundle-2.4.1 strategoxt-0.17.1
EOF
    run rmc -C rose/_build bash build-jovial-dependencies
}

[[ override ]]
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
