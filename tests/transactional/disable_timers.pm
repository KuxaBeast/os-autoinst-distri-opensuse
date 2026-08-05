# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Disable various timers that sometimes cause test interruptions
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use Utils::Systemd qw(systemctl);
use version_utils qw(is_microos is_sle_micro);
use serial_terminal;

sub run {
    my ($self) = @_;

    select_serial_terminal;

    # Disable disruptive timers
    my @timers = qw(snapper-cleanup.timer fstrim.timer transactional-update.timer btrfs-balance.timer btrfs-defrag.timer btrfs-scrub.timer btrfs-trim.timer);
    push(@timers, "snapper-timeline.timer") unless (is_microos);
    push(@timers, "transactional-update-cleanup.timer") if (is_sle_micro);

    # Disabling these timers is best-effort housekeeping, it is not the system
    # under test. A unit which is not shipped on this product (poo#192154,
    # poo#193471), or a SUT which is momentarily too slow to answer (poo#205260),
    # must not abort the whole job. Report it and carry on instead.
    my @not_disabled;
    foreach my $timer (@timers) {
        my $rc = systemctl("disable --now '$timer'", timeout => 300, ignore_failure => 1);
        push(@not_disabled, $timer) unless (defined($rc) && $rc == 0);
    }
    record_info('Not disabled', join(' ', @not_disabled), result => 'softfail') if (@not_disabled);
}

1;
