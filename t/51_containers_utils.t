use strict;
use warnings;
use Test::More;
use Test::Warnings;
use testapi;
use containers::utils qw(is_newer_image_build);

## Test containers::utils routines.

subtest '[is_newer_image_build] registry reference newer than requested build' => sub {
    ok is_newer_image_build('registry.suse.com/bci/bci-sle15-kernel-module-devel:15.7-60.36', '60.35'),
      'newer minor release is detected (poo#205197)';
    ok is_newer_image_build('registry.suse.com/bci/bci-golang-image:1.24-89.26', '89.25'),
      'newer minor release is detected for a different image';
    ok is_newer_image_build('registry.suse.com/bci/bci-image:1-61.1', '60.35'),
      'newer major release is detected';
};

subtest '[is_newer_image_build] registry reference not newer than requested build' => sub {
    ok !is_newer_image_build('registry.suse.com/bci/bci-sle15-kernel-module-devel:15.7-60.35', '60.35'),
      'equal releases are not considered newer';
    ok !is_newer_image_build('registry.suse.com/bci/bci-sle15-kernel-module-devel:15.7-60.34', '60.35'),
      'older release is not considered newer';
};

subtest '[is_newer_image_build] unparseable input falls back to "not newer" (caller must die)' => sub {
    ok !is_newer_image_build('null', '60.35'), 'a "null" reference (missing label) is not considered newer';
    ok !is_newer_image_build(undef, '60.35'), 'an undefined reference is not considered newer';
    ok !is_newer_image_build('registry.suse.com/bci/bci-image:1-60.35', undef), 'an undefined build is not considered newer';
};

done_testing;
