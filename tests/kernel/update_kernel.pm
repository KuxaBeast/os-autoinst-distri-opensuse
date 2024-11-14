# SUSE's openQA tests
#
# Copyright 2017-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: kernel-azure kernel-devel dracut kmod-compat kernel-default
# Summary: This module installs maint update under test for kernel/kgraft to ltp work image
# Maintainer: QE Kernel <kernel-qa@suse.de>

use 5.018;
use warnings;
use strict;
use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle is_sle_micro is_transactional package_version_cmp);
use qam;
use kernel;
use klp;
use power_action_utils 'power_action';
use repo_tools qw(add_qa_head_repo);
use Utils::Backends;
use LTP::utils;
use transactional;
use package_utils;

sub check_kernel_package {
    my $kernel_name = shift;

    enter_trup_shell(global_options => '-c') if is_transactional;
    script_run('ls -1 /boot/vmlinu[xz]*');
    # Only check versioned kernels in livepatch tests. Some old kernel
    # packages install /boot/vmlinux symlink but don't set package ownership.
    my $glob = get_var('KGRAFT', 0) ? '-*' : '*';
    my $cmd = 'rpm -qf --qf "%{NAME}\n" /boot/vmlinu[xz]' . $glob;
    my $packs = script_output($cmd);
    exit_trup_shell if is_transactional;

    for my $packname (split /\s+/, $packs) {
        die "Unexpected kernel package $packname is installed, test may boot the wrong kernel"
          if $packname ne $kernel_name;
    }
}

# kernel-azure is never released in pool, first release is in updates.
# Fix the chicken & egg problem manually.
sub first_azure_release {
    my $repo = shift;

    fully_patch_system;
    remove_kernel_packages();

    my @repos = split(",", $repo);
    while (my ($i, $val) = each(@repos)) {
        zypper_call("ar $val kernel-update-$i");
    }

    zypper_call("ref");
    zypper_call("in -l kernel-azure", exitcode => [0, 100, 101, 102, 103], timeout => 700);
    zypper_call('in kernel-devel');
}

sub prepare_azure {
    my $self = shift;

    fully_patch_system;
    remove_kernel_packages();
    zypper_call("in -l kernel-azure", exitcode => [0, 100, 101, 102, 103], timeout => 700);
    check_kernel_package('kernel-azure');
    power_action('reboot', textmode => 1);
    boot_to_console($self);
}

sub prepare_kernel_base {
    my $self = shift;

    fully_patch_system;
    remove_kernel_packages();
    zypper_call("in -l kernel-default-base", exitcode => [0, 100, 101, 102, 103], timeout => 700);
    check_kernel_package('kernel-default-base');
    power_action('reboot', textmode => 1);
    reconnect_mgmt_console if is_pvm;
    boot_to_console($self);
}

sub update_kernel {
    my ($repo, $incident_id) = @_;

    fully_patch_system;

    if (check_var('SLE_PRODUCT', 'slert')) {
        install_package('kernel-devel-rt', skip_trup => 'There is no kernel-devel-rt available on transactional system.');
    }
    elsif (is_sle('12+')) {
        zypper_call('in kernel-devel');
    }

    my @repos = split(",", $repo);
    while (my ($i, $val) = each(@repos)) {
        zypper_call("ar -G $val kernel-update-$i");
    }
    zypper_call("ref");

    #Get patch list related to incident
    my $patches = '';
    $patches = get_patches($incident_id, $repo);

    if ($incident_id && !($patches)) {
        die "Patch isn't needed";
    }
    else {
        # Use single patch or patch list
        if (is_transactional) {
            # Proceed with transactional-update patch
            trup_call("patch");
            # Reboot system after patch, to make sure that further checks are done on updated system
            reboot_on_changes;
        } else {
            zypper_call("in -l -t patch $patches", exitcode => [0, 102, 103], log => 'zypper.log', timeout => 1400);
        }
    }
}

