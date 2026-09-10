#!/bin/bash

# Deterministic input only. The actual serializer and write path are production code.
fixture_node_context() {
    unset host path password ss_password is_private_key is_servername net_type
    unset is_reality is_caddy is_no_auto_tls is_change is_config_file is_gen is_dry_run
    unset is_new_install is_add_public_key json_str
    uuid=00000000-0000-4000-8000-000000000001
    ip=203.0.113.10
    port=31001
    custom_remark='test "node"'
    is_socks_user='test user'
    is_socks_pass='pass "word"\\ //'
    ss_method=aes-128-gcm
    ss_password='pass "word"\\ //'
    password='pass "word"\\ //'
    is_tls_key=${tls_key_config:-/tmp/tls.key}
    is_tls_cer=${tls_cert_config:-/tmp/tls.cer}
    is_servername=www.microsoft.com
    is_private_key=${reality_private_key:-test-private-key}
    is_public_key=test-public-key
    is_short_id=0123abcd
    door_addr=127.0.0.1
    door_port=8080
    cf_domain=tunnel.example.com
    is_random_ss_method=aes-128-gcm
    is_random_servername=www.microsoft.com
    is_test_json=1
    is_conf_dir=${conf_dir:-/tmp}
    is_new_protocol=$1
    if [[ $1 == *-TLS ]]; then
        host=example.com
        path='/ws//path "quoted"'
    fi
}
