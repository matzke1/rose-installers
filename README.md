# ROSE installation scripts

This repository contains scripts that install ROSE on clean machines
such as newly provisioned machines like AWS EC2 instances, VirtualBox
VMs, etc.

These scripts may work for incomplete operating systems such as what
might be present in a Docker container, but this is not the goal for
these scripts.

Each of these scripts performs the following steps:

* Installs system-managed dependencies needed to compile ROSE and the
  tools.
  
* Installs the ROSE Meta Configuration (RMC/Spock) system that will
  manage the non-system dependencies.
  
* Downloads the ROSE source code.

* Chooses what ROSE dependencies will be used.

* Downloads and installs the chosen dependencies using RMC/Spock.

* Prepares ROSE's build system (autoconf, automake, etc).

* Configures ROSE in preparation for building.

* Builds, tests, and installs the ROSE library and associated tools.

* Optionally builds, tests, and installs Megachiropteran binary
  analysis tools from a private repository.
  
* Optionally builds, tests, and installs ESTCP binary analysis tools
  from a private repository.
  
* Builds a binary release package for all installed artifacts.

* Prepares the binary release for distribution by compressing and
  encrypting it.
  
# Test dates

The following table describes when the most recent test was performed
for each of the installer scripts.

| Script                            |       Date |      ROSE | Megachiropteran | ESTCP | Result                                         |
|-----------------------------------+------------+-----------+-----------------+-------+------------------------------------------------|
| install-binaryanalysis-ubuntu1804 | 2020-04-03 | 0.10.0.28 | yes             | yes   | pass                                           |
| install-binaryanalysis-ubuntu1910 | 2020-04-03 | 0.10.0.28 | yes             | yes   | fails when building binary release (ROSE-2627) |
| install-binaryanalysis-centos7    | 2020-04-03 | 0.10.0.28 | yes             | yes   | fails when building binary release (ROSE-2627) |
| install-binaryanalysis-centos6    |            | 0.10.0.28 | yes             | yes   |                                                |
| install-binaryanalysis-mint18     | 2020-04-06 | 0.10.0.30 | yes             | yes   | pass                                           |
| install-binaryanalysis-mint19     |            | 0.10.0.28 | yes             | yes   | pass                                           |

