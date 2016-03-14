class sunet::bird(
  $bird      = 'bird',
  $bird6     = 'bird6',
  $package   = 'bird-bgp',
  $username  = 'bird',
  $uid       = 501,
  $gid       = 501,
  $router_id = undef
) {
  require stdlib
  $my_router_id = $router_id ? {
     undef   => "${::ipaddress_eth0}",
     default => $router_id
  }

  validate_string($my_router_id)

  group {$username:
    ensure   => present,
    gid      => 501
  } ->
  user  {$username:
    ensure   => present, 
    password => '!!',
    uid      => $uid,
    gid      => $gid
  } ->
  package {$package: ensure => latest } ->
  file { "/etc/bird":
    ensure   => directory,
    owner    => $username,
    group    => $username
  } ->
  file { "/etc/bird/conf.d": ensure => directory } ->
  file { "/etc/bird/conf6.d": ensure => directory } ->
  concat { "/etc/bird/bird.conf":
    owner    => $username,
    group    => $username,
    mode     => '0644',
    notify   => Service[$bird]
  }
  concat { "/etc/bird/bird6.conf":
    owner    => $username,
    group    => $username,
    mode     => '0644',
    notify   => Service[$bird6]
  }
  concat::fragment {'bird_header':
    target   => "/etc/bird/bird.conf",
    order    => '10',
    content  => template("sunet/bird/bird.conf.erb"),
    notify   => Service[$bird]
  }
  concat::fragment {'bird6_header':
    target   => "/etc/bird/bird6.conf",
    order    => '10',
    content  => template("sunet/bird/bird6.conf.erb"),
    notify   => Service[$bird6]
  }
  service {$bird: ensure => running }
  service {$bird6: ensure => running }
}
