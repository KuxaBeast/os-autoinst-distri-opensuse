# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Aborts the remaining BCI test run without failing the job when
# bci_version_check detected that the run is obsolete (a newer image build
# was published to the registry while this job was queued/running on a slow
# architecture). See poo#205197.
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'consoletest';
use testapi;

sub run {
    die "Obsolete test run: a newer image build was published to the registry while this job was queued/running (poo#205197)\n"
      if get_var('BCI_IMAGE_OBSOLETE');
}

sub test_flags {
    # 'fatal' aborts the remaining modules once this one dies; 'ignore_failure' keeps this module's
    # own failure from affecting the overall job result (it is only reached after bci_version_check
    # already recorded a soft failure explaining why the run is obsolete).
    return {fatal => 1, ignore_failure => 1};
}

1;
