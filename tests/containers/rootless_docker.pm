# SUSE's openQA tests
#
# Copyright 2023-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test rootless mode on docker.
# - add a user on the /etc/subuid and /etc/subgid to allow automatically allocation subuid and subgid ranges.
# - check uids allocated to user (inside the container are mapped on the host)
# - give read access to the SUSE Customer Center credentials to call zypper from in the container.
#   This grants the current user the required access rights
# - Test rootless container:
#   * container is launched with default root user
#   * container is launched with existing user id
#   * container is launched with keep-id of the user who run the container
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use containers::common;
use containers::docker;
use containers::container_images;
use Utils::Architectures;
use containers::common qw(install_docker_when_needed);

sub run {
    my ($self) = @_;
    select_serial_terminal;
    my $user = $testapi::username;

    install_docker_when_needed();

    my $docker = containers::docker->new();

    my $pkg_name = check_var("CONTAINERS_DOCKER_FLAVOUR", "stable") ? "docker-stable" : "docker";
    install_packages("$pkg_name-rootless-extras");

    my $image = 'registry.opensuse.org/opensuse/tumbleweed:latest';

    my $subuid_start = get_user_subuid($user);
    if ($subuid_start eq '') {
        record_soft_failure 'bsc#1185342 - YaST does not set up subuids/-gids for users';
        $subuid_start = 200000;
        my $subuid_range = $subuid_start + 65535;
        assert_script_run "usermod --add-subuids $subuid_start-$subuid_range --add-subgids $subuid_start-$subuid_range $user";
    }
    assert_script_run "grep $user /etc/subuid", fail_message => "subuid range not assigned for $user";
    assert_script_run "grep $user /etc/subgid", fail_message => "subgid range not assigned for $user";

    # Remove all previous commands generated by root. Some of these commands will be triggered
    # by the rootless user and will generate the same file /tmp/scriptX which will fail if it
    # already exists owned by root
    assert_script_run 'rm -rf /tmp/script*';
    ensure_serialdev_permissions;
    select_console "user-console";

    # https://docs.docker.com/engine/security/rootless/
    assert_script_run "dockerd-rootless-setuptool.sh install";
    assert_script_run "systemctl --user enable --now docker";
    record_info("docker info", script_output("docker info"));

    test_container_image(image => $image, runtime => $docker);
    build_and_run_image(base => $image, runtime => $docker);
    test_zypper_on_container($docker, $image);
}

sub get_user_subuid {
    my ($user) = shift;
    my $start_range = script_output("awk -F':' '\$1 == \"$user\" {print \$2}' /etc/subuid",
        proceed_on_failure => 1);
    return $start_range;
}

sub cleanup {
    script_run "docker system prune -f";
    script_run "rootlesskit rm -rf ~/.local/share/docker";
}

sub post_run_hook {
    my $self = shift;
    cleanup();
    select_serial_terminal();
    $self->SUPER::post_run_hook;
}

sub post_fail_hook {
    my $self = shift;
    cleanup();
    select_serial_terminal();
    save_and_upload_log('cat /etc/{subuid,subgid}', "/tmp/permissions.txt");
    $self->SUPER::post_fail_hook;
}

1;
