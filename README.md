# Drogo

This is a quick wrapper script to setup everthing you need for running
openstack component tests using Ansible & Khaleesi.

## Setup

None =D

## Usage

Bunch of examples:

To run pep8 tests on existing project in current directory:
./component_test.sh -c neutron -t pep8

To run unit tests using remote git url:
./component_test.sh -git http://arie.com/neutron-lbaas.git -t unit

To run pep8 tests on local repo and different branch:
./component_test.sh -c /opt/cinder -b stable/liberty -t pep8