sub mod_rpm_info {
    my $module = shift;
    script_output("rpm -qf /$module");
    script_output("modinfo /$module");
}

sub kgraft_state {
    script_run("ls -lt /boot >/tmp/lsboot");
    upload_logs("/tmp/lsboot");
    script_run("cat /tmp/lsboot");

    my $kver = script_output("uname -r");
    my $module;

    chomp $kver;
    script_run("lsinitrd /boot/initrd-$kver | grep patch");
    $module = script_output("lsinitrd /boot/initrd-$kver | awk '/-patch-.*ko\$/ || /livepatch-.*ko\$/ {print \$NF}'");

    if (check_var('REMOVE_KGRAFT', '1')) {
        die 'Kgraft module exists when it should have been removed' if $module;
    }
    else {
        mod_rpm_info($module);
    }

    script_run("uname -a");
}

sub override_shim {
    my $version = shift;

    my $shim_versions = {
        '12-SP2' => [['4.4.121-92.135.1', '0.9-20.3']],
        '12-SP3' => [
            ['4.4.180-94.124.1', '14-25.3.2'],
            ['4.4.180-94.138.1', '15+git47-25.11.1'],
        ],
        '12-SP4' => [
            ['4.12.14-95.54.1', '14-25.6.1'],
            ['4.12.14-95.68.1', '15+git47-25.11.1'],
        ],
        '12-SP5' => [
            ['4.12.14-122.26.1', '14-25.6.1'],
            ['4.12.14-122.60.1', '15+git47-25.11.1']
        ],
        '15' => [
            ['4.12.14-150.52.1', '14-7.10.1'],
            ['4.12.14-150.66.1', '15+git47-7.15.1'],
        ],
        '15-SP1' => [
            ['4.12.14-197.45.1', '15+git47-3.3.1'],
            ['4.12.14-197.83.1', '15+git47-3.13.1']
        ],
        '15-SP2' => [
            ['5.3.18-22.2', '15+git47-3.3.1'],
            ['5.3.18-24.49.2', '15+git47-3.13.1']
        ]
    };
    my $version_list;

    for my $sle (keys %$shim_versions) {
        if (is_sle("=$sle")) {
            $version_list = $shim_versions->{$sle};
            last;
        }
    }

    return if !defined $version_list;

    for my $pair (@$version_list) {
        if (package_version_cmp($version, $$pair[0]) <= 0) {
            my $shim = 'shim-' . $$pair[1];
            enter_trup_shell(global_options => '-c') if is_transactional;
            zypper_call("in -f $shim");
            zypper_call("al $shim");
            exit_trup_shell if is_transactional;
            return;
        }
    }
}

