class sunet::gitolite(
    $username           = 'git',
    $group              = 'git',
    $ssh_key            = undef,
    $enable_git_daemon  = false,
) {
    ensure_resource('sunet::system_user', $username, {
        username   => $username,
        group      => $group,
        managehome => true,
        shell      => '/bin/bash'
    })

    $hostname = $::fqdn
    $shortname = $::hostname

    $home = $username ? {
        'root'    => '/root',
        default   => "/home/${username}"
    }

    $_ssh_key = $ssh_key ? {
        undef   => safe_hiera("gitolite-admin-ssh-key",undef),
        ""      => safe_hiera("gitolite-admin-ssh-key",undef),
        default => $ssh_key
    }

    file { ["$home/.gitolite","$home/.gitolite/logs"]:
        ensure => directory,
        owner  => $username,
        group  => $group
    } ->

    case $_ssh_key {
        undef: {
            sunet::snippets::ssh_keygen { "$home/admin": }
        }
        default: {
            file { "$home/admin":
                ensure  => file,
                content => inline_template('<%= @_ssh_key %>'),
                mode    => '0600',
                owner   => 'root',
                group   => 'root',
            }
            sunet::snippets::ssh_pubkey_from_privkey { "$home/admin": }
        }
    } ->

    package {'gitolite3': ensure => latest } ->
    file { "$home/.gitolite.rc":
        ensure  => file,
        owner   => $username,
        group   => $group,
        content => template("sunet/gitolite/gitolite-rc.erb"),
    } ->

    exec {'gitolite-setup':
        command     => "gitolite setup -pk $home/admin.pub",
        user        => $username,
        environment => ["HOME=$home"]
    }

    if $enable_git_daemon {
        package { 'git-daemon-sysvinit':
            ensure => latest
        } ->
        file { '/etc/default/git-daemon':
            ensure  => file,
            owner   => 'root',
            group   => 'root',
            content => template('sunet/gitolite/git-daemon.erb'),
        } ->
        sunet::snippets::add_user_to_group { 'git_daemon_repository_access':
            username => 'gitdaemon',
            group    => $group,
        }
        sunet::misc::ufw_allow { 'allow-git-daemon':
            from => 'any',
            port => '9418',
        }
    }
}
