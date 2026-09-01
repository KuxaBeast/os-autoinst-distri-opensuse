# SUSE's openQA tests
#
# Copyright 2020-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: container-diff
# Summary: Print and save diffs between two containers using container-diff tool
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use containers::common;
use containers::container_images;
use containers::urls 'get_image_uri';
use version_utils qw(is_leap is_sle);

sub run {
    my ($self) = @_;
    select_serial_terminal;
    my $docker = $self->containers_factory('docker');

    # Not in the main repo, use it from the devel one for this test.
    # Prio 150 to only use this repo for packages not available elsewhere.
    zypper_call('addrepo -fG -p 150 obs://Virtualization:containers/' . get_required_var('VERSION') . ' containers') if is_leap("16.0+");

    zypper_call("install container-diff") if (script_run("which container-diff") != 0);

    # Authenticate against registry.suse.com before pulling the released
    # LTSS image (bsc#1274889). Avoids "docker login -u/-p", which would
    # print the credentials in the test logs.
    if (is_sle("=12-sp5")) {
        assert_script_run('mkdir -p ~/.docker');
        assert_script_run(
q{printf '{"auths":{"registry.suse.com":{"auth":"%s"}}}' "$(awk -F= '/^username/{u=$2} /^password/{p=$2} END{printf "%s:%s", u, p}' /etc/zypp/credentials.d/SCCcredentials | base64 -w0)" > ~/.docker/config.json}
        );
    }

    my $unreleased_image = get_image_uri(released => 0);
    my $released_image = get_image_uri(released => 1);

    # Diagnostic only (poo#206322): narrow down whether the LTSS pull
    # failure is a client-side entitlement problem or a registry-side
    # gap, without changing what the test actually does. Never prints
    # the credentials or the bearer token itself. Safe to drop once the
    # ticket is resolved.
    if ($released_image =~ m{^(registry\.suse\.com)/(suse/ltss/[^:]+)(?::(.+))?$}) {
        my ($registry, $repo, $tag) = ($1, $2, $3 // 'latest');
        # script_output ships a multi-line script over a here-document and
        # runs it with bash -oe pipefail. assert_script_run cannot do that:
        # it verifies the command by matching the echo of what it typed,
        # which never matches once the string contains newlines.
        my $probe = "REGISTRY=$registry\nREPO=$repo\nTAG=$tag\n" . <<'DIAG_EOF';
set +e +o pipefail
echo "== probing $REGISTRY/$REPO:$TAG =="
echo "== SUSEConnect status =="
SUSEConnect --status-text 2>&1
echo "== credentials file =="
ls -l /etc/zypp/credentials.d/ 2>&1
awk -F= '/^username/{print "username=" $2}' /etc/zypp/credentials.d/SCCcredentials 2>&1
CREDS=$(awk -F= '/^username/{u=$2} /^password/{p=$2} END{printf "%s:%s", u, p}' /etc/zypp/credentials.d/SCCcredentials 2>/dev/null)
if [ "${CREDS%%:*}" = "" ] || [ "${CREDS#*:}" = "" ]; then
    echo "no usable SCC credentials - this alone accounts for the pull failure"
    exit 0
fi
echo "== SCC activations for this system =="
curl -s -u "$CREDS" https://scc.suse.com/connect/systems/activations </dev/null | grep -o '"friendly_name":"[^"]*"' | sort -u
echo "== SCC token request (scope: repository:$REPO:pull) =="
TOKEN_JSON=$(curl -s -u "$CREDS" "https://scc.suse.com/api/registry/authorize?service=SUSE+Linux+Docker+Registry&scope=repository:$REPO:pull" </dev/null)
echo "$TOKEN_JSON" | sed 's/"token":"[^"]*"/"token":"<redacted>"/'
TOKEN=$(echo "$TOKEN_JSON" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
echo "== granted scope, decoded from the token payload =="
PAYLOAD=$(echo "$TOKEN" | cut -d. -f2 | tr '_-' '/+')
MOD=$(( ${#PAYLOAD} % 4 ))
if [ "$MOD" -ne 0 ]; then PAYLOAD="${PAYLOAD}$(printf '=%.0s' $(seq 1 $((4 - MOD))))"; fi
echo "$PAYLOAD" | base64 -d 2>/dev/null
echo
echo "== manifest list, headers and body =="
curl -s -D - -H "Authorization: Bearer $TOKEN" -H 'Accept: application/vnd.docker.distribution.manifest.list.v2+json' "https://$REGISTRY/v2/$REPO/manifests/$TAG" </dev/null 2>&1
DIAG_EOF
        record_info('diag: LTSS registry probe (poo#206322)',
            script_output($probe, timeout => 120, proceed_on_failure => 1));
    }

    # container-diff
    my $image_file = $unreleased_image =~ s/\/|:/-/gr;
    my $container_diff_results = "/tmp/container-diff-$image_file.txt";
    assert_script_run("docker pull $unreleased_image", 360);

    # Capture the registry's actual error text (poo#206322): openQA's
    # own failure record for this step never includes docker's stderr,
    # only "command failed", so surface it explicitly before failing,
    # without pulling twice. No pipe here on purpose - piping into tee
    # would report tee's exit status and hide the very failure this is
    # meant to observe.
    my $pull_rc = script_run("docker pull $released_image > /tmp/released_pull.log 2>&1", 360);
    my $pull_out = script_output('cat /tmp/released_pull.log', proceed_on_failure => 1);
    record_info('diag: released pull output', $pull_out);
    die "command 'docker pull $released_image' failed (rc=" . ($pull_rc // 'timeout') . ")" if !defined($pull_rc) || $pull_rc != 0;
    assert_script_run("container-diff diff daemon://$released_image daemon://$unreleased_image --type=rpm --type=file --type=size > $container_diff_results", 300);
    upload_logs("$container_diff_results");

    # Clean container
    $docker->cleanup_system_host();
}

1;