sub install_lock_kernel {
    my $kernel_version = shift;
    my $src_version = shift;

    # Pre-Boothole (CVE 2020-10713) kernel compatibility workaround.
    # Machines with SecureBoot enabled will refuse to boot old kernels
    # with latest shim. Downgrade shim to allow livepatch tests to boot.
    if (get_var('SECUREBOOT') && get_var('KGRAFT')) {
        override_shim($kernel_version);
    }

    # remove all kernel related packages from system
    my @packages = remove_kernel_packages();
    my @lpackages = @packages;
    my %packver = (
        'kernel-devel' => $src_version,
        'kernel-devel-rt' => $src_version,
        'kernel-macros' => $src_version,
        'kernel-source' => $src_version,
        'kernel-source-rt' => $src_version
    );

    unless (is_sle_micro) {
        if (check_var('SLE_PRODUCT', 'slert')) {
            push @packages, "kernel-devel-rt";
        }
        else {
            push @packages, "kernel-devel";
        }
    }

    # add explicit version to each package
    foreach my $package (@packages) {
        $package .= '-' . ($packver{$package} // $kernel_version);
    }

    # Workaround for kgraft installation issue due to Retbleed mitigations
    push @packages, 'crash-kmp-default-7.2.1_k4.12.14_122.124'
      if is_sle('=12-SP5') && !check_var('SLE_PRODUCT', 'slert');

    # install and lock needed kernel
    enter_trup_shell(global_options => '-c') if is_transactional;
    zypper_call("in " . join(' ', @packages), exitcode => [0, 102, 103, 104], timeout => 1400);
    zypper_call("al " . join(' ', @lpackages));
    exit_trup_shell if is_transactional;
}

sub prepare_kgraft {
    my ($repo, $incident_id) = @_;

    #add repository with tested patch
    my $incident_klp_pkg;
    my @all_pkgs;
    my @repos = split(",", $repo);
    while (my ($i, $val) = each(@repos)) {
        my $cur_repo = "kgraft-test-repo-$i";
        zypper_call("ar -G $val $cur_repo");
        my $pkgs = zypper_search("-s -t package -r $cur_repo");
        #disable kgraf-test-repo for while
        zypper_call("mr -d $cur_repo");

        foreach my $pkg (@$pkgs) {
            my $cur_klp_pkg = is_klp_pkg($pkg);
            if ($cur_klp_pkg) {
                if ($incident_klp_pkg) {
                    die "Multiple kernel live patch packages found: \"$$incident_klp_pkg{name}-$$incident_klp_pkg{version}\" and \"$$cur_klp_pkg{name}-$$cur_klp_pkg{version}\"";
                }
                else {
                    $incident_klp_pkg = $cur_klp_pkg;
                }
            }
        }

        push @all_pkgs, @$pkgs;
    }

    if (!$incident_klp_pkg) {
        die "No kernel livepatch package found";
    }

    fully_patch_system;

    my $kernel_name = 'kernel-' . $$incident_klp_pkg{kflavor};
    my $src_name = 'kernel-source';

    $src_name .= '-' . $$incident_klp_pkg{kflavor}
      unless $$incident_klp_pkg{kflavor} eq 'default';

    zypper_call("mr -e kgraft-test-repo-0") if get_var('FLAVOR') =~ /-Updates-Staging/;
    my $kernel_version = find_version($kernel_name, $$incident_klp_pkg{kver});
    my $src_version = find_version($src_name, $$incident_klp_pkg{kver});
    install_lock_kernel($kernel_version, $src_version);
    zypper_call("mr -d kgraft-test-repo-0") if get_var('FLAVOR') =~ /-Updates-Staging/;

    install_klp_product;

    if (check_var('REMOVE_KGRAFT', '1') && @all_pkgs) {
        my $pversion = join(' ', map { $$_{name} } @all_pkgs);
        zypper_call("rm " . $pversion);
    }

    power_action('reboot', textmode => 1);

    return $incident_klp_pkg;
}

sub downgrade_kernel {
    my $kver = shift;
    my $kernel_package = 'kernel-default';
    my $src_package = 'kernel-source';

    fully_patch_system;

    if (check_var('SLE_PRODUCT', 'slert')) {
        $kernel_package = 'kernel-rt';
        $src_package = 'kernel-source-rt';
    }

    my $kernel_version = find_version($kernel_package, $kver);
    my $src_version = find_version($src_package, $kver);
    install_lock_kernel($kernel_version, $src_version);
}

sub find_version {
    my ($packname, $version_fragment) = @_;
    my $verlist = zypper_search("-s --match-exact -t package $packname");
    my $version_arg = $version_fragment;

    $version_fragment =~ s/\./\\./g;

    for my $item (@$verlist) {
        if ($$item{version} =~ qr/^$version_fragment\./) {
            die "$packname-$version_arg is retracted."
              if $$item{status} =~ m/^.R/;
            return $$item{version};
        }
    }

    die "$packname-$version_arg not found in repositories.";
}

sub start_heavy_load {
    my @pids;
    my $root = get_ltproot;

    script_run("grep -v 'module\\|add_key' $root/runtest/syscalls >$root/runtest/syscalls.klp");

    for my $runfile (qw(syscalls.klp ltp-aiodio.part4)) {
        push @pids, background_script_run("yes | $root/runltp -f $runfile &>/dev/null");
    }

    return \@pids;
}

sub update_kgraft {
    my ($incident_klp_pkg, $repo, $incident_id) = @_;

    my @repos = split(",", $repo);
    while (my ($i, $val) = each(@repos)) {
        zypper_call("mr -e kgraft-test-repo-$i");
    }

    # Get patch list related to incident
    my $patches = '';
    $patches = get_patches($incident_id, $repo);

    if ($incident_id && !($patches)) {
        die "Patch isn't needed";
    }
    else {
        script_run(qq{rpm -qa --qf "%{NAME}-%{VERSION}-%{RELEASE} (%{INSTALLTIME:date})\\n" | sort -t '-' > /tmp/rpmlist.before});
        upload_logs('/tmp/rpmlist.before');

        my $pids = start_heavy_load;

        # warm up system
        sleep 15;

        if (is_sle) {
            zypper_call("in -l -t patch $patches", exitcode => [0, 102, 103], log => 'zypper.log', timeout => 2100);
        } elsif (is_sle_micro) {
            trup_call('pkg in kernel-livepatch-$(uname -r | sed s/\\\./_/g)');
        } else {
            die "The current distribution does not support kernel live patching.";
        }

        #kill HEAVY-LOAD scripts
        script_run("kill -s INT -- " . join(' ', map { "-$_" } @$pids));

        script_run(qq{rpm -qa --qf "%{NAME}-%{VERSION}-%{RELEASE} (%{INSTALLTIME:date})\\n" | sort -t '-' > /tmp/rpmlist.after});
        upload_logs('/tmp/rpmlist.after');

        reboot_on_changes if is_sle_micro;

        my $installed_klp_pkg =
          find_installed_klp_pkg($$incident_klp_pkg{kver},
            $$incident_klp_pkg{kflavor});
        if (!$installed_klp_pkg) {
            die "No kernel livepatch package installed after update";
        }
        elsif (!klp_pkg_eq($installed_klp_pkg, $incident_klp_pkg)) {
            die "Unexpected kernel livepatch package installed after update";
        }

        verify_klp_pkg_patch_is_active($incident_klp_pkg);
        verify_klp_pkg_installation($incident_klp_pkg);
    }
}

sub install_kotd {
    my $repo = shift;
    my $kernel_flavor = get_kernel_flavor;
    fully_patch_system;
    remove_kernel_packages;
    zypper_ar($repo, name => 'KOTD', priority => 90, no_gpg_check => 1);
    install_package("-r KOTD $kernel_flavor", trup_continue => 1);
    install_package('kernel-devel', trup_continue => 1);
}

sub boot_to_console {
    my ($self) = @_;

    select_console('sol', await_console => 0) if is_ipmi;
    $self->wait_boot;
    select_serial_terminal;
    assert_script_run('echo 1 >/sys/module/printk/parameters/ignore_loglevel')
      unless is_sle('<12');
}

sub run {
    my $self = shift;
    my $kernel_package = get_kernel_flavor;

    unless (get_var('KERNEL_FLAVOR')) {
        $kernel_package = 'kernel-default-base' if is_sle('<12');
        $kernel_package = 'kernel-rt' if check_var('SLE_PRODUCT', 'slert');
    }

    if (((is_ipmi || is_pvm) && get_var('LTP_BAREMETAL')) || is_transactional) {
        # System is already booted after installation, just switch terminal
        select_serial_terminal;
    } else {
        boot_to_console($self);
    }

    # SLE Micro RT 5.1 image contains both kernel flavors, we need to remove kernel-default
    if (is_sle_micro('=5.1') && check_var('SLE_PRODUCT', 'slert')) {
        trup_call('pkg rm kernel-default');
        # kernel-rt will be removed with kernel-default, we can't lock it before, we need to install it after
        trup_call('-c pkg in kernel-rt');
        reboot_on_changes;
    }

    add_extra_customer_repositories;

    if (get_var('KERNEL_VERSION')) {
        downgrade_kernel(get_var('KERNEL_VERSION'));
        check_kernel_package($kernel_package);
        power_action('reboot', textmode => 1);
        $self->wait_boot if get_var('LTP_BAREMETAL') || is_transactional;
        return;
    }

    my $repo = is_sle_micro('>=6.0') ? get_var('OS_TEST_REPOS') : get_var('KOTD_REPO');
    my $incident_id = undef;

    unless ($repo) {
        $repo = get_required_var('INCIDENT_REPO');
        $incident_id = get_required_var('INCIDENT_ID');
    }

    if (get_var('KGRAFT')) {
        my $incident_klp_pkg = prepare_kgraft($repo, $incident_id);
        boot_to_console($self);

        if (!check_var('REMOVE_KGRAFT', '1')) {
            # dependencies for heavy load script
            add_qa_head_repo;
            install_package("ltp-stable", trup_reboot => 1);

            # update kgraft patch under heavy load
            update_kgraft($incident_klp_pkg, $repo, $incident_id);

            enter_trup_shell if is_transactional;
            zypper_call("rr qa-head");
            zypper_call("rm ltp-stable");
            exit_trup_shell if is_transactional;

            verify_klp_pkg_patch_is_active($incident_klp_pkg);
        }

        kgraft_state;
    }
    elsif (get_var('AZURE')) {
        $kernel_package = 'kernel-azure';

        if (get_var('AZURE_FIRST_RELEASE')) {
            first_azure_release($repo);
        }
        else {
            $self->prepare_azure;
            update_kernel($repo, $incident_id);
        }
    }
    elsif (get_var('KERNEL_BASE')) {
        $kernel_package = 'kernel-default-base';
        $self->prepare_kernel_base;
        update_kernel($repo, $incident_id);
    }
    elsif (get_var('KOTD_REPO')) {
        install_kotd($repo);
    }
    else {
        update_kernel($repo, $incident_id);
    }

    check_kernel_package($kernel_package);

    if (is_transactional) {
        reboot_on_changes;
    } elsif (!get_var('KGRAFT')) {
        power_action('reboot', textmode => 1);
        reconnect_mgmt_console if is_pvm;
        $self->wait_boot if get_var('LTP_BAREMETAL');
    }
}

sub test_flags {
    return {fatal => 1};
}
1;

=head1 Configuration

=head2 INCIDENT_REPO

Comma-separated repository URL list with packages to be tested. Used together
with KGRAFT, AZURE or in the default case. Mutually exclusive with KOTD_REPO.
INCIDENT_ID variable must be set to maintenance incident number.

=head2 KGRAFT

When KGRAFT variable evaluates to true, the incident is a kgraft/livepatch
test. Install one of the older released kernels and apply kgraft/livepatch
from incident repository to it.

=head2 AZURE

When AZURE variable evaluates to true, the incident is a public cloud kernel
test. Uninstall kernel-default and install kernel-azure instead. Then update
kernel as in the default case.

=head3 AZURE_FIRST_RELEASE

When AZURE_FIRST_RELEASE evaluates to true, install kernel-azure directly
from incident repository and update system. This is a chicken&egg workaround
because there is never any kernel-azure package in the pool repository.

=head2 KERNEL_BASE

When KERNEL_BASE variable evaluates to true, the job should test the
alternative minimal kernel. Uninstall kernel-default and install
kernel-default-base instead. Then update kernel as in the default case.

=head2 KERNEL_VERSION

Install the kernel version set in this variable instead of the latest update.

=head2 KOTD_REPO

Repository URL for installing kernel of the day packages. Update system and
install new kernel using the simplified installation method.
