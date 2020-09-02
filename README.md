# ROSE installation scripts

This repository contains scripts that install ROSE on clean machines
such as newly provisioned machines like AWS EC2 instances, VirtualBox
VMs, Docker containers, etc.

Each of these scripts performs the following steps:

* Installs system-managed dependencies needed to compile ROSE and the
  tools.
  
* Installs the ROSE Meta Configuration (RMC/Spock) system that will
  manage the non-system dependencies.
  
* Downloads the latest development ROSE source code if there is no
  preexisting "rose" directory.

* Chooses what ROSE dependencies will be used. The dependencies may
  vary slightly across different Linux distributions depending on
  their capabilities.

* Downloads and installs the chosen dependencies using RMC/Spock.

* Prepares ROSE's build system (autoconf, automake, etc).

* Configures ROSE in preparation for building.

* Builds, tests, and installs the ROSE library and associated tools.

* Optionally builds, tests, and installs the Megachiropteran binary
  analysis tools from a private repository.
  
* Optionally builds, tests, and installs ESTCP binary analysis tools
  from a private repository.
  
* Builds a binary release package for all installed artifacts. This
  file can be installed (by executing it with the --prefix=... switch)
  on different machines running the same operating system
  distributions. The CentOS binary releases will also generally work
  on Red Hat distributions with the same version number.

* Prepares the binary release for distribution by compressing and
  encrypting it.  The password and binary release name is emitted in
  the final output.

The scripts are divided into two halves. The upper half defines
special cases for the various steps, and the steps are listed in the
second half.  If step needs to be modified for your particular use
case, it's best to copy it from the "impl" directory into the top half
of the script and modify it there. That way you're not affecting other
OS distributions. If a script fails, the steps that have passed can be
commented out and the script rerun.

Each script has additional commentary at the top that may have more
detailed instructions.
  
# Running the scripts directly

Running the top-level scripts directly is the easiest way to use
them. They are occasionally tested in clean AWS EC2 instances or
VirtualBox guests as indicated in the table below.

The script can be run in any directory and does all its work in that
directory, including ROSE source code downloads. The scripts may
install additional system-wide software (using "sudo"). The use
RMC/Spock, the ROSE metaconfiguration system, to manage additional
dependencies which are installed under ~/.spock.

ROSE itself will be installed in subdirectories of
~/rose-installations, with the "latest" symlink being updated to point
to the most recent installation.
   
# Running scripts in Docker containers

The scripts can be run in Docker containers as well. The "docker"
directory has Dockerfile descriptions of images and each Dockerfile
has comments at the top that describe how to use it. The general steps
are:

1. If you desire to build Megachiropteran and/or ESTCP software that's
   not publicly released, you need to first prepare a Docker volume
   that contains the software and mount this volume at "/software"
   when you create the Docker container.  This volume should contain
   Git bundles of the desired software with names
   "megachiropteran.bundle" and/or "estcp-software.bundle". See the
   "scripts" directory for an example of how to create the volume.
   
2. The Docker images described in the "docker" directory are
   occasionally regenerated and uploaded to hub.docker.com in the
   "matzke" account. You can use these as the basis of the containers,
   or you can generate your own images using the instructions at the
   top of each Dockerfile.

3. Create a Docker container from the chosen image and let it's
   default command run. This will perform all the steps that have not
   been already run when the image was created.  Alternatively, you
   can run /bin/bash and enter the default command manually (shown at
   the end of each Dockerfile), which gives you the opportunity to
   copy the build artifacts off the container.

The binary releases are built automatically as part of Robb's workflow
and are available upon request. They are OUO since they contain
artifacts generated from source code that is not publicly released.
   
# Test dates

The scripts are run in Docker containers as part of Robb's workflow,
and are thus tested at least weekly.

Additionally, the scripts are occasionally run directly on AWS EC2
instances and/or VirtualBox guests. This is usually done in response
to bug reports by users.

Direct runs on AWS EC2 or VirtualBox.

    |-----------------------------------+------------+-----------+-----------------+-------+-----------|
    | Script                            |       Date |      ROSE | Megachiropteran | ESTCP | Result    |
    |-----------------------------------+------------+-----------+-----------------+-------+-----------|
    | install-binaryanalysis-centos8    | 2020-05-14 | 0.10.4.31 | yes             | yes   | pass      |
    | install-binaryanalysis-ubuntu1804 | 2020-05-14 | 0.10.4.18 | yes             | yes   | pass      |
    | install-binaryanalysis-centos7    | 2020-05-14 | 0.10.4.18 | yes             | yes   | pass      |
    | install-binaryanalysis-ubuntu2004 | 2020-08-05 | 0.10.12.6 | yes             | yes   | pass      |
    | install-binaryanalysis-mint18     | 2020-04-06 | 0.10.0.30 | yes             | yes   | pass      |
    | install-binaryanalysis-mint19     | 2020-04-06 | 0.10.0.30 | yes             | yes   | pass      |
    | install-binaryanalysis-ubuntu1910 | 2020-04-03 | 0.10.0.28 | yes             | yes   | failure 1 |
    | install-binaryanalysis-centos6    | 2020-04-03 | 0.10.0.28 | yes             | yes   | failure 1 |
    |-----------------------------------+------------+-----------+-----------------+-------+-----------|

* Failure 1: fails when building binary release (ROSE-2627) but does
  install ROSE on this system.  The binary release failure can be
  worked around by replacing the /lib symlink with a copy of /lib64.
